class Public::ActivityReactionsController < ApplicationController
  before_action :authenticate_customer!
  before_action :set_activity

  def create
    reaction_type = params[:reaction_type]
    unless ActivityReaction::REACTION_TYPES.include?(reaction_type)
      render json: { error: "Invalid reaction type" }, status: :unprocessable_entity
      return
    end

    reaction = @activity.activity_reactions.find_or_initialize_by(
      customer: current_customer,
      reaction_type: reaction_type
    )

    if reaction.new_record?
      reaction.save!
      count = @activity.activity_reactions.where(reaction_type: reaction_type).count
      render json: { reacted: true, count: count }
    else
      reaction.destroy!
      count = @activity.activity_reactions.where(reaction_type: reaction_type).count
      render json: { reacted: false, count: count }
    end
  end

  private

  def set_activity
    @activity = Activity.find(params[:activity_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Activity not found" }, status: :not_found
  end
end
