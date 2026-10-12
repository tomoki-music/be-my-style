require "rails_helper"

# Business のコミュニティ タイムライン / プロジェクト チャットの添付・スタンプと、その閲覧権限。
RSpec.describe "Business チャットの添付・スタンプ", type: :request do
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business") }
  let(:community) { create(:community, owner: owner, domain: business_domain) }
  let(:project) { Project.create!(community: community, customer: owner, title: "新規事業", description: "説明") }
  let(:free_member) { create(:customer, domain_name: "business") }
  let(:outsider) { create(:customer, domain_name: "business") }

  before do
    CommunityCustomer.find_or_create_by!(customer: owner, community: community)
    CommunityCustomer.find_or_create_by!(customer: free_member, community: community)
    project.members << free_member
  end

  def upload(name, content_type = "application/octet-stream")
    fixture_file_upload(Rails.root.join("spec/fixtures/files/business_chat", name), content_type)
  end

  def post_timeline(params)
    post business_community_community_posts_path(community), params: { community_post: params }
  end

  def post_project_chat(params)
    post business_project_project_chats_path(project), params: { project_chat: params }
  end

  describe "Free の参加者による送信" do
    before { sign_in free_member }

    it "タイムラインへ画像・資料付きで投稿でき、添付だけの投稿もできる" do
      expect(free_member.plan).to eq "free"

      expect {
        post_timeline(body: "資料です", attachments: [upload("photo.png", "image/png"), upload("sample.pdf", "application/pdf")])
      }.to change(CommunityPost, :count).by(1)
      created = CommunityPost.last
      expect(created.attachments.count).to eq 2
      expect(created).to be_content_format_markdown

      expect { post_timeline(attachments: [upload("memo.docx")]) }.to change(CommunityPost, :count).by(1)
      expect(CommunityPost.last.body).to be_blank
    end

    it "タイムラインへスタンプだけを投稿できる" do
      expect { post_timeline(stamp_type: "thanks") }.to change(CommunityPost, :count).by(1)
      expect(CommunityPost.last.stamp_type).to eq "thanks"
    end

    it "プロジェクトチャットへ資料・スタンプを送信できる" do
      expect { post_project_chat(attachments: [upload("report.xlsx")]) }.to change(ProjectChat, :count).by(1)
      expect { post_project_chat(stamp_type: "animal_got_it") }.to change(ProjectChat, :count).by(1)
      expect(response).to redirect_to(business_project_path(project))
    end

    it "不正なファイル・容量超過・件数超過・不正なスタンプは保存せず理由を表示する" do
      expect { post_timeline(attachments: [upload("tool.exe")]) }.not_to change(CommunityPost, :count)
      expect(flash[:alert]).to include("「tool.exe」は添付できない形式です")

      big = fixture_file_upload(Rails.root.join("spec/fixtures/11megabytes_sample.png"), "image/png")
      expect { post_project_chat(attachments: [big]) }.not_to change(ProjectChat, :count)
      expect(flash[:alert]).to include("10MBを超えています")

      expect {
        post_project_chat(attachments: Array.new(6) { upload("sample.pdf", "application/pdf") })
      }.not_to change(ProjectChat, :count)
      expect(flash[:alert]).to eq "添付ファイルは5件までです"

      expect { post_timeline(stamp_type: "clap") }.not_to change(CommunityPost, :count)
      expect(flash[:alert]).to include("選択されたスタンプは利用できません")

      expect(ActiveStorage::Blob.count).to eq 0
    end
  end

  describe "非参加者による送信" do
    before { sign_in outsider }

    it "タイムライン・プロジェクトチャットへ添付やスタンプを送れない" do
      expect { post_timeline(stamp_type: "thanks") }.not_to change(CommunityPost, :count)
      expect { post_project_chat(attachments: [upload("sample.pdf", "application/pdf")]) }.not_to change(ProjectChat, :count)
    end
  end

  describe "添付ファイルの表示・ダウンロード" do
    let!(:timeline_post) do
      CommunityPost.create!(community: community, customer: owner, content_format: :markdown,
                            attachments: [upload("photo.png", "image/png"), upload("sample.pdf", "application/pdf")])
    end
    let!(:project_chat) do
      ProjectChat.create!(project: project, customer: owner, content_format: :markdown, attachments: [upload("memo.docx")])
    end
    let(:image) { timeline_post.attachments.detect(&:image?) }
    let(:pdf) { timeline_post.attachments.detect { |a| a.content_type == "application/pdf" } }
    let(:docx) { project_chat.attachments.first }

    context "参加者" do
      before { sign_in free_member }

      it "画面には権限確認付きの URL だけを出し、恒久的な blob URL を出さない" do
        get business_community_path(community)

        expect(response.body).to include(business_chat_attachment_path(image, variant: "thumb"))
        expect(response.body).to include("sample.pdf")
        expect(response.body).to include("ダウンロード")
        expect(response.body).not_to include("/rails/active_storage/")

        get business_project_path(project)
        expect(response.body).to include("memo.docx")
        expect(response.body).to include("Word")
        expect(response.body).not_to include("/rails/active_storage/")
      end

      it "画像は表示用、資料はダウンロード用の短時間 URL へ転送する" do
        get business_chat_attachment_path(image)
        expect(response).to have_http_status(:found)
        expect(response.location).to include("/rails/active_storage/disk/")
        expect(response.headers["Cache-Control"]).to include("no-store")

        get business_chat_attachment_path(image, variant: "thumb")
        expect(response).to have_http_status(:found)

        get business_chat_attachment_path(pdf)
        expect(response).to have_http_status(:found)
        follow_redirect!
        expect(response.headers["Content-Disposition"]).to start_with("attachment")

        get business_chat_attachment_path(docx)
        expect(response).to have_http_status(:found)
      end
    end

    context "コミュニティ非参加者(ログイン中)" do
      before { sign_in outsider }

      it "タイムラインの本文・添付は閲覧できるが、プロジェクトチャットの添付にはアクセスできない" do
        get business_community_path(community)
        expect(response.body).to include("sample.pdf")
        expect(response.body).not_to include("/rails/active_storage/")

        get business_chat_attachment_path(image)
        expect(response).to have_http_status(:found)
        get business_chat_attachment_path(pdf)
        expect(response).to have_http_status(:found)

        get business_chat_attachment_path(docx)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "コミュニティ参加者だがプロジェクト非参加" do
      let(:community_only) { create(:customer, domain_name: "business") }

      before do
        CommunityCustomer.create!(customer: community_only, community: community)
        sign_in community_only
      end

      it "タイムラインの添付は見られるが、プロジェクトチャットの添付にはアクセスできない" do
        get business_chat_attachment_path(image)
        expect(response).to have_http_status(:found)

        get business_chat_attachment_path(docx)
        expect(response).to have_http_status(:not_found)
      end
    end

    describe "ActiveStorage の標準配信ルートからの迂回" do
      it "画面に blob の署名付き ID を出さない(標準ルートの URL を組み立てられない)" do
        sign_in free_member
        get business_community_path(community)
        community_body = response.body
        get business_project_path(project)

        [image, pdf, docx].each do |attachment|
          expect(community_body + response.body).not_to include(attachment.blob.signed_id)
          expect(community_body + response.body).not_to include(attachment.blob.key)
        end
      end

      it "blob の連番 ID やキーでは標準ルートから取得できない" do
        sign_in outsider

        get "/rails/active_storage/blobs/redirect/#{docx.blob.id}/memo.docx"
        expect(response).to have_http_status(:not_found)

        get "/rails/active_storage/blobs/redirect/#{docx.blob.key}/memo.docx"
        expect(response).to have_http_status(:not_found)

        get "/rails/active_storage/blobs/#{docx.blob.id}/memo.docx"
        expect(response).to have_http_status(:not_found)
      end
    end

    it "未ログインではアクセスできない" do
      get business_chat_attachment_path(image)

      expect(response).to redirect_to(new_customer_session_path)
    end

    it "チャット以外の添付(プロフィール画像など)はこの窓口から取得できない" do
      owner.profile_image.attach(upload("photo.png", "image/png"))
      sign_in free_member

      get business_chat_attachment_path(owner.profile_image.attachment)

      expect(response).to have_http_status(:not_found)
    end
  end
end
