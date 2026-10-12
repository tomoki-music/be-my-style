require "rails_helper"

RSpec.describe BusinessChatContent, type: :model do
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business") }
  let(:community) { create(:community, owner: owner, domain: business_domain) }
  let(:project) { Project.create!(community: community, customer: owner, title: "企画", description: "説明") }

  def upload(name, content_type = "application/octet-stream")
    fixture_file_upload(Rails.root.join("spec/fixtures/files/business_chat", name), content_type)
  end

  def build_post(**attrs)
    CommunityPost.new({ community: community, customer: owner }.merge(attrs))
  end

  describe "本文・スタンプ・添付の組み合わせ" do
    it "本文だけ・スタンプだけ・添付だけのどれでも保存できる" do
      expect(build_post(body: "こんにちは")).to be_valid
      expect(build_post(stamp_type: "thanks")).to be_valid
      expect(build_post(attachments: [upload("sample.pdf", "application/pdf")])).to be_valid
    end

    it "何も無いメッセージは保存できない" do
      post = build_post(body: "")

      expect(post).not_to be_valid
      expect(post.errors[:base]).to include("メッセージを入力するか、スタンプ・ファイルを選んでください")
    end

    it "ProjectChat でも同じ規則が使われる" do
      expect(ProjectChat.new(project: project, customer: owner, stamp_type: "animal_got_it")).to be_valid
      expect(ProjectChat.new(project: project, customer: owner)).not_to be_valid
    end
  end

  describe "スタンプ" do
    let(:simple_keys) { Stampable::STAMP_DEFINITIONS.select { |_k, d| %i[simple human].include?(d[:category]) }.keys }
    let(:animal_keys) { Stampable::STAMP_DEFINITIONS.select { |_k, d| d[:category] == :animal }.keys }

    it "「シンプル」「動物」の2タブで、素材のある既存スタンプを欠落なく選べる" do
      tabs = BusinessChatContent.stamp_tabs

      expect(tabs.keys).to eq %i[simple animal]
      expect(tabs.values.map { |tab| tab[:label] }).to eq %w[シンプル 動物]
      expect(tabs[:simple][:definitions].keys).to eq simple_keys
      expect(tabs[:animal][:definitions].keys).to eq animal_keys
      expect(BusinessChatContent::STAMP_TYPES).to match_array Stampable::STAMP_DEFINITIONS.keys
    end

    it "選択 UI と許可リストが一致する" do
      expect(BusinessChatContent.stamp_tabs.values.flat_map { |tab| tab[:definitions].keys }).to eq BusinessChatContent::STAMP_TYPES
    end

    it "全スタンプの素材が存在し、画像として読める" do
      BusinessChatContent.stamp_tabs.values.flat_map { |tab| tab[:definitions].values }.each do |definition|
        path = Rails.root.join("app/assets/images", definition[:asset])

        expect(File.size?(path)).to be_truthy, "#{definition[:asset]} がありません"
        if path.extname == ".svg"
          expect(Nokogiri::XML(File.read(path)) { |config| config.strict }.root.name).to eq "svg"
        else
          expect(Marcel::MimeType.for(path)).to eq "image/png"
        end
      end
    end

    it "両タブの全スタンプを保存できる" do
      BusinessChatContent::STAMP_TYPES.each do |key|
        expect(build_post(stamp_type: key)).to be_valid, "#{key} が保存できません"
      end
    end

    it "不正な識別子・素材のない絵文字スタンプは拒否する" do
      ["<script>", "animal_unknown", "clap", "love"].each do |key|
        post = build_post(stamp_type: key)

        expect(post).not_to be_valid
        expect(post.errors[:base]).to include("選択されたスタンプは利用できません")
      end
    end

    it "保存済みのスタンプは、スタンプを変えない限り再検証しない" do
      post = build_post(stamp_type: "thanks")
      post.save!
      post.update_column(:stamp_type, "clap")

      expect(post.reload.update(body: "追記")).to eq true
      expect(post.update(stamp_type: "fire")).to eq false
    end
  end

  describe "添付ファイル" do
    it "画像・PDF・Office 資料を受け付ける" do
      post = build_post(attachments: [
        upload("photo.png", "image/png"),
        upload("sample.pdf", "application/pdf"),
        upload("memo.docx"),
        upload("report.xlsx")
      ])

      expect(post).to be_valid
    end

    it "実行ファイル・SVG・HTML は拒否する" do
      %w[tool.exe icon.svg page.html].each do |name|
        post = build_post(attachments: [upload(name)])

        expect(post).not_to be_valid
        expect(post.errors[:base]).to include("「#{name}」は添付できない形式です")
      end
    end

    it "拡張子だけ PDF に偽装したファイルや、中身と拡張子が食い違うファイルは拒否する" do
      disguised = build_post(attachments: [upload("disguised.pdf", "application/pdf")])
      png_as_pdf = build_post(attachments: [
        Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/thread_sample_image.png"), "application/pdf", original_filename: "x.pdf")
      ])

      expect(disguised).not_to be_valid
      expect(disguised.errors[:base]).to include("「disguised.pdf」は添付できない形式です")
      expect(png_as_pdf).not_to be_valid
      expect(png_as_pdf.errors[:base]).to include("「x.pdf」は添付できない形式です")
    end

    it "10MB を超えるファイルは拒否する" do
      post = build_post(attachments: [fixture_file_upload(Rails.root.join("spec/fixtures/11megabytes_sample.png"), "image/png")])

      expect(post).not_to be_valid
      expect(post.errors[:base]).to include("「11megabytes_sample.png」は10MBを超えています")
    end

    it "6件以上は拒否する" do
      post = build_post(attachments: Array.new(6) { upload("sample.pdf", "application/pdf") })

      expect(post).not_to be_valid
      expect(post.errors[:base]).to include("添付ファイルは5件までです")
    end
  end
end
