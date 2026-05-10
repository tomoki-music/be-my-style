require "rails_helper"

RSpec.describe "Learning line webhooks", type: :request do
  let!(:learning_domain) { Domain.find_or_create_by!(name: "learning") }
  let(:teacher) { create(:customer, domain_name: "learning", confirmed_at: Time.current) }
  let(:student) { create(:learning_student, customer: teacher, nickname: "ギターさん") }
  let(:channel_secret) { "line-channel-secret-for-spec" }

  around do |example|
    original_secret = ENV["LINE_CHANNEL_SECRET"]
    ENV.delete("LINE_CHANNEL_SECRET")
    example.run
    ENV["LINE_CHANNEL_SECRET"] = original_secret
  end

  describe "POST /learning/line/webhook" do
    it "LINE_CHANNEL_SECRET未設定なら安全に失敗すること" do
      post learning_line_webhook_path,
           params: webhook_body("events" => []),
           headers: { "CONTENT_TYPE" => "application/json", "X-Line-Signature" => "invalid" }

      expect(response).to have_http_status(:service_unavailable)
      expect(JSON.parse(response.body)["status"]).to eq("not_configured")
    end

    it "署名が不正なら処理しないこと" do
      ENV["LINE_CHANNEL_SECRET"] = channel_secret
      connection = create(:learning_line_connection, customer: teacher, learning_student: student, line_user_id: nil)
      connection.issue_connect_token!

      post learning_line_webhook_path,
           params: webhook_body(message_event(connection.connect_token)),
           headers: { "CONTENT_TYPE" => "application/json", "X-Line-Signature" => "invalid" }

      expect(response).to have_http_status(:unauthorized)
      expect(connection.reload).not_to be_connected
    end

    it "messageイベントのtokenから本物のline_user_idを保存すること" do
      ENV["LINE_CHANNEL_SECRET"] = channel_secret
      connection = create(:learning_line_connection, customer: teacher, learning_student: student, line_user_id: nil)
      connection.issue_connect_token!
      body = webhook_body(message_event(connection.connect_token, user_id: "UrealLineUserId"))

      post learning_line_webhook_path,
           params: body,
           headers: { "CONTENT_TYPE" => "application/json", "X-Line-Signature" => signature_for(body) }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include("status" => "ok", "processed" => 1, "connected" => 1)
      expect(connection.reload).to be_connected
      expect(connection.line_user_id).to eq("UrealLineUserId")
      expect(connection.connect_token).to be_nil
      expect(connection.expires_at).to be_nil
    end

    it "postbackイベントのtokenから本物のline_user_idを保存すること" do
      ENV["LINE_CHANNEL_SECRET"] = channel_secret
      connection = create(:learning_line_connection, customer: teacher, learning_student: student, line_user_id: nil)
      connection.issue_connect_token!
      body = webhook_body(postback_event(connection.connect_token, user_id: "UpostbackLineUserId"))

      post learning_line_webhook_path,
           params: body,
           headers: { "CONTENT_TYPE" => "application/json", "X-Line-Signature" => signature_for(body) }

      expect(response).to have_http_status(:ok)
      expect(connection.reload.line_user_id).to eq("UpostbackLineUserId")
    end

    it "followイベントだけではtokenがないため紐付けないこと" do
      ENV["LINE_CHANNEL_SECRET"] = channel_secret
      connection = create(:learning_line_connection, customer: teacher, learning_student: student, line_user_id: nil)
      connection.issue_connect_token!
      body = webhook_body(follow_event(user_id: "UfollowLineUserId"))

      post learning_line_webhook_path,
           params: body,
           headers: { "CONTENT_TYPE" => "application/json", "X-Line-Signature" => signature_for(body) }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["connected"]).to eq(0)
      expect(connection.reload).not_to be_connected
    end

    it "使用済みtokenは再利用できないこと" do
      ENV["LINE_CHANNEL_SECRET"] = channel_secret
      connection = create(:learning_line_connection, customer: teacher, learning_student: student, line_user_id: nil)
      connection.issue_connect_token!
      token = connection.connect_token
      first_body = webhook_body(message_event(token, user_id: "UfirstLineUserId"))
      second_body = webhook_body(message_event(token, user_id: "UsecondLineUserId"))

      post learning_line_webhook_path,
           params: first_body,
           headers: { "CONTENT_TYPE" => "application/json", "X-Line-Signature" => signature_for(first_body) }
      post learning_line_webhook_path,
           params: second_body,
           headers: { "CONTENT_TYPE" => "application/json", "X-Line-Signature" => signature_for(second_body) }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["connected"]).to eq(0)
      expect(connection.reload.line_user_id).to eq("UfirstLineUserId")
    end

    it "やった系の返信から通知リアクションと簡易練習記録を保存すること" do
      ENV["LINE_CHANNEL_SECRET"] = channel_secret
      create(:learning_line_connection,
             customer: teacher,
             learning_student: student,
             line_user_id: "UreactionLineUserId",
             status: "connected",
             connected_at: Time.current)
      create(:learning_student_training,
             customer: teacher,
             learning_student: student,
             title: "リズム練習")
      notification_log = create(:learning_notification_log,
                                customer: teacher,
                                learning_student: student,
                                delivery_channel: "line",
                                status: "sent",
                                sent_at: 10.minutes.ago,
                                reaction_received: false)
      body = webhook_body(reaction_event("やった", user_id: "UreactionLineUserId"))

      expect {
        post learning_line_webhook_path,
             params: body,
             headers: { "CONTENT_TYPE" => "application/json", "X-Line-Signature" => signature_for(body) }
      }.to change(LearningProgressLog, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["reactions"]).to eq(1)
      expect(notification_log.reload).to be_reaction_received
      expect(notification_log.reaction_message).to eq("やった")
      expect(notification_log.reacted_at).to be_present
      expect(student.reload.last_learning_action_at).to be_present
      expect(LearningProgressLog.last.training_title).to eq("リズム練習")
      expect(LearningProgressLog.last.comment).to include("LINE返信から自動記録")
    end

    it "同じ日に複数回返信しても練習記録は重複作成しないこと" do
      ENV["LINE_CHANNEL_SECRET"] = channel_secret
      create(:learning_line_connection,
             customer: teacher,
             learning_student: student,
             line_user_id: "UduplicateReactionUserId",
             status: "connected",
             connected_at: Time.current)
      create(:learning_progress_log, customer: teacher, learning_student: student, practiced_on: Date.current)
      notification_log = create(:learning_notification_log,
                                customer: teacher,
                                learning_student: student,
                                delivery_channel: "line",
                                status: "sent",
                                sent_at: 10.minutes.ago,
                                reaction_received: false)
      body = webhook_body(reaction_event("完了", user_id: "UduplicateReactionUserId"))

      expect {
        post learning_line_webhook_path,
             params: body,
             headers: { "CONTENT_TYPE" => "application/json", "X-Line-Signature" => signature_for(body) }
      }.not_to change(LearningProgressLog, :count)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["reactions"]).to eq(1)
      expect(notification_log.reload.reaction_message).to eq("完了")
    end

    it "本番テスト送信相当のteacher_action通知にもreactionを保存すること" do
      ENV["LINE_CHANNEL_SECRET"] = channel_secret
      create(:learning_line_connection,
             customer: teacher,
             learning_student: student,
             line_user_id: "UteacherActionUserId",
             status: "connected",
             connected_at: Time.current)
      notification_log = create(:learning_notification_log,
                                customer: teacher,
                                learning_student: student,
                                notification_type: "teacher_action",
                                delivery_channel: "line",
                                status: "sent",
                                sent_at: 1.minute.ago,
                                reaction_received: false,
                                title: "LINEテスト送信")
      body = webhook_body(reaction_event("やった", user_id: "UteacherActionUserId"))

      post learning_line_webhook_path,
           params: body,
           headers: { "CONTENT_TYPE" => "application/json", "X-Line-Signature" => signature_for(body) }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["reactions"]).to eq(1)
      expect(notification_log.reload).to be_reaction_received
      expect(notification_log.reaction_message).to eq("やった")
      expect(notification_log.reacted_at).to be_present
    end

    it "やった！で最新sent通知にreactionを保存し元メッセージを残すこと" do
      ENV["LINE_CHANNEL_SECRET"] = channel_secret
      create(:learning_line_connection,
             customer: teacher,
             learning_student: student,
             line_user_id: "UreactionBangUserId",
             status: "connected",
             connected_at: Time.current)
      notification_log = create(:learning_notification_log,
                                customer: teacher,
                                learning_student: student,
                                notification_type: "teacher_action",
                                delivery_channel: "line",
                                status: "sent",
                                sent_at: 1.minute.ago,
                                reaction_received: false)
      body = webhook_body(reaction_event("やった！", user_id: "UreactionBangUserId"))

      post learning_line_webhook_path,
           params: body,
           headers: { "CONTENT_TYPE" => "application/json", "X-Line-Signature" => signature_for(body) }

      expect(response).to have_http_status(:ok)
      expect(notification_log.reload).to be_reaction_received
      expect(notification_log.reaction_message).to eq("やった！")
    end

    it "OKに絵文字が付いていてもreactionを保存すること" do
      ENV["LINE_CHANNEL_SECRET"] = channel_secret
      create(:learning_line_connection,
             customer: teacher,
             learning_student: student,
             line_user_id: "UreactionOkEmojiUserId",
             status: "connected",
             connected_at: Time.current)
      notification_log = create(:learning_notification_log,
                                customer: teacher,
                                learning_student: student,
                                notification_type: "teacher_action",
                                delivery_channel: "line",
                                status: "sent",
                                sent_at: 1.minute.ago,
                                reaction_received: false)
      body = webhook_body(reaction_event("OK🙆‍♂️", user_id: "UreactionOkEmojiUserId"))

      post learning_line_webhook_path,
           params: body,
           headers: { "CONTENT_TYPE" => "application/json", "X-Line-Signature" => signature_for(body) }

      expect(response).to have_http_status(:ok)
      expect(notification_log.reload).to be_reaction_received
      expect(notification_log.reaction_message).to eq("OK🙆‍♂️")
    end

    it "練習しましたでreactionを保存すること" do
      ENV["LINE_CHANNEL_SECRET"] = channel_secret
      create(:learning_line_connection,
             customer: teacher,
             learning_student: student,
             line_user_id: "UreactionPracticedUserId",
             status: "connected",
             connected_at: Time.current)
      notification_log = create(:learning_notification_log,
                                customer: teacher,
                                learning_student: student,
                                notification_type: "teacher_action",
                                delivery_channel: "line",
                                status: "sent",
                                sent_at: 1.minute.ago,
                                reaction_received: false)
      body = webhook_body(reaction_event("練習しました", user_id: "UreactionPracticedUserId"))

      post learning_line_webhook_path,
           params: body,
           headers: { "CONTENT_TYPE" => "application/json", "X-Line-Signature" => signature_for(body) }

      expect(response).to have_http_status(:ok)
      expect(notification_log.reload).to be_reaction_received
      expect(notification_log.reaction_message).to eq("練習しました")
    end

    it "sent通知が複数ある場合は最新の未reaction通知に保存すること" do
      ENV["LINE_CHANNEL_SECRET"] = channel_secret
      create(:learning_line_connection,
             customer: teacher,
             learning_student: student,
             line_user_id: "UmultipleSentUserId",
             status: "connected",
             connected_at: Time.current)
      old_log = create(:learning_notification_log,
                       customer: teacher,
                       learning_student: student,
                       notification_type: "reminder",
                       delivery_channel: "line",
                       status: "sent",
                       sent_at: 3.hours.ago,
                       reaction_received: false)
      latest_reacted_log = create(:learning_notification_log,
                                  customer: teacher,
                                  learning_student: student,
                                  notification_type: "reminder",
                                  delivery_channel: "line",
                                  status: "sent",
                                  sent_at: 2.hours.ago,
                                  reaction_received: true,
                                  reacted_at: 90.minutes.ago,
                                  reaction_message: "完了")
      latest_unreacted_log = create(:learning_notification_log,
                                    customer: teacher,
                                    learning_student: student,
                                    notification_type: "teacher_action",
                                    delivery_channel: "line",
                                    status: "sent",
                                    sent_at: 10.minutes.ago,
                                    reaction_received: false)
      body = webhook_body(reaction_event("OK", user_id: "UmultipleSentUserId"))

      post learning_line_webhook_path,
           params: body,
           headers: { "CONTENT_TYPE" => "application/json", "X-Line-Signature" => signature_for(body) }

      expect(response).to have_http_status(:ok)
      expect(latest_unreacted_log.reload).to be_reaction_received
      expect(latest_unreacted_log.reaction_message).to eq("OK")
      expect(old_log.reload).not_to be_reaction_received
      expect(latest_reacted_log.reload.reaction_message).to eq("完了")
    end

    it "不明メッセージでは練習記録を作らないこと" do
      ENV["LINE_CHANNEL_SECRET"] = channel_secret
      create(:learning_line_connection,
             customer: teacher,
             learning_student: student,
             line_user_id: "UunknownMessageUserId",
             status: "connected",
             connected_at: Time.current)
      notification_log = create(:learning_notification_log,
                                customer: teacher,
                                learning_student: student,
                                delivery_channel: "line",
                                status: "sent",
                                sent_at: 10.minutes.ago,
                                reaction_received: false)
      body = webhook_body(reaction_event("またあとで", user_id: "UunknownMessageUserId"))

      expect {
        post learning_line_webhook_path,
             params: body,
             headers: { "CONTENT_TYPE" => "application/json", "X-Line-Signature" => signature_for(body) }
      }.not_to change(LearningProgressLog, :count)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["reactions"]).to eq(0)
      expect(notification_log.reload).not_to be_reaction_received
    end

    it "問い合わせ文はreaction扱いしないこと" do
      ENV["LINE_CHANNEL_SECRET"] = channel_secret
      create(:learning_line_connection,
             customer: teacher,
             learning_student: student,
             line_user_id: "UquestionMessageUserId",
             status: "connected",
             connected_at: Time.current)
      notification_log = create(:learning_notification_log,
                                customer: teacher,
                                learning_student: student,
                                delivery_channel: "line",
                                status: "sent",
                                sent_at: 10.minutes.ago,
                                reaction_received: false)
      body = webhook_body(reaction_event("OKですか？", user_id: "UquestionMessageUserId"))

      post learning_line_webhook_path,
           params: body,
           headers: { "CONTENT_TYPE" => "application/json", "X-Line-Signature" => signature_for(body) }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["reactions"]).to eq(0)
      expect(notification_log.reload).not_to be_reaction_received
    end

    it "token連携メッセージはreaction扱いしないこと" do
      ENV["LINE_CHANNEL_SECRET"] = channel_secret
      connection = create(:learning_line_connection, customer: teacher, learning_student: student, line_user_id: nil)
      connection.issue_connect_token!
      body = webhook_body(message_event(connection.connect_token, user_id: "UtokenOnlyUserId"))

      expect {
        post learning_line_webhook_path,
             params: body,
             headers: { "CONTENT_TYPE" => "application/json", "X-Line-Signature" => signature_for(body) }
      }.not_to change(LearningProgressLog, :count)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include("connected" => 1, "reactions" => 0)
    end

    it "token文字列を含む連携メッセージは既存連携済みでもreaction扱いしないこと" do
      ENV["LINE_CHANNEL_SECRET"] = channel_secret
      create(:learning_line_connection,
             customer: teacher,
             learning_student: student,
             line_user_id: "UconnectedTokenMessageUserId",
             status: "connected",
             connected_at: Time.current)
      notification_log = create(:learning_notification_log,
                                customer: teacher,
                                learning_student: student,
                                delivery_channel: "line",
                                status: "sent",
                                sent_at: 10.minutes.ago,
                                reaction_received: false)
      body = webhook_body(reaction_event("BeMyStyle LINE連携 token=abcdefghijklmnopqrstuvwxyz", user_id: "UconnectedTokenMessageUserId"))

      post learning_line_webhook_path,
           params: body,
           headers: { "CONTENT_TYPE" => "application/json", "X-Line-Signature" => signature_for(body) }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["reactions"]).to eq(0)
      expect(notification_log.reload).not_to be_reaction_received
    end

    it "text以外のmessage eventではreaction扱いしないこと" do
      ENV["LINE_CHANNEL_SECRET"] = channel_secret
      create(:learning_line_connection,
             customer: teacher,
             learning_student: student,
             line_user_id: "UimageMessageUserId",
             status: "connected",
             connected_at: Time.current)
      notification_log = create(:learning_notification_log,
                                customer: teacher,
                                learning_student: student,
                                delivery_channel: "line",
                                status: "sent",
                                sent_at: 10.minutes.ago,
                                reaction_received: false)
      body = webhook_body(image_message_event(user_id: "UimageMessageUserId"))

      post learning_line_webhook_path,
           params: body,
           headers: { "CONTENT_TYPE" => "application/json", "X-Line-Signature" => signature_for(body) }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["reactions"]).to eq(0)
      expect(notification_log.reload).not_to be_reaction_received
    end

    it "reaction済み通知は再返信で上書きしないこと" do
      ENV["LINE_CHANNEL_SECRET"] = channel_secret
      create(:learning_line_connection,
             customer: teacher,
             learning_student: student,
             line_user_id: "UalreadyReactedUserId",
             status: "connected",
             connected_at: Time.current)
      notification_log = create(:learning_notification_log,
                                customer: teacher,
                                learning_student: student,
                                delivery_channel: "line",
                                status: "sent",
                                sent_at: 10.minutes.ago,
                                reaction_received: true,
                                reacted_at: 5.minutes.ago,
                                reaction_message: "やった")
      body = webhook_body(reaction_event("完了", user_id: "UalreadyReactedUserId"))

      post learning_line_webhook_path,
           params: body,
           headers: { "CONTENT_TYPE" => "application/json", "X-Line-Signature" => signature_for(body) }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["reactions"]).to eq(1)
      expect(notification_log.reload.reaction_message).to eq("やった")
    end

    it "同じline_user_idの複数連携がある場合は最新のconnected生徒へ紐付けること" do
      ENV["LINE_CHANNEL_SECRET"] = channel_secret
      older_student = create(:learning_student, customer: teacher, nickname: "古い生徒")
      create(:learning_line_connection,
             customer: teacher,
             learning_student: older_student,
             line_user_id: "UsharedLineUserId",
             status: "connected",
             connected_at: 2.days.ago)
      create(:learning_line_connection,
             customer: teacher,
             learning_student: student,
             line_user_id: "UsharedLineUserId",
             status: "connected",
             connected_at: Time.current)
      create(:learning_notification_log,
             customer: teacher,
             learning_student: student,
             delivery_channel: "line",
             status: "sent",
             sent_at: 10.minutes.ago)
      body = webhook_body(reaction_event("OK", user_id: "UsharedLineUserId"))

      post learning_line_webhook_path,
           params: body,
           headers: { "CONTENT_TYPE" => "application/json", "X-Line-Signature" => signature_for(body) }

      expect(response).to have_http_status(:ok)
      expect(LearningProgressLog.last.learning_student).to eq(student)
      expect(older_student.learning_progress_logs).to be_empty
    end
  end

  def webhook_body(*events)
    { destination: "UbotDestination", events: events.flatten }.to_json
  end

  def message_event(token, user_id: "UrealLineUserId")
    {
      type: "message",
      source: { type: "user", userId: user_id },
      message: { type: "text", text: "BeMyStyle LINE連携 token=#{token}" }
    }
  end

  def postback_event(token, user_id:)
    {
      type: "postback",
      source: { type: "user", userId: user_id },
      postback: { data: "token=#{token}" }
    }
  end

  def follow_event(user_id:)
    {
      type: "follow",
      source: { type: "user", userId: user_id }
    }
  end

  def reaction_event(text, user_id:)
    {
      type: "message",
      source: { type: "user", userId: user_id },
      message: { type: "text", text: text }
    }
  end

  def image_message_event(user_id:)
    {
      type: "message",
      source: { type: "user", userId: user_id },
      message: { type: "image", id: "line-image-message-id" }
    }
  end

  def signature_for(body)
    Base64.strict_encode64(
      OpenSSL::HMAC.digest(OpenSSL::Digest.new("sha256"), channel_secret, body)
    )
  end
end
