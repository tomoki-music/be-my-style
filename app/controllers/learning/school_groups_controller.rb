class Learning::SchoolGroupsController < Learning::BaseController
  before_action :set_school_group, only: [:show, :edit, :update, :destroy]

  def index
    @school_groups = current_customer.learning_school_groups
      .includes(learning_students: :learning_student_trainings)
      .with_filters(filter_params)
      .ordered
  end

  def show
    @dashboard = Learning::DashboardBuilder.new(current_customer, school_group: @school_group).build
    @students = @school_group.learning_students
      .includes(:learning_student_parts, :learning_student_trainings)
      .ordered
  end

  def new
    @school_group = current_customer.learning_school_groups.new
  end

  def create
    @school_group = current_customer.learning_school_groups.new(school_group_params)

    if @school_group.save
      redirect_to learning_school_group_path(@school_group), notice: "高校グループを作成しました。"
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @school_group.update(school_group_params)
      redirect_to learning_school_group_path(@school_group), notice: "高校グループを更新しました。"
    else
      render :edit
    end
  end

  def destroy
    @school_group.destroy
    redirect_to learning_school_groups_path, notice: "高校グループを削除しました。"
  end

  private

  def set_school_group
    @school_group = current_customer.learning_school_groups.find(params[:id])
  end

  def school_group_params
    params.require(:learning_school_group).permit(:name, :memo)
  end

  def filter_params
    params.permit(:keyword)
  end
end
