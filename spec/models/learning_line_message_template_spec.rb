require "rails_helper"

RSpec.describe LearningLineMessageTemplate, type: :model do
  it "有効なテンプレートを作成できること" do
    template = build(:learning_line_message_template)

    expect(template).to be_valid
  end

  it "本文は500文字以内であること" do
    template = build(:learning_line_message_template, body: "あ" * 501)

    expect(template).not_to be_valid
    expect(template.errors[:body]).to be_present
  end

  it "カテゴリは定義済みの値だけ許可すること" do
    template = build(:learning_line_message_template, category: "unknown")

    expect(template).not_to be_valid
    expect(template.errors[:category]).to be_present
  end
end
