# app/controllers/business/project_chats_controller.rb
class Business::ProjectChatsController < ApplicationController
  before_action :set_project

  def create
    @chat = @project.project_chats.build(chat_params)
    @chat.customer = current_customer

    if @chat.save
      notify_project_chat!(@chat)
      redirect_to business_project_path(@project), notice: "送信しました"
    else
      redirect_to business_project_path(@project), alert: "送信できませんでした"
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

  def chat_params
    params.require(:project_chat).permit(:body)
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
