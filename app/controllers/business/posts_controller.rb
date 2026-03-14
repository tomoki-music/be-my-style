class Business::PostsController < ApplicationController
  before_action :authenticate_customer!
  before_action :set_post, only: [:show, :edit, :update, :destroy]

  def index
    if params[:keyword].present?
      @posts = Post.where(
        "body LIKE ?", "%#{params[:keyword]}%"
      )
    else
      @posts = Post.includes(:customer).order(created_at: :desc)
    end
  end

  def show
    @post = Post.find(params[:id])
    @message = Message.new
  end

  def new
    @post = Post.new
  end

  def create
    @post = current_customer.posts.new(post_params)

    if @post.save
      redirect_to business_posts_path, notice: "投稿しました"
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @post.update(post_params)
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

    following_ids = current_customer.followings.pluck(:id)

    @posts = Post
              .where(customer_id: following_ids + [current_customer.id])
              .includes(:customer)
              .order(created_at: :desc)

  end

  private

  def set_post
    @post = Post.find(params[:id])
  end

  def post_params
    params.require(:post).permit(:title, :body, :category, :post_image)
  end
end
