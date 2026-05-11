class Learning::StudentsController < Learning::BaseController
  before_action :set_student, only: [:show, :edit, :update, :destroy, :send_portal_mail]

  def index
    @school_groups = current_customer.learning_school_groups.ordered
    @students = current_customer.learning_students
      .includes(:learning_student_parts, :learning_student_trainings, :learning_school_group, :learning_line_connections)
      .with_filters(filter_params)
      .ordered
    @line_message_templates = current_customer.learning_line_message_templates.active.ordered
    @recent_bulk_line_student_ids = current_customer.learning_notification_logs
      .recently_sent_line(24.hours.ago)
      .where(notification_type: "teacher_bulk_message", learning_student_id: @students.map(&:id))
      .distinct
      .pluck(:learning_student_id)
  end

  def show
    trainings = @student.learning_student_trainings.ordered.to_a
    logs = @student.learning_progress_logs.recent_first
    @related_band_trainings = @student.related_band_trainings.first(6)
    achievement_count = trainings.count(&:star?)

    @training_summary = {
      total_count: trainings.count,
      achievement_count: achievement_count,
      progress_rate: trainings.count.zero? ? 0 : ((achievement_count.to_f / trainings.count) * 100).round
    }
    @line_connection = @student.learning_line_connections.order(created_at: :desc).first
    @last_line_notification_log = @student.learning_notification_logs
      .where(delivery_channel: "line", status: "sent")
      .order(sent_at: :desc, generated_at: :desc)
      .first
    @student_trainings = trainings.first(8)
    @recent_logs = logs.limit(8)
  end

  def new
    @student = current_customer.learning_students.new(
      status: "active",
      main_part: "vocal",
      learning_school_group: selected_school_group_for_new
    )
  end

  def create
    @student = current_customer.learning_students.new(student_params)
    assign_school_group(@student)

    if save_student_with_parts(@student)
      redirect_to learning_student_path(@student), notice: "生徒を登録しました。"
    else
      render :new
    end
  end

  def edit
  end

  def update
    @student.assign_attributes(student_params)
    assign_school_group(@student)

    if save_student_with_parts(@student)
      redirect_to learning_student_path(@student), notice: "生徒情報を更新しました。"
    else
      render :edit
    end
  end

  def destroy
    @student.destroy
    redirect_to learning_students_path, notice: "生徒を削除しました。"
  end

  def send_portal_mail
    if @student.email.blank?
      return redirect_to learning_student_path(@student), alert: "この生徒はメールアドレス未登録です。生徒情報を編集してから送信してください。"
    end

    LearningMailer.with(teacher: current_customer, student: @student).student_portal_mail.deliver_now
    redirect_to learning_student_path(@student), notice: "生徒向けページをメールで送信しました。"
  rescue StandardError => e
    redirect_to learning_student_path(@student), alert: "メール送信に失敗しました: #{e.message}"
  end

  private

  def set_student
    @student = current_customer.learning_students.includes(:learning_student_parts).find(params[:id])
  end

  def student_params
    params.require(:learning_student).permit(:name, :email, :main_part, :grade, :memo, :status, :learning_school_group_id)
  end

  def filter_params
    params.permit(:keyword, :status, :part, :learning_school_group_id)
  end

  def save_student_with_parts(student)
    ActiveRecord::Base.transaction do
      student.save!
      student.sync_parts!(params.dig(:learning_student, :parts))
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def selected_school_group_for_new
    current_customer.learning_school_groups.find_by(id: params[:learning_school_group_id]) || current_customer.learning_school_groups.ordered.first
  end

  def assign_school_group(student)
    school_group_id = params.dig(:learning_student, :learning_school_group_id).presence
    student.learning_school_group = school_group_id.present? ? current_customer.learning_school_groups.find_by(id: school_group_id) : nil
  end
end
