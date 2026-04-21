class Learning::BandTrainingsController < Learning::BaseController
  before_action :set_band_training, only: [:edit, :update, :destroy, :mark]
  before_action :load_supporting_resources, only: [:new, :create, :edit, :update, :index]

  def index
    @school_groups = current_customer.learning_school_groups.ordered
    @selected_school_group = current_customer.learning_school_groups.find_by(id: params[:learning_school_group_id])
    @bands = filtered_band_scope
    @selected_band = @bands.find_by(id: params[:band_id]) if params[:band_id].present?
    @band_trainings = filtered_band_trainings
    @training_schedule = build_training_schedule(@training_masters, @band_trainings)
  end

  def new
    @band_training = current_customer.learning_band_trainings.new(part: "band", period: "1-2ヶ月", level: "基礎", learning_band: @bands.first)
  end

  def create
    @band_training = current_customer.learning_band_trainings.new(band_training_params)
    assign_related_parts(@band_training)

    if @band_training.save
      redirect_to learning_band_trainings_path(band_id: @band_training.learning_band_id), notice: "バンド練習を追加しました。"
    else
      render :new
    end
  end

  def edit
  end

  def update
    @band_training.assign_attributes(band_training_params)
    assign_related_parts(@band_training)

    if @band_training.save
      redirect_to learning_band_trainings_path(band_id: @band_training.learning_band_id), notice: "バンド練習を更新しました。"
    else
      render :edit
    end
  end

  def destroy
    band_id = @band_training.learning_band_id
    @band_training.destroy
    redirect_to learning_band_trainings_path(band_id: band_id), notice: "バンド練習を削除しました。"
  end

  def mark
    if @band_training.update(achievement_mark: params[:achievement_mark])
      redirect_to learning_band_trainings_path(band_id: @band_training.learning_band_id), notice: "達成記号を更新しました。"
    else
      redirect_to learning_band_trainings_path(band_id: @band_training.learning_band_id), alert: "達成記号を更新できませんでした。"
    end
  end

  private

  def set_band_training
    @band_training = current_customer.learning_band_trainings.find(params[:id])
  end

  def load_supporting_resources
    @bands = current_customer.learning_bands.ordered
    @training_masters = current_customer.learning_training_masters.band_training.ordered
  end

  def filtered_band_scope
    scope = current_customer.learning_bands.includes(:learning_band_trainings).ordered
    return scope unless @selected_school_group.present?

    current_customer.learning_bands
      .joins(:learning_students)
      .where(learning_students: { learning_school_group_id: @selected_school_group.id })
      .includes(:learning_band_trainings)
      .distinct
      .ordered
  end

  def filtered_band_trainings
    return @selected_band.learning_band_trainings.ordered if @selected_band.present?

    band_ids = @bands.map(&:id)
    return LearningBandTraining.none if band_ids.blank?

    current_customer.learning_band_trainings
      .joins(:learning_band)
      .includes(:learning_band)
      .where(learning_band_id: band_ids)
      .order("learning_bands.name ASC, learning_band_trainings.position ASC, learning_band_trainings.created_at ASC")
  end

  def build_training_schedule(training_masters, band_trainings)
    band_trainings_by_period = band_trainings.group_by(&:period)

    schedule = LearningCatalog::PERIODS.filter_map do |period|
      period_masters = training_masters.select { |master| master.period == period }
      next if period_masters.blank?

      assigned_trainings = band_trainings_by_period[period].to_a
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

  def band_training_params
    params.require(:learning_band_training).permit(
      :learning_band_id,
      :learning_training_master_id,
      :part,
      :period,
      :level,
      :title,
      :description,
      :achievement_criteria,
      :frequency,
      :related_parts,
      :status,
      :achievement_mark,
      :teacher_comment
    )
  end

  def assign_related_parts(band_training)
    band_training.related_parts = Array(params[:learning_band_training_related_parts]).map(&:presence).compact.uniq.join(",")
  end
end
