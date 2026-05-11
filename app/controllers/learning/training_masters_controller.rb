class Learning::TrainingMastersController < Learning::BaseController
  before_action :set_training_master, only: [:edit, :update, :destroy]

  def index
    @school_groups = current_customer.learning_school_groups.ordered
    @selected_school_group = current_customer.learning_school_groups.find_by(id: params[:learning_school_group_id])
    @training_masters = filtered_training_master_scope
      .with_filters(filter_params)
      .ordered
  end

  def new
    @training_master = current_customer.learning_training_masters.new(period: "1-2ヶ月", level: "基礎", part: "vocal")
  end

  def create
    @training_master = current_customer.learning_training_masters.new(training_master_params)

    if @training_master.save
      redirect_to learning_training_masters_path, notice: "トレーニングマスターを追加しました。"
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @training_master.update(training_master_params)
      redirect_to learning_training_masters_path, notice: "トレーニングマスターを更新しました。"
    else
      render :edit
    end
  end

  def destroy
    @training_master.destroy
    redirect_to learning_training_masters_path, notice: "トレーニングマスターを削除しました。"
  end

  private

  def set_training_master
    @training_master = current_customer.learning_training_masters.find(params[:id])
  end

  def training_master_params
    params.require(:learning_training_master).permit(
      :part,
      :period,
      :level,
      :title,
      :description,
      :check_method,
      :achievement_criteria,
      :judge_type,
      :frequency,
      :is_band_training
    )
  end

  def filter_params
    params.permit(:keyword, :part, :period, :level, :band)
  end

  def filtered_training_master_scope
    scope = current_customer.learning_training_masters
    return scope unless @selected_school_group.present?

    parts = @selected_school_group.learning_students.distinct.pluck(:main_part)
    return scope.none if parts.blank?

    scope.where(part: parts + ["band"])
  end
end
