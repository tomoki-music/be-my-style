require "rails_helper"

RSpec.describe ImagePositionable do
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business") }
  let(:community) { create(:community, owner: owner, domain: business_domain) }

  def fixture(name)
    Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/image_position/#{name}.png"), "image/png")
  end

  describe "#community_image_object_position" do
    it "未調整(NULL)なら nil を返し、既存の見え方を変えない" do
      expect(community.community_image_object_position).to be_nil
    end

    it "保存した位置を object-position の書式で返す(余分な 0 は付けない)" do
      community.update!(community_image_position_x: 12.5, community_image_position_y: 100)

      expect(community.reload.community_image_object_position).to eq "12.5% 100%"
    end

    it "片方だけ保存されていても、もう片方は中央(50%)として扱う" do
      community.update!(community_image_position_x: 0)

      expect(community.reload.community_image_object_position).to eq "0% 50%"
    end
  end

  describe "検証" do
    it "0〜100 の範囲外は保存しない" do
      community.community_image_position_x = 100.01
      community.community_image_position_y = -1

      expect(community).not_to be_valid
      expect(community.errors.attribute_names).to include(:community_image_position_x, :community_image_position_y)
    end
  end

  describe "画像の差し替え" do
    before do
      community.update!(community_image: fixture("wide"), community_image_position_x: 10, community_image_position_y: 20)
    end

    it "位置を送らずに新しい画像へ差し替えると、前の位置を持ち越さず中央基準に戻す" do
      community.update!(community_image: fixture("tall"))

      expect(community.reload.community_image_object_position).to be_nil
      expect(community.community_image.filename.to_s).to eq "tall.png"
    end

    it "新しい画像と一緒に位置を送れば、その位置で保存する" do
      community.update!(community_image: fixture("tall"), community_image_position_x: 50, community_image_position_y: 80)

      expect(community.reload.community_image_object_position).to eq "50% 80%"
    end

    it "画像を変えずに位置だけ変更でき、元画像はそのまま残る" do
      blob_id = community.community_image.blob.id

      community.update!(community_image_position_x: 75, community_image_position_y: 30)

      expect(community.reload.community_image_object_position).to eq "75% 30%"
      expect(community.community_image.blob.id).to eq blob_id
    end
  end

  it "Customer と Project にも同じ仕組みがある" do
    customer = create(:customer, profile_image_position_x: 30, profile_image_position_y: 40)
    project = Project.create!(community: community, customer: owner, title: "案件", description: "概要",
                              project_image_position_x: 60, project_image_position_y: 70)

    expect(customer.profile_image_object_position).to eq "30% 40%"
    expect(project.project_image_object_position).to eq "60% 70%"
  end
end
