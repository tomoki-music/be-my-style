# app/controllers/business/project_chats_controller.rb
class Business::ProjectChatsController < ApplicationController
  include BusinessChatSubmission

  before_action :set_project
  before_action :ensure_project_member!, only: [:create]

  def create
    attributes = business_chat_attributes(:project_chat)
    return redirect_to(business_project_path(@project), alert: business_chat_too_many_files_message) if attributes.nil?

    @chat = @project.project_chats.build(attributes)
    @chat.customer = current_customer

    if @chat.save
      notify_project_chat!(@chat)
      redirect_to business_project_path(@project), notice: "送信しました"
    else
      redirect_to business_project_path(@project), alert: business_chat_error_message(@chat)
    end
  end

  def destroy
    @chat = @project.project_chats.find(params[:id])
    @chat.destroy if @chat.customer == current_customer
    redirect_to business_project_path(@project)
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  # チャットの閲覧画面と同じく、プロジェクト参加者だけが投稿できる。プラン条件は無い。
  def ensure_project_member!
    return if @project.members.include?(current_customer)

    redirect_to business_project_path(@project), alert: "チャットはプロジェクト参加者のみ投稿できます。"
  end

  def notify_project_chat!(chat)
    recipients = []
    recipients.concat(@project.community.community_owners.includes(:customer).map(&:customer))
    recipients << @project.community.owner if @project.community.owner.present?
    recipients << @project.customer
    recipients.concat(@project.members.to_a)
    recipients = recipients.compact.reject { |customer| customer.id == current_customer.id }.uniq

    recipients.each do |customer|
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
