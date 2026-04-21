class Learning::BandsController < Learning::BaseController
  before_action :set_band, only: [:show, :edit, :update, :destroy]
  before_action :load_students, only: [:new, :create, :edit, :update]

  def index
    @bands = current_customer.learning_bands.includes(:learning_students, :learning_band_trainings).ordered
  end

  def show
    @band_trainings = @band.learning_band_trainings.ordered
    @students = @band.learning_students.includes(:learning_student_parts).ordered
  end

  def new
    @band = current_customer.learning_bands.new
  end

  def create
    @band = current_customer.learning_bands.new(band_params)

    if save_band_with_students(@band)
      redirect_to learning_band_trainings_path(band_id: @band.id), notice: "バンドグループを作成しました。"
    else
      render :new
    end
  end

  def edit
  end

  def update
    @band.assign_attributes(band_params)

    if save_band_with_students(@band)
      redirect_to learning_band_trainings_path(band_id: @band.id), notice: "バンドグループを更新しました。"
    else
      render :edit
    end
  end

  def destroy
    @band.destroy
    redirect_to learning_bands_path, notice: "バンドグループを削除しました。"
  end

  private

  def set_band
    @band = current_customer.learning_bands.find(params[:id])
  end

  def band_params
    params.require(:learning_band).permit(:name, :memo)
  end

  def load_students
    @students = current_customer.learning_students.includes(:learning_student_parts).ordered
  end

  def save_band_with_students(band)
    ActiveRecord::Base.transaction do
      band.save!
      band.sync_students!(params.dig(:learning_band, :student_ids))
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end
end
