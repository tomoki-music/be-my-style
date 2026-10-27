# app/controllers/business/project_chats_controller.rb
# スレッドへの投稿。スレッド指定の無い旧導線(/business/projects/:id/project_chats)は「全体トーク」へ送る。
class Business::ProjectChatsController < ApplicationController
  include BusinessChatSubmission
  include BusinessAccessControl

  before_action :set_project
  before_action :require_business_project_participant!
  before_action :set_thread

  def create
    attributes = business_chat_attributes(:project_chat)
    return redirect_to(business_project_thread_path(@project, @thread), alert: business_chat_too_many_files_message) if attributes.nil?

    @chat = @project.project_chats.build(attributes)
    @chat.project_thread = @thread
    @chat.customer = current_customer

    if @chat.save
      notify_project_chat!(@chat)
      redirect_to business_project_thread_path(@project, @thread), notice: "送信しました"
    else
      redirect_to business_project_thread_path(@project, @thread), alert: business_chat_error_message(@chat)
    end
  end

  def destroy
    chats = params[:thread_id].present? ? @thread.project_chats : @project.project_chats
    @chat = chats.find(params[:id])
    @chat.destroy if @chat.customer == current_customer
    redirect_to business_project_thread_path(@project, @chat.project_thread || @thread)
  end

  private

  def set_project
    @project = find_business_project!(params[:project_id])
  end

  # スレッド指定の無い旧導線は「全体トーク」へ(旧コードで作られたプロジェクトでも、無ければ作って送る)。
  def set_thread
    @thread = params[:thread_id].present? ? @project.project_threads.find(params[:thread_id]) : ProjectThread.general_for!(@project)
  end

  # 宛先はプロジェクト内部を閲覧できる人だけ(メール本文に投稿内容を含むため)。
  def notify_project_chat!(chat)
    @project.accessible_customers.where.not(id: current_customer.id).find_each do |customer|
      customer.business_notification_project_message(current_customer, @project)
      next unless customer.confirm_mail

      CustomerMailer.with(
        ac_customer: current_customer,
        ps_customer: customer,
        project: @project,
        project_chat: chat
      ).business_project_chat_mail.deliver_later
    end
  end
end
