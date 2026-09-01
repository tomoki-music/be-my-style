require "rails_helper"

RSpec.describe AdminCustomerFeedbackNotifier do
  let(:customer) { create(:customer, name: "投稿者太郎", email: "poster@example.com") }
  let(:feedback) { create(:customer_feedback, customer: customer, subject: "検索が動かない", body: "本文の中身です") }

  def mail_matcher
    have_enqueued_mail(AdminNotificationMailer, :customer_feedback_created)
  end

  describe ".call" do
    context "Admin 件数ごとの enqueue" do
      it "Admin 0 件なら enqueue しないこと" do
        expect { described_class.call(feedback) }.not_to mail_matcher
      end

      it "Admin 1 件なら 1 通 enqueue すること" do
        create(:admin)
        expect { described_class.call(feedback) }.to mail_matcher.once
      end

      it "Admin 複数なら人数分 enqueue すること" do
        create_list(:admin, 3)
        expect { described_class.call(feedback) }.to mail_matcher.exactly(3).times
      end
    end

    context "未保存 / nil の feedback" do
      it "未保存の feedback では enqueue しないこと" do
        create(:admin)
        expect { described_class.call(build(:customer_feedback, customer: customer)) }.not_to mail_matcher
      end

      it "nil を渡してもエラーにならず enqueue もしないこと" do
        create(:admin)
        expect { described_class.call(nil) }.not_to raise_error
        expect { described_class.call(nil) }.not_to mail_matcher
      end
    end

    context "development 環境の送信ガード" do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))
        create(:admin)
      end

      around do |example|
        saved = ENV.to_hash.slice(described_class::ENABLE_ENV_KEY)
        ENV.delete(described_class::ENABLE_ENV_KEY)
        example.run
      ensure
        ENV.delete(described_class::ENABLE_ENV_KEY)
        saved.each { |key, value| ENV[key] = value }
      end

      it "ENV 未設定なら enqueue しないこと" do
        expect { described_class.call(feedback) }.not_to mail_matcher
      end

      it 'ENV="true" のときだけ enqueue すること' do
        ENV[described_class::ENABLE_ENV_KEY] = "true"
        expect { described_class.call(feedback) }.to mail_matcher.once
      end

      it 'ENV="TRUE" では enqueue しないこと' do
        ENV[described_class::ENABLE_ENV_KEY] = "TRUE"
        expect { described_class.call(feedback) }.not_to mail_matcher
      end

      it 'ENV="1" では enqueue しないこと' do
        ENV[described_class::ENABLE_ENV_KEY] = "1"
        expect { described_class.call(feedback) }.not_to mail_matcher
      end

      it 'ENV="yes" では enqueue しないこと' do
        ENV[described_class::ENABLE_ENV_KEY] = "yes"
        expect { described_class.call(feedback) }.not_to mail_matcher
      end

      it 'ENV="" では enqueue しないこと' do
        ENV[described_class::ENABLE_ENV_KEY] = ""
        expect { described_class.call(feedback) }.not_to mail_matcher
      end

      it "スキップログは feedback ID のみを含み、投稿本文・件名・投稿者情報を含めないこと" do
        allow(Rails.logger).to receive(:info)

        described_class.call(feedback)

        expect(Rails.logger).to have_received(:info).once do |message|
          expect(message).to include("feedback_id=#{feedback.id}")
          expect(message).not_to include(feedback.body)
          expect(message).not_to include(feedback.subject)
          expect(message).not_to include(customer.name)
          expect(message).not_to include(customer.email)
        end
      end
    end

    context "production 相当の環境" do
      before { allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production")) }

      around do |example|
        saved = ENV.to_hash.slice(described_class::ENABLE_ENV_KEY)
        ENV.delete(described_class::ENABLE_ENV_KEY)
        example.run
      ensure
        ENV.delete(described_class::ENABLE_ENV_KEY)
        saved.each { |key, value| ENV[key] = value }
      end

      it "ENV 未設定でも enqueue すること" do
        create(:admin)
        expect { described_class.call(feedback) }.to mail_matcher.once
      end
    end

    context "test 環境（既定）" do
      it "test adapter へ enqueue できること" do
        expect(ActiveJob::Base.queue_adapter_name).to eq("test")
        create(:admin)
        expect { described_class.call(feedback) }.to mail_matcher.once
      end
    end

    context "Admin ごとの例外処理" do
      before { create_list(:admin, 3) }

      # enqueue チェーン(AdminNotificationMailer.with(...).customer_feedback_created.deliver_later)を
      # adapter 非依存で差し替え、1 通目だけ失敗させる。
      def stub_delivery_chain(deliveries)
        parameterized = double("parameterized")
        allow(AdminNotificationMailer).to receive(:with).and_return(parameterized)
        allow(parameterized).to receive(:customer_feedback_created).and_return(*deliveries)
      end

      it "1 人目の enqueue が失敗しても残りの Admin へ継続すること" do
        bad = double("delivery")
        good = double("delivery")
        allow(bad).to receive(:deliver_later).and_raise(StandardError, "boom")
        allow(good).to receive(:deliver_later)
        stub_delivery_chain([bad, good, good])

        described_class.call(feedback)

        expect(good).to have_received(:deliver_later).twice
      end

      it "例外ログに feedback ID・admin ID・例外クラスのみを含み、例外メッセージ・本文・メールアドレスを含めないこと" do
        allow(Rails.logger).to receive(:error)
        # 例外メッセージに個人情報（宛先アドレス）が混入するケースを再現する
        pii_message = "SMTP failed for #{customer.email}"
        allow(AdminNotificationMailer).to receive(:with).and_raise(RuntimeError, pii_message)

        described_class.call(feedback)

        expect(Rails.logger).to have_received(:error).at_least(:once) do |message|
          expect(message).to include("feedback_id=#{feedback.id}")
          expect(message).to include("admin_id=")
          expect(message).to include("error_class=RuntimeError")
          expect(message).not_to include(pii_message)
          expect(message).not_to include("SMTP failed for")
          expect(message).not_to include(customer.email)
          expect(message).not_to include(feedback.body)
          expect(message).not_to include(feedback.subject)
        end
      end

      it "全 Admin で失敗しても例外を外へ送出しないこと" do
        allow(AdminNotificationMailer).to receive(:with).and_raise(StandardError, "boom")
        expect { described_class.call(feedback) }.not_to raise_error
      end
    end

    context "Service 入口・Admin 取得の想定外例外" do
      before { create(:admin) }

      it "Admin.find_each 自体が失敗しても呼び出し元へ例外を波及させないこと" do
        allow(Admin).to receive(:find_each).and_raise(StandardError, "db down")
        expect { described_class.call(feedback) }.not_to raise_error
      end

      it "その場合は enqueue されず、feedback ID と例外クラスのみのエラーログが残ること" do
        pii_message = "connection to #{customer.email} refused"
        allow(Admin).to receive(:find_each).and_raise(RuntimeError, pii_message)
        allow(Rails.logger).to receive(:error)

        expect { described_class.call(feedback) }.not_to mail_matcher

        expect(Rails.logger).to have_received(:error).once do |message|
          expect(message).to include("feedback_id=#{feedback.id}")
          expect(message).to include("error_class=RuntimeError")
          expect(message).not_to include(pii_message)
          expect(message).not_to include(customer.email)
          expect(message).not_to include(feedback.body)
        end
      end

      it "Exception（非 StandardError）は捕捉しないこと" do
        allow(Admin).to receive(:find_each).and_raise(Exception, "fatal")
        expect { described_class.call(feedback) }.to raise_error(Exception, "fatal")
      end
    end
  end
end
