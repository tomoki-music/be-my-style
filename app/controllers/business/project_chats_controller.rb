# app/controllers/business/project_chats_controller.rb
class Business::ProjectChatsController < ApplicationController
  before_action :set_project

  def create
    @chat = @project.project_chats.build(chat_params)
    @chat.customer = current_customer

    if @chat.save
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
end