require "rails_helper"

RSpec.describe Learning::LineWebhookProcessor do
  let(:channel_secret) { "phase32-line-secret" }
  let(:processor) { described_class.new(channel_secret: channel_secret) }

  it "judge_type self はLINE返信でcompletedになりProgressLogを作成すること" do
    assignment, student = assignment_with_judge_type("self")
    connect_line(student, "Uphase32Self")
    create_notification_log(assignment)
    body = webhook_body("やった", "Uphase32Self")

    expect {
      result = processor.process(raw_body: body, signature: signature_for(body))
      expect(result.reaction_count).to eq(1)
    }.to change(LearningProgressLog, :count).by(1)

    expect(assignment.reload.status).to eq("completed")
  end

  it "judge_type peer はLINE返信でcompletedになりProgressLogを作成すること" do
    assignment, student = assignment_with_judge_type("peer")
    connect_line(student, "Uphase32Peer")
    create_notification_log(assignment)
    body = webhook_body("done", "Uphase32Peer")

    expect {
      result = processor.process(raw_body: body, signature: signature_for(body))
      expect(result.reaction_count).to eq(1)
    }.to change(LearningProgressLog, :count).by(1)

    expect(assignment.reload.status).to eq("completed")
  end

  it "judge_type teacher はLINE返信でpending_reviewになり承認前のProgressLogを作成しないこと" do
    assignment, student = assignment_with_judge_type("teacher")
    connect_line(student, "Uphase32Teacher")
    create_notification_log(assignment)
    body = webhook_body("練習した", "Uphase32Teacher")

    expect {
      result = processor.process(raw_body: body, signature: signature_for(body))
      expect(result.reaction_count).to eq(1)
    }.not_to change(LearningProgressLog, :count)

    assignment.reload
    expect(assignment.status).to eq("pending_review")
    expect(assignment.submitted_at).to be_present
    expect(assignment.reaction_message).to eq("練習した")
  end

  it "judge_type teacher はLINE replyTokenがあれば先生確認待ちを返信すること" do
    line_adapter = instance_double(Learning::LineNotificationAdapter)
    processor = described_class.new(channel_secret: channel_secret, line_adapter: line_adapter)
    allow(line_adapter).to receive(:reply).and_return(
      Learning::LineNotificationAdapter::Result.new(status: :ok, message: "sent", payload: {})
    )
    assignment, student = assignment_with_judge_type("teacher")
    connect_line(student, "Uphase32TeacherReply")
    create_notification_log(assignment)
    body = webhook_body("やった", "Uphase32TeacherReply", reply_token: "reply-token-123")

    processor.process(raw_body: body, signature: signature_for(body))

    expect(line_adapter).to have_received(:reply).with(
      reply_token: "reply-token-123",
      text: "報告ありがとう！このトレーニングは先生確認が必要です。先生の確認後に完了になります。"
    )
  end

  private

  def assignment_with_judge_type(judge_type)
    teacher = create(:customer, domain_name: "learning")
    student = create(:learning_student, customer: teacher)
    master = create(:learning_training_master, customer: teacher, judge_type: judge_type)
    training = create(:learning_student_training,
                      customer: teacher,
                      learning_student: student,
                      learning_training_master: master,
                      title: nil)
    [training.learning_assignments.first, student]
  end

  def connect_line(student, line_user_id)
    create(:learning_line_connection,
           customer: student.customer,
           learning_student: student,
           line_user_id: line_user_id,
           status: "connected",
           connected_at: Time.current)
  end

  def create_notification_log(assignment)
    create(:learning_notification_log,
           customer: assignment.customer,
           learning_student: assignment.learning_student,
           delivery_channel: "line",
           status: "sent",
           notification_type: "assignment_created",
           sent_at: 10.minutes.ago,
           metadata: { learning_assignment_id: assignment.id })
  end

  def webhook_body(text, user_id, reply_token: nil)
    {
      events: [
        {
          type: "message",
          replyToken: reply_token,
          source: { userId: user_id },
          message: { type: "text", text: text }
        }.compact
      ]
    }.to_json
  end

  def signature_for(body)
    Base64.strict_encode64(OpenSSL::HMAC.digest(OpenSSL::Digest.new("sha256"), channel_secret, body))
  end
end
