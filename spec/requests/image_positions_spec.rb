require "rails_helper"

# コミュニティ・プロジェクト・プロフィール画像の表示位置。編集画面で位置だけを保存でき、
# 同じ画像を出す詳細・一覧・アイコンに object-position として反映される。
RSpec.describe "画像の表示位置", type: :request do
  def doc
    Nokogiri::HTML(response.body)
  end

  def fixture(name)
    Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/image_position/#{name}.png"), "image/png")
  end

  def attach(record, attachment, name)
    record.public_send(attachment).attach(
      io: File.open(Rails.root.join("spec/fixtures/files/image_position/#{name}.png")),
      filename: "#{name}.png",
      content_type: "image/png"
    )
  end

  def styles_of(selector)
    doc.css(selector).map { |node| node["style"].to_s }
  end

  def editor_values(attribute)
    field = doc.at_css("[data-image-position-field]")
    [
      field.at_css("input[type=hidden][name$='[#{attribute}_position_x]']")["value"],
      field.at_css("input[type=hidden][name$='[#{attribute}_position_y]']")["value"]
    ]
  end

  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:music_domain) { Domain.find_or_create_by!(name: "music") }

  describe "Business コミュニティ" do
    let(:owner) { create(:customer, domain_name: "business") }
    let(:community) { create(:community, owner: owner, domain: business_domain) }

    before do
      CommunityCustomer.find_or_create_by!(customer: owner, community: community)
      attach(community, :community_image, "wide")
      sign_in owner
    end

    it "未調整の既存画像は、編集画面・詳細画面とも中央基準のまま(style を付けない)" do
      get edit_business_community_path(community)
      expect(editor_values(:community_image)).to eq [nil, nil]
      expect(doc.at_css("[data-image-position-editor]")["hidden"]).to be_nil
      expect(doc.css("[data-image-position-frame]").size).to eq 3

      get business_community_path(community)
      expect(styles_of(".ba-profile__cover-image")).to eq [""]
    end

    it "画像を選び直さずに位置だけ保存でき、詳細・一覧・編集画面の再表示に反映される" do
      blob_id = community.community_image.blob.id

      patch business_community_path(community), params: {
        community: { community_image_position_x: "0", community_image_position_y: "37.5" }
      }

      expect(response).to redirect_to(business_community_path(community))
      expect(community.reload.community_image.blob.id).to eq blob_id

      get business_community_path(community)
      expect(styles_of(".ba-profile__cover-image")).to eq ["object-position: 0% 37.5%;"]

      get business_communities_path
      expect(styles_of("img.ba-avatar")).to include("object-position: 0% 37.5%;")

      get edit_business_community_path(community)
      expect(editor_values(:community_image)).to eq ["0.0", "37.5"]
      expect(styles_of("[data-image-position-image]").uniq).to eq ["object-position: 0% 37.5%;"]
    end

    it "範囲外の位置は保存しない" do
      patch business_community_path(community), params: { community: { community_image_position_x: "120" } }

      expect(response).to have_http_status(:ok)
      expect(community.reload.community_image_position_x).to be_nil
    end
  end

  describe "Business プロジェクト" do
    let(:owner) { create(:customer, domain_name: "business") }
    let(:community) { create(:community, owner: owner, domain: business_domain) }
    let!(:project) { Project.create!(community: community, customer: owner, title: "A社サイト制作", description: "概要") }

    before do
      CommunityCustomer.find_or_create_by!(customer: owner, community: community)
      attach(project, :project_image, "tall")
      sign_in owner
    end

    it "位置だけ保存でき、詳細のカバーと一覧カードに反映される" do
      patch business_project_path(project), params: {
        project: { project_image_position_x: "50", project_image_position_y: "100" }
      }
      expect(response).to redirect_to(business_project_path(project))

      get business_project_path(project)
      expect(styles_of(".ba-profile__cover-image")).to eq ["object-position: 50% 100%;"]

      get business_community_path(community)
      expect(styles_of(".ba-project-card__image")).to eq ["object-position: 50% 100%;"]

      get edit_business_project_path(project)
      expect(editor_values(:project_image)).to eq ["50.0", "100.0"]
      expect(doc.css("[data-image-position-frame]").size).to eq 3
    end

    it "新規作成で画像と位置を一緒に保存できる" do
      post business_projects_path, params: {
        community_id: community.id,
        project: { title: "新規案件", description: "概要", community_id: community.id, project_image: fixture("wide"),
                   project_image_position_x: "80", project_image_position_y: "50" }
      }

      created = Project.find_by!(title: "新規案件")
      expect(created.project_image).to be_attached
      expect(created.project_image_object_position).to eq "80% 50%"
    end
  end

  describe "Business プロフィール" do
    let(:customer) { create(:customer, domain_name: "business") }

    before do
      attach(customer, :profile_image, "tall")
      sign_in customer
    end

    it "位置だけ保存でき、プロフィールとヘッダーのアイコンに反映される" do
      patch business_customer_path(customer), params: {
        customer: { profile_image_position_x: "50", profile_image_position_y: "0" }
      }
      expect(response).to redirect_to(business_customer_path(customer))

      get business_customer_path(customer)
      expect(styles_of(".ba-user__avatar img.user-profile-image")).to eq ["object-position: 50% 0%;"]
      expect(styles_of("img.business-account-menu__avatar")).to all(eq "object-position: 50% 0%;")

      get edit_business_customer_path(customer)
      expect(editor_values(:profile_image)).to eq ["50.0", "0.0"]
    end
  end

  describe "音楽 コミュニティ" do
    let(:owner) { create(:customer) }
    let(:community) { create(:community, owner: owner, domain: music_domain) }

    before do
      CommunityCustomer.find_or_create_by!(customer: owner, community: community)
      attach(community, :community_image, "tall")
      sign_in owner
    end

    it "位置だけ保存でき、詳細画面・編集画面の再表示に反映される" do
      patch public_community_path(community), params: {
        community: { community_image_position_x: "50", community_image_position_y: "12.25" }
      }
      expect(response).to redirect_to(public_community_path(community))

      get public_community_path(community)
      expect(styles_of(".community-show-card .img-container img")).to eq ["object-position: 50% 12.25%;"]

      get edit_public_community_path(community)
      expect(editor_values(:community_image)).to eq ["50.0", "12.25"]
      expect(doc.css("[data-image-position-frame]").size).to eq 4
    end
  end

  describe "音楽 プロフィール" do
    let(:customer) { create(:customer) }

    before do
      attach(customer, :profile_image, "wide")
      sign_in customer
    end

    it "位置だけ保存でき、プロフィール画面と編集画面の再表示に反映される" do
      patch public_customer_path(customer), params: {
        customer: { profile_image_position_x: "100", profile_image_position_y: "50" }
      }
      expect(response).to redirect_to(public_customer_path(customer))
      expect(customer.reload.profile_image_object_position).to eq "100% 50%"

      get public_customer_path(customer)
      expect(styles_of(".customer-show-card img.user-profile-image")).to eq ["object-position: 100% 50%;"]

      get edit_public_customer_path(customer)
      expect(editor_values(:profile_image)).to eq ["100.0", "50.0"]
    end

    it "新規登録で選んだ位置が、登録後のプロフィール画像に保存される" do
      sign_out customer

      post customer_registration_path, params: {
        customer: {
          email: "image-position@example.com", password: "password", password_confirmation: "password", name: "位置太郎",
          profile_image: fixture("wide"), profile_image_position_x: "0", profile_image_position_y: "50"
        }
      }

      created = Customer.find_by!(email: "image-position@example.com")
      expect(created.profile_image).to be_attached
      expect(created.profile_image_object_position).to eq "0% 50%"
    end
  end

  describe "そのほかのプロフィール画像の入力欄" do
    it "新規登録画面に、画像を選ぶまで隠れた位置調整欄がある" do
      get new_customer_registration_path

      expect(doc.at_css("[data-image-position-field] input[type=file][name='customer[profile_image]']")).to be_present
      expect(doc.at_css("[data-image-position-editor]").key?("hidden")).to be true
    end

    it "歌声プロフィール編集でも位置だけ保存でき、プロフィールに反映される" do
      singer = create(:customer, domain_name: "singing")
      attach(singer, :profile_image, "wide")
      sign_in singer

      get edit_singing_user_path(singer)
      expect(doc.at_css("[data-image-position-field]")).to be_present

      patch singing_user_path(singer), params: { customer: { name: singer.name, profile_image_position_x: "25", profile_image_position_y: "50" } }
      expect(response).to redirect_to(singing_user_path(singer))

      get singing_user_path(singer)
      expect(styles_of("img.user-profile-image")).to include("object-position: 25% 50%;")
    end
  end
end
