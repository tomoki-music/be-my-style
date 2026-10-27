# プロジェクト内のスレッド。閲覧・投稿・作成はプロジェクト参加者(管理者を含む)、
# タイトル・説明の編集は作成者か管理者、削除は管理者だけ。
class Business::ProjectThreadsController < ApplicationController
  include BusinessAccessControl

  before_action :set_project
  before_action :require_business_project_participant!
  before_action :link_legacy_chats, only: [:index, :show]
  before_action :set_thread, only: [:show, :edit, :update, :destroy]
  before_action :ensure_thread_editable!, only: [:edit, :update]
  before_action :ensure_thread_destroyable!, only: [:destroy]

  def index
    @threads = @project.project_threads.includes(customer: { profile_image_attachment: :blob }).recently_active
    @thread_post_counts = ProjectChat.where(project_thread_id: @threads.map(&:id)).group(:project_thread_id).count
  end

  def show
    @messages = @thread.project_chats
      .includes(customer: { profile_image_attachment: :blob })
      .with_attached_attachments
      .order(created_at: :asc)
    @new_message = ProjectChat.new
  end

  def new
    @thread = @project.project_threads.build
  end

  def create
    @thread = @project.project_threads.build(thread_params)
    @thread.customer = current_customer

    if @thread.save
      redirect_to business_project_thread_path(@project, @thread), notice: "スレッドを作成しました"
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @thread.update(thread_params)
      redirect_to business_project_thread_path(@project, @thread), notice: "スレッドを更新しました"
    else
      render :edit
    end
  end

  # 未所属チャットの紐づけ(LegacyChatBackfill)と同じロックで、削除途中のスレッドへ紐づくのを防ぐ。
  def destroy
    @project.with_lock { @thread.destroy }
    redirect_to business_project_threads_path(@project), notice: "スレッドを削除しました"
  end

  private

  def set_project
    @project = find_business_project!(params[:project_id])
    @community = @project.community
  end

  # デプロイ中に旧コードが残したデータ(全体トークの無いプロジェクト・スレッド未所属の投稿)を、
  # 手動の backfill を待たずに補う。失敗したら画面で再読み込みを案内する。
  def link_legacy_chats
    @thread_repair_failed = !Business::ProjectThreads::LegacyChatBackfill.call_safely(project: @project)
  end

  # 別プロジェクトのスレッド ID を指定しても見つからない(404)ようにする。
  def set_thread
    @thread = @project.project_threads.find(params[:id])
  end

  def ensure_thread_editable!
    return if current_customer.can_edit_project_thread?(@thread)

    redirect_to business_project_thread_path(@project, @thread), alert: "このスレッドを編集する権限がありません。"
  end

  def ensure_thread_destroyable!
    return if current_customer.can_destroy_project_thread?(@thread)

    message = @thread.general? ? "「#{ProjectThread::DEFAULT_TITLE}」は削除できません。" : "スレッドはプロジェクトの管理者だけが削除できます。"
    redirect_to business_project_thread_path(@project, @thread), alert: message
  end

  def thread_params
    params.require(:project_thread).permit(:title, :description)
  end
end
