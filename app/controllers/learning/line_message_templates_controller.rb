class Learning::LineMessageTemplatesController < Learning::BaseController
  before_action :set_template, only: [:edit, :update]

  def index
    @templates = current_customer.learning_line_message_templates.ordered
  end

  def new
    @template = current_customer.learning_line_message_templates.new(category: "custom", active: true)
  end

  def create
    @template = current_customer.learning_line_message_templates.new(template_params)

    if @template.save
      redirect_to learning_line_message_templates_path, notice: "LINEテンプレートを作成しました。"
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @template.update(template_params)
      redirect_to learning_line_message_templates_path, notice: "LINEテンプレートを更新しました。"
    else
      render :edit
    end
  end

  private

  def set_template
    @template = current_customer.learning_line_message_templates.find(params[:id])
  end

  def template_params
    params.require(:learning_line_message_template).permit(:title, :category, :body, :active)
  end
end
