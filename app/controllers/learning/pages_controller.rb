class Learning::PagesController < ApplicationController
  skip_before_action :authenticate_customer!
  layout "learning_public"

  def school
  end

  def guide
  end

  def apply
    @application = LearningSchoolApplication.new
  end

  def create_apply
    @application = LearningSchoolApplication.new(application_params)
    if @application.save
      redirect_to learning_apply_path, notice: "申し込みを受け付けました。担当者より2営業日以内にご連絡いたします。"
    else
      render :apply, status: :unprocessable_entity
    end
  end

  def student_start
  end

  private

  def application_params
    params.require(:learning_school_application).permit(
      :school_name, :advisor_name, :email, :student_count, :message
    )
  end
end
