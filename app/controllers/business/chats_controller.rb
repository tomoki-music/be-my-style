class Business::ChatsController < ApplicationController

  def create
    project = Project.find(params[:project_id])

    chat = project.chats.new(chat_params)
    chat.customer = current_customer

    chat.save

    redirect_to business_project_path(project)
  end

  private

  def chat_params
    params.require(:chat).permit(:message)
  end

end