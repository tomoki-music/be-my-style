class Learning::LineConnectionsController < Learning::BaseController
  layout "learning_public", only: [:connect, :callback]

  skip_before_action :authenticate_customer!, only: [:connect, :callback, :webhook]
  skip_before_action :ensure_learning_access!, only: [:connect, :callback, :webhook]
  skip_before_action :verify_authenticity_token, only: :webhook
  before_action :set_student, only: [:show, :create]

  DUMMY_LINE_USER_ID_PREFIX = "dummy-line-user".freeze

  def show
    @line_connection = line_connection_for_student
    @connect_url = connect_url_for(@line_connection) if @line_connection&.token_active?
  end

  def create
    @line_connection = line_connection_for_student

    if @line_connection.connected?
      redirect_to learning_student_line_connection_path(@student), notice: "この生徒はすでにLINE連携済みです。"
      return
    end

    @line_connection.issue_connect_token!
    redirect_to learning_student_line_connection_path(@student), notice: "LINE連携QRを発行しました。有効期限は24時間です。"
  end

  def connect
    @line_connection = Learning::LineConnection.find_by_active_token(params[:token])

    if @line_connection
      @student = @line_connection.learning_student
      @connect_token = @line_connection.connect_token
      @line_message_text = "BeMyStyle LINE連携 token=#{@connect_token}"
      @line_share_url = "https://line.me/R/msg/text/?#{ERB::Util.url_encode(@line_message_text)}"
    else
      render :invalid, status: :unprocessable_entity
    end
  end

  def callback
    if Rails.env.production?
      render :invalid, status: :not_found
      return
    end

    @line_connection = Learning::LineConnection.find_by_active_token(params[:token])

    if @line_connection
      complete_connection!(@line_connection)
      @student = @line_connection.learning_student
      render :completed
    else
      render :invalid, status: :unprocessable_entity
    end
  end

  def webhook
    result = Learning::LineWebhookProcessor.new.process(
      raw_body: request.raw_post,
      signature: request.headers["X-Line-Signature"]
    )

    render json: { status: result.status, processed: result.processed_count, connected: result.connected_count },
           status: webhook_status_for(result)
  end

  private

  def set_student
    @student = current_customer.learning_students.find(params[:student_id])
  end

  def line_connection_for_student
    current_customer.learning_line_connections.find_or_create_by!(learning_student: @student) do |connection|
      connection.status = "pending"
    end
  end

  def connect_url_for(line_connection)
    learning_line_connect_url(token: line_connection.connect_token)
  end

  def complete_connection!(line_connection)
    line_connection.complete_connection!(
      line_user_id: dummy_line_user_id(line_connection),
      display_name: line_connection.learning_student&.display_name
    )
  end

  def dummy_line_user_id(line_connection)
    "#{DUMMY_LINE_USER_ID_PREFIX}-#{line_connection.id}"
  end

  def webhook_status_for(result)
    case result.status
    when :ok
      :ok
    when :not_configured
      :service_unavailable
    when :invalid_signature
      :unauthorized
    else
      :unprocessable_entity
    end
  end
end
