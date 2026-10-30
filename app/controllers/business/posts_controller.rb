class Business::PostsController < ApplicationController
  layout "business"

  TIMELINE_TABS = %w[recommended following community].freeze
  # タイムラインの絞り込み条件。旧一覧からの転送でも、この4つだけを文字列として引き継ぐ。
  TIMELINE_FILTER_KEYS = %w[keyword tag user_id page].freeze

  before_action :authenticate_customer!
  before_action :set_post, only: [:show, :edit, :update, :destroy]
  before_action :ensure_post_owner!, only: [:edit, :update, :destroy]
  before_action only: [:new, :create] do
    unless onboarding_activity_exception?(:business)
      require_feature!(:business_post_create, redirect_to_path: business_timeline_path)
    end
  end

  # 投稿の一覧はタイムラインに統一した。旧一覧の URL(プロフィールの「もっと見る」・タグのリンク・ブックマーク)は
  # 絞り込み条件ごとタイムラインへ転送する。
  def index
    redirect_to business_timeline_path(TIMELINE_FILTER_KEYS.index_with { |key| timeline_filter(key) }.compact),
      status: :moved_permanently
  end

  def show
    @message = Message.new
  end

  def new
    @post = Post.new
  end

  def create
    tags = params[:post][:tag_list]
              .to_s
              .split(/[[:space:],　]+/)
              .reject(&:blank?)

    @post = current_customer.posts.new(post_params.merge(tag_list: tags))

    if @post.save
      complete_onboarding_if_pending!

      if current_customer.onboarding_done?
        redirect_to business_post_path(@post), notice: "投稿しました。NAKAMAにログインしている全員が見られます。"
      else
        redirect_to onboarding_step3_path
      end
    else
      render :new
    end
  end

  def edit
  end

  def update
    tags = params[:post][:tag_list]
              .to_s
              .split(/[[:space:],　]+/)
              .reject(&:blank?)

    if @post.update(post_params.merge(tag_list: tags))
      redirect_to business_post_path(@post)
    else
      render :edit
    end
  end

  def destroy
    @post.destroy
    redirect_to business_timeline_path, notice: "投稿を削除しました"
  end

  # ビジネス投稿(Post)の唯一の一覧。投稿はログインした全員が見られ、タブは「誰の投稿か」で絞り込むだけ。
  # コミュニティ内の会話(CommunityPost)・プロジェクトのスレッド(ProjectChat)は含めない。
  def timeline
    @tab = TIMELINE_TABS.include?(params[:tab]) ? params[:tab] : "recommended"
    @filters = { keyword: timeline_filter("keyword"), tag: timeline_filter("tag"), user_id: timeline_filter("user_id") }
    @filter_customer = Customer.find_by(id: @filters[:user_id]) if @filters[:user_id]

    posts = timeline_scope(@tab)
    # 存在しない投稿者を指定されたときは、全件ではなく該当なしにする(旧一覧と同じ)。
    posts = posts.where(customer_id: @filter_customer&.id) if @filters[:user_id]
    posts = posts.where("posts.body LIKE ?", "%#{Post.sanitize_sql_like(@filters[:keyword])}%") if @filters[:keyword]
    posts = posts.where(id: Post.tagged_with(@filters[:tag]).select(:id)) if @filters[:tag]

    @popular_tags = Post.tag_counts_on(:tags).order(count: :desc).limit(10)
    @posts = scored(posts)
      .preload(:likes, :messages, post_image_attachment: :blob, customer: { profile_image_attachment: :blob })
      .page(timeline_filter("page")).per(12)
  end

  private

  # 配列・ハッシュなど文字列以外の値は無視する(検索条件として扱えず、表示も崩れるため)。
  def timeline_filter(key)
    value = params[key]
    value.is_a?(String) ? value.strip.presence : nil
  end

  def timeline_scope(tab)
    case tab
    when "following"
      Post.where(customer_id: current_customer.followings.select(:id)).or(Post.where(customer_id: current_customer.id))
    when "community"
      # 同じコミュニティに参加している人の投稿。投稿自体の公開範囲(ログインした全員)は変わらない。
      Post.where(customer_id: CommunityCustomer.where(community_id: current_customer.communities.select(:id)).select(:customer_id))
    else
      Post.all
    end
  end

  # いいね・コメントの多さと新しさで並べる。テスト環境(SQLite)でも同じ並びを確かめられるよう、時刻の数値化だけ DB ごとに書き分ける。
  def scored(posts)
    epoch = ActiveRecord::Base.connection.adapter_name.match?(/mysql/i) ? "UNIX_TIMESTAMP(posts.created_at)" : "CAST(strftime('%s', posts.created_at) AS REAL)"

    posts
      .left_joins(:likes, :messages)
      .select("posts.*, COUNT(DISTINCT likes.id) * 3 + COUNT(DISTINCT messages.id) * 2 + (#{epoch} / 10000) AS score")
      .group("posts.id")
      .order("score DESC", "posts.id DESC")
  end

  def set_post
    @post = Post.find(params[:id])
  end

  # 詳細画面の「編集」「削除」ボタンと同じく、投稿者本人だけに許可する。
  def ensure_post_owner!
    return if @post.customer_id == current_customer.id

    redirect_to business_post_path(@post), alert: "この投稿を編集・削除する権限がありません。"
  end

  def post_params
    params.require(:post).permit(
      :title,
      :body,
      :category,
      :post_image,
      :project_id,
    )
  end
end
