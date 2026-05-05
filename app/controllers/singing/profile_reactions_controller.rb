class Singing::ProfileReactionsController < Singing::BaseController
  before_action :set_user

  def create
    reaction_type = params[:reaction_type].to_s
    unless SingingProfileReaction::REACTION_TYPES.include?(reaction_type)
      render json: { error: "Invalid reaction type" }, status: :unprocessable_entity
      return
    end

    if @user == current_customer
      render json: { error: "Cannot react to your own profile" }, status: :forbidden
      return
    end

    reaction = @user.received_singing_profile_reactions.find_or_initialize_by(
      customer: current_customer,
      reaction_type: reaction_type
    )

    reacted = reaction.new_record?
    reacted ? reaction.save! : reaction.destroy!

    render json: {
      reacted: reacted,
      count: @user.received_singing_profile_reactions.where(reaction_type: reaction_type).count
    }
  end

  private

  def set_user
    @user = Customer.find(params[:user_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "User not found" }, status: :not_found
  end
end
