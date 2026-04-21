class Learning::StudentTrainingsController < Learning::BaseController
  before_action :set_student, only: [:index, :create, :reorder]
  before_action :set_student_training, only: [:edit, :update, :destroy, :mark]

  def index
    prepare_index_resources
  end

  def create
    prepare_index_resources

    training_master_id = student_training_create_params[:learning_training_master_id].presence

    @new_student_training = @student.learning_student_trainings.new(
      customer: current_customer,
      weekly_goal: student_training_create_params[:weekly_goal],
      teacher_comment: student_training_create_params[:teacher_comment]
    )

    if training_master_id.blank?
      @new_student_training.errors.add(:learning_training_master, "を選択してください")
      return render :index
    end

    training_master = current_customer.learning_training_masters.individual_training.find_by(id: training_master_id)

    unless training_master
      @new_student_training.errors.add(:learning_training_master, "が見つかりませんでした")
      return render :index
    end

    @new_student_training.learning_training_master = training_master

    if @new_student_training.save
      redirect_to learning_student_student_trainings_path(@student), notice: "トレーニングを割り当てました。"
    else
      render :index
    end
  end

  def edit
  end

  def update
    if @student_training.update(student_training_params)
      redirect_to learning_student_student_trainings_path(@student_training.learning_student), notice: "割当内容を更新しました。"
    else
      render :edit
    end
  end

  def destroy
    student = @student_training.learning_student
    @student_training.destroy
    redirect_to learning_student_student_trainings_path(student), notice: "割当を削除しました。"
  end

  def mark
    if @student_training.update(achievement_mark: params[:achievement_mark])
      redirect_to learning_student_student_trainings_path(@student_training.learning_student), notice: "達成記号を更新しました。"
    else
      redirect_to learning_student_student_trainings_path(@student_training.learning_student), alert: "達成記号を更新できませんでした。"
    end
  end

  def reorder
    ordered_ids = Array(params[:ordered_ids]).map(&:to_i)
    trainings = @student.learning_student_trainings.where(id: ordered_ids).index_by(&:id)

    ActiveRecord::Base.transaction do
      ordered_ids.each_with_index do |id, index|
        trainings[id]&.update!(position: index + 1)
      end
    end

    head :ok
  end

  private

  def set_student
    @student = current_customer.learning_students.find(params[:student_id])
  end

  def set_student_training
    @student_training = current_customer.learning_student_trainings.find(params[:id])
  end

  def student_training_params
    params.require(:learning_student_training).permit(
      :status,
      :achievement_mark,
      :weekly_goal,
      :teacher_comment,
      :part,
      :period,
      :level,
      :title,
      :description,
      :achievement_criteria,
      :frequency
    )
  end

  def student_training_create_params
    params.require(:learning_student_training).permit(:learning_training_master_id, :weekly_goal, :teacher_comment)
  end

  def filter_params
    params.permit(:keyword, :status, :part, :level)
  end

  def prepare_index_resources
    @student_trainings = @student.learning_student_trainings
      .with_filters(filter_params)
      .ordered
      .to_a
    @training_masters = current_customer.learning_training_masters
      .individual_training
      .where(part: @student.main_part)
      .ordered
    @new_student_training ||= @student.learning_student_trainings.new(customer: current_customer)
    achievement_count = @student_trainings.count(&:star?)
    @training_master_groups = build_training_master_groups(@training_masters)
    @training_schedule = build_training_schedule(@student, @training_masters, @student_trainings)
    @summary = {
      total_count: @student_trainings.count,
      achievement_count: achievement_count,
      progress_rate: @student_trainings.count.zero? ? 0 : ((achievement_count.to_f / @student_trainings.count) * 100).round
    }
  end

  def build_training_master_groups(training_masters)
    training_masters.group_by { |master| [master.part, master.level] }.map do |(part, level), masters|
      group_label = "#{LearningCatalog.label_for_part(part)} / #{level}"
      options = masters.map do |master|
        ["#{master.period} / #{master.title}", master.id]
      end
      [group_label, options]
    end.to_h
  end

  def build_training_schedule(student, training_masters, student_trainings)
    masters = training_masters.select { |master| master.part == student.main_part }
    student_trainings_by_period = student_trainings
      .select { |training| training.part == student.main_part }
      .group_by(&:period)

    schedule = LearningCatalog::PERIODS.filter_map do |period|
      period_masters = masters.select { |master| master.period == period }
      next if period_masters.blank?

      assigned_trainings = student_trainings_by_period[period].to_a
      assigned_titles = assigned_trainings.map(&:title).uniq
      completed_titles = assigned_trainings.select(&:star?).map(&:title).uniq
      available_titles = period_masters.map(&:title).uniq
      completed = assigned_titles.present? && (assigned_titles - completed_titles).empty?
      target_count = assigned_titles.count.nonzero? || available_titles.count

      {
        period: period,
        levels: period_masters.map(&:level).uniq,
        titles: period_masters.map(&:title),
        count: target_count,
        completed: completed,
        assigned_count: assigned_titles.count,
        completed_count: completed_titles.count
      }
    end

    current_index = schedule.index { |entry| !entry[:completed] }

    schedule.each_with_index.map do |entry, index|
      state =
        if entry[:completed]
          "done"
        elsif current_index == index
          "current"
        else
          "upcoming"
        end

      entry.merge(state: state)
    end
  end
end
