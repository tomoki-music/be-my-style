class Learning::ProgressLogsController < Learning::BaseController
  before_action :set_student, only: [:new, :create]
  before_action :set_progress_log, only: [:edit, :update, :destroy]

  def index
    @school_groups = current_customer.learning_school_groups.ordered
    @selected_school_group = current_customer.learning_school_groups.find_by(id: params[:learning_school_group_id])
    @students = student_scope.ordered
    @progress_logs = progress_log_scope
      .includes(:learning_student, :learning_student_training)
      .with_filters(filter_params)
      .recent_first
  end

  def new
    @progress_log = @student.learning_progress_logs.new(practiced_on: Date.current, part: @student.main_part)
  end

  def create
    @progress_log = @student.learning_progress_logs.new(progress_log_params)
    @progress_log.customer = current_customer

    if @progress_log.save
      redirect_to learning_progress_logs_path(student_id: @student.id), notice: "進捗ログを追加しました。"
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @progress_log.update(progress_log_params)
      redirect_to learning_progress_logs_path(student_id: @progress_log.learning_student_id), notice: "進捗ログを更新しました。"
    else
      render :edit
    end
  end

  def destroy
    student_id = @progress_log.learning_student_id
    @progress_log.destroy
    redirect_to learning_progress_logs_path(student_id: student_id), notice: "進捗ログを削除しました。"
  end

  private

  def set_student
    @student = current_customer.learning_students.find(params[:student_id])
  end

  def set_progress_log
    @progress_log = current_customer.learning_progress_logs.find(params[:id])
  end

  def progress_log_params
    params.require(:learning_progress_log).permit(
      :learning_student_training_id,
      :part,
      :training_title,
      :practiced_on,
      :achievement_mark,
      :comment
    )
  end

  def filter_params
    params.permit(:keyword, :part, :student_id)
  end

  def student_scope
    scope = current_customer.learning_students
    scope = scope.where(learning_school_group_id: @selected_school_group.id) if @selected_school_group.present?
    scope
  end

  def progress_log_scope
    scope = current_customer.learning_progress_logs
    return scope unless @selected_school_group.present?

    scope.joins(:learning_student).where(learning_students: { learning_school_group_id: @selected_school_group.id })
  end
end
