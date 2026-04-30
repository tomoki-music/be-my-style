class Business::PostsController < ApplicationController
  before_action :authenticate_customer!
  before_action :set_post, only: [:show, :edit, :update, :destroy]
  before_action only: [:new, :create] do
    unless onboarding_activity_exception?(:business)
      require_feature!(:business_post_create, redirect_to_path: business_posts_path)
    end
  end

  def index

    @posts = Post.all

    # ユーザー絞り込み
    if params[:user_id].present?
      @posts = @posts.where(customer_id: params[:user_id])
    end

    # キーワード検索
    if params[:keyword].present?
      @posts = @posts.where("body LIKE ?", "%#{params[:keyword]}%")
    end

    # 人気タグ（常に表示）
    @popular_tags = Post.tag_counts_on(:tags).order(count: :desc).limit(10)

    # タグ検索
    if params[:tag].present?
      @posts = Post.tagged_with(params[:tag])
    end

    # 並び順
    @posts = @posts.order(created_at: :desc)

    # ページネーション
    @posts = @posts.page(params[:page]).per(12)

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
        redirect_to business_posts_path
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
    redirect_to business_posts_path
  end

  def timeline

    tab = params[:tab] || "recommended"

    case tab

    when "following"
      following_ids = current_customer.followings.pluck(:id)
      posts = Post.where(customer_id: following_ids + [current_customer.id])

    when "community"
      community_ids = current_customer.communities.pluck(:id)

      posts = Post.joins(:customer)
                  .joins("INNER JOIN community_customers ON community_customers.customer_id = customers.id")
                  .where(community_customers: { community_id: community_ids })

    else # recommended

      posts = Post.all

    end

    # スコアリング
    @posts = posts
      .left_joins(:likes, :messages)
      .select("posts.*, 
        COUNT(DISTINCT likes.id) * 3 +
        COUNT(DISTINCT messages.id) * 2 +
        (UNIX_TIMESTAMP(posts.created_at) / 10000) as score
      ")
      .group("posts.id")
      .order("score DESC")

    if params[:keyword].present?
      @posts = posts.where("body LIKE ?", "%#{params[:keyword]}%")
    end

    @posts = @posts.page(params[:page]).per(12)
  end

  private

  def set_post
    @post = Post.find(params[:id])
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
