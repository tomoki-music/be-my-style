class CustomerMailer < ApplicationMailer
  before_action :set_default_params

  def join_event_mail
    @event = Event.find(params[:event_id])
    @event_url = "https://be-my-style.com/public/events/#{@event.id}"
    mail to: @ps_customer.email, subject: 'あなたの企画したイベントへの参加がありました！'
  end

  def member_join_event_mail
    @event = Event.find(params[:event_id])
    @event_url = "https://be-my-style.com/public/events/#{@event.id}"
    mail to: @ps_customer.email, subject: 'あなたが参加したイベントに、他の参加者がエントリーしました！'
  end

  def request_msg_mail
    @event = Event.find(params[:event_id])
    @event_url = "https://be-my-style.com/public/events/#{@event.id}"
    @request = params[:request]
    mail to: @ps_customer.email, subject: '参加したイベントにリクエストがありました！'
  end

  def create_event_mail
    @event = Event.find(params[:event_id])
    @event_url = "https://be-my-style.com/public/events/#{@event.id}"
    mail to: @ps_customer.email, subject: 'イベントが新しく企画されました！'
  end

  def create_activity_mail
    @activity = params[:activity]
    @activity_url = "https://be-my-style.com/public/activities/#{@activity.id}"
    mail to: @ps_customer.email, subject: '活動報告が新しく投稿されました！'
  end

  def create_favorite_mail
    @activity = params[:activity]
    @activity_url = "https://be-my-style.com/public/activities/#{@activity.id}"
    mail to: @ps_customer.email, subject: 'あなたの活動報告が「いいね！」されました！'
  end

  def create_comment_mail
    @activity = params[:activity]
    @activity_url = "https://be-my-style.com/public/activities/#{@activity.id}"
    @comment = params[:comment]
    mail to: @ps_customer.email, subject: 'あなたの活動報告に「コメント」が付きました！'
  end

  def create_follow_mail
    @follower_url = "https://be-my-style.com/public/customers/#{@ac_customer.id}"
    mail to: @ps_customer.email, subject: 'あなたのアカウントが「フォロー」されました！'
  end

  def create_chat_mail
    @chat_message = params[:chat_message]
    @matching_url = "https://be-my-style.com/public/matchings"
    mail to: @ps_customer.email, subject: 'あなたに「個別チャット」が届きました！'
  end

  def create_request_mail
    @community = params[:community]
    @community_url = "https://be-my-style.com/public/communities/#{@community.id}"
    mail to: @ps_customer.email, subject: 'あなたの企画した「コミュニティ」へ参加申請が届きました！'
  end

  def create_accept_mail
    @community = params[:community]
    @community_url = "https://be-my-style.com/public/communities/#{@community.id}"
    mail to: @ps_customer.email, subject: '参加申請した「コミュニティ」への参加が受理されました！'
  end

  def create_group_chat_mail
    @chat_message = params[:chat_message]
    @community = params[:community]
    @community_url = "https://be-my-style.com/public/communities/#{@community.id}"
    mail to: @ps_customer.email, subject: 'あなたの参加するコミュニティにて「チャット」が届きました！'
  end


  # ビジネスNAKAMA
  # いいね、コメント、フォロー通知
  def like_post_mail
    @post = params[:post]
    @post_url = "https://be-my-style.com/business/posts/#{@post.id}"
    mail to: @ps_customer.email, subject: 'あなたの投稿がいいねされました！'
  end

  def comment_post_mail
    @post = params[:post]
    @message = params[:message]
    @post_url = "https://be-my-style.com/business/posts/#{@post.id}"
    mail to: @ps_customer.email, subject: 'あなたの投稿にコメントが付きました！'
  end

  def business_follow_mail
    @follower_url = "https://be-my-style.com/business/customers/#{@ac_customer.id}"
    mail to: @ps_customer.email, subject: 'あなたのアカウントが「フォロー」されました！'
  end

  # コミュニティ申請通知、許可通知
  def business_request_mail
    @community = params[:community]
    @community_url = "https://be-my-style.com/business/communities/#{@community.id}"
    mail to: @ps_customer.email, subject: 'あなたの企画した「コミュニティ」へ参加申請が届きました！'
  end

  def business_accept_mail
    @community = params[:community]
    @community_url = "https://be-my-style.com/business/communities/#{@community.id}"
    mail to: @ps_customer.email, subject: '参加申請した「コミュニティ」への参加が受理されました！'
  end

  def business_project_created_mail
    @project = params[:project]
    @project_url = "https://be-my-style.com/business/projects/#{@project.id}"
    mail to: @ps_customer.email, subject: '所属コミュニティで新しいプロジェクトが作成されました！'
  end

  def business_project_joined_mail
    @project = params[:project]
    @project_url = "https://be-my-style.com/business/projects/#{@project.id}"
    mail to: @ps_customer.email, subject: 'プロジェクトに新しい参加メンバーが加わりました！'
  end

  def business_project_chat_mail
    @project = params[:project]
    @project_chat = params[:project_chat]
    @project_url = "https://be-my-style.com/business/projects/#{@project.id}"
    mail to: @ps_customer.email, subject: '参加中のプロジェクトに新しいコメントが届きました！'
  end

  private

  def set_default_params
    @ac_customer = params[:ac_customer]
    @ps_customer = params[:ps_customer]
    @url = 'https://be-my-style.com/customers/sign_in'
    @mypage = "https://be-my-style.com/public/customers/#{@ps_customer.id}"
    @business_mypage = "https://be-my-style.com/business/customers/#{@ps_customer.id}"
  end

end
