require "rails_helper"

# 承認制プロジェクトの参加申請に添える任意のメッセージ。保存し、承認できる人だけがメンバー管理で読める。
RSpec.describe "Business プロジェクトの申請メッセージ", type: :request do
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business") }
  let(:creator) { create(:customer, domain_name: "business") }
  let(:applicant) { create(:customer, domain_name: "business", name: "申請するひと") }
  let(:participant) { create(:customer, domain_name: "business") }
  let(:community) { create(:community, owner: owner, domain: business_domain, join_approval_mode: :auto) }
  let(:project) { Project.create!(community: community, customer: creator, title: "LP制作") }
  let(:message) { "デザインに興味があります。\nバナー制作を担当してみたいです。" }

  before do
    [owner, creator, applicant, participant].each { |customer| CommunityCustomer.create!(community: community, customer: customer) }
    ProjectMember.create!(project: project, customer: participant)
  end

  def request_join(text = nil)
    sign_in applicant
    params = text.nil? ? {} : { project_join_request: { message: text } }
    post join_business_project_path(project), params: params
  end

  def body_html
    Nokogiri::HTML(response.body)
  end

  def join_request_rows(viewer)
    sign_in viewer
    get members_business_project_path(project)
    body_html.css("#join-requests .ba-row")
  end

  describe "申請フォーム" do
    it "承認制では「参加を申請する」の中に任意のメッセージ欄が出る" do
      sign_in applicant
      get business_project_path(project)

      form = body_html.at_css("#project-join details.ba-join-request form")
      expect(body_html.at_css("#project-join summary").text).to include("参加を申請する")
      expect(form["action"]).to eq join_business_project_path(project)
      textarea = form.at_css("textarea[name='project_join_request[message]']")
      expect(textarea["maxlength"]).to eq "500"
      expect(textarea["placeholder"]).to eq "興味を持った理由や、参加してやってみたいことなど"
      expect(textarea["required"]).to be_nil
      expect(form.at_css("label[for='#{textarea['id']}']").text).to include("申請メッセージ")
    end

    it "自動承認ではメッセージ欄を出さず、従来どおりその場で参加できる" do
      project.update!(join_approval_mode: :auto)
      sign_in applicant
      get business_project_path(project)
      expect(body_html.at_css("#project-join textarea")).to be_nil
      expect(body_html.at_css("#project-join a[data-method='post']").text).to include("参加する")

      expect { request_join("無視される") }.to change(ProjectMember, :count).by(1)
      expect(ProjectJoinRequest.count).to eq 0
      expect(flash[:notice]).to eq "プロジェクトに参加しました！"
    end
  end

  describe "保存と表示" do
    it "メッセージ付きで申請すると保存され、承認できる人がメンバー管理で読める" do
      expect { request_join(message) }.to change(ProjectJoinRequest, :count).by(1)
      expect(flash[:notice]).to eq "プロジェクトへ参加申請しました"
      expect(ProjectJoinRequest.last.message).to eq message

      [owner, creator].each do |approver|
        row = join_request_rows(approver).first
        expect(row.at_css(".ba-person__name").text).to eq "申請するひと"
        expect(row.at_css(".ba-join-message__body").text).to include("デザインに興味があります。", "バナー制作を担当してみたいです。")
        expect(row.at_css(".ba-join-message__body br")).to be_present
      end
    end

    it "HTML はそのまま文字として表示する" do
      request_join("<script>alert(1)</script><b>太字</b>")

      sign_in owner
      get members_business_project_path(project)
      expect(response.body).not_to include("<script>alert(1)</script>")
      expect(body_html.at_css(".ba-join-message__body").text).to include("<script>alert(1)</script><b>太字</b>")
    end

    it "空欄・空白だけでも申請でき、メッセージなしとして表示する" do
      expect { request_join("  \n ") }.to change(ProjectJoinRequest, :count).by(1)
      expect(ProjectJoinRequest.last.message).to be_nil

      row = join_request_rows(owner).first
      expect(row.at_css(".ba-join-message__body")).to be_nil
      expect(row.at_css(".ba-join-message--empty").text).to eq "申請メッセージはありません"
    end

    it "メッセージ欄を送らない従来の申請も受け付ける" do
      expect { request_join }.to change(ProjectJoinRequest, :count).by(1)
      expect(ProjectJoinRequest.last.message).to be_nil
    end

    it "既存の申請(メッセージ列が NULL)はメッセージなしとして表示する" do
      ProjectJoinRequest.create!(project: project, customer: applicant)
      ProjectJoinRequest.update_all(message: nil)

      expect(join_request_rows(owner).first.at_css(".ba-join-message--empty")).to be_present
    end

    it "500文字ちょうどは申請でき、501文字は申請せずに知らせる" do
      expect { request_join("あ" * 501) }.not_to change(ProjectJoinRequest, :count)
      expect(flash[:alert]).to eq "申請メッセージは500文字以内で入力してください。申請はまだ送られていません。"
      expect(response).to redirect_to business_project_path(project)
      expect(Notification.unscoped.where(action: "project_request")).to be_empty

      expect { request_join("あ" * 500) }.to change(ProjectJoinRequest, :count).by(1)
      expect(ProjectJoinRequest.last.message.length).to eq 500
    end

    it "メッセージに想定外の形式が送られても、メッセージなしで申請する" do
      sign_in applicant
      post join_business_project_path(project), params: { project_join_request: "文字列" }
      expect(ProjectJoinRequest.last.message).to be_nil
    end
  end

  describe "閲覧できる人" do
    before { request_join(message) }

    it "承認権限のない参加者はメンバー管理を開けず、メッセージも見えない" do
      sign_in participant
      get members_business_project_path(project)
      expect(response).to have_http_status(:redirect)
      follow_redirect!
      expect(response.body).not_to include("デザインに興味があります")

      get business_project_path(project)
      expect(response.body).not_to include("デザインに興味があります")
    end

    it "申請者本人もメンバー管理を開けない" do
      sign_in applicant
      get members_business_project_path(project)
      expect(response).to have_http_status(:redirect)
    end

    it "通知ベル・通知一覧には本文を載せず、通知から承認待ち欄を開ける" do
      sign_in creator
      get business_notifications_path
      link = body_html.at_css("a.ba-notification[href*='/members']")
      expect(link["href"]).to eq members_business_project_path(project, anchor: "join-requests")
      expect(response.body).not_to include("デザインに興味があります")
      expect(Notification.unscoped.where(action: "project_request").count).to eq 2
    end

    it "申請メッセージを含むメールは送らない" do
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear
      other = create(:customer, domain_name: "business")
      CommunityCustomer.create!(community: community, customer: other)
      sign_in other

      expect { post join_business_project_path(project), params: { project_join_request: { message: "メールに載せない本文" } } }
        .not_to have_enqueued_mail
      expect(ActionMailer::Base.deliveries.map(&:body).map(&:to_s).join).not_to include("メールに載せない本文")
    end
  end

  describe "取り消し・却下のあとの再申請" do
    it "新しい申請内容を表示し、空欄で再申請すると以前のメッセージは残らない" do
      request_join("最初のメッセージ")
      delete cancel_request_business_project_path(project)
      expect(ProjectJoinRequest.count).to eq 0

      request_join("二回目のメッセージ")
      row = join_request_rows(owner).first
      expect(row.text).to include("二回目のメッセージ")
      expect(row.text).not_to include("最初のメッセージ")

      sign_in applicant
      delete cancel_request_business_project_path(project)
      request_join("")
      row = join_request_rows(owner).first
      expect(row.text).not_to include("二回目のメッセージ")
      expect(row.at_css(".ba-join-message--empty")).to be_present
      expect(ProjectJoinRequest.last.message).to be_nil
    end

    it "却下後に再申請しても以前のメッセージは残らない" do
      request_join("却下される申請")
      sign_in owner
      delete reject_business_project_join_request_path(project, ProjectJoinRequest.last)

      request_join
      expect(join_request_rows(owner).first.text).not_to include("却下される申請")
    end

    it "承認待ちのうちに再送しても、最初の申請内容のまま変わらない" do
      request_join("最初のメッセージ")
      request_join("上書きしようとした文")

      expect(flash[:notice]).to eq "参加申請は承認待ちです"
      expect(ProjectJoinRequest.count).to eq 1
      expect(ProjectJoinRequest.last.message).to eq "最初のメッセージ"
    end
  end

  describe "承認" do
    it "メッセージ付きの申請も従来どおり承認でき、承認後は一覧から消える" do
      request_join(message)
      sign_in creator
      post approve_business_project_join_request_path(project, ProjectJoinRequest.last)

      expect(flash[:notice]).to eq "参加を承認しました"
      expect(applicant.business_project_participant?(project)).to eq true
      expect(join_request_rows(creator)).to be_empty
    end
  end
end
