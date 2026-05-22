require "rails_helper"

RSpec.describe Singing::RecapMovieExpiryPolicy do
  let(:customer) { build_stubbed(:customer) }

  describe ".expires_at_for" do
    context "free プラン" do
      before { allow(customer).to receive(:plan).and_return("free") }

      it "30日後の日時を返す" do
        expect(described_class.expires_at_for(customer)).to be_within(5.seconds).of(30.days.from_now)
      end
    end

    context "light プラン" do
      before { allow(customer).to receive(:plan).and_return("light") }

      it "60日後の日時を返す" do
        expect(described_class.expires_at_for(customer)).to be_within(5.seconds).of(60.days.from_now)
      end
    end

    context "core プラン" do
      before { allow(customer).to receive(:plan).and_return("core") }

      it "180日後の日時を返す" do
        expect(described_class.expires_at_for(customer)).to be_within(5.seconds).of(180.days.from_now)
      end
    end

    context "premium プラン" do
      before { allow(customer).to receive(:plan).and_return("premium") }

      it "nil を返す（無期限）" do
        expect(described_class.expires_at_for(customer)).to be_nil
      end
    end

    context "未知のプラン名の場合" do
      before { allow(customer).to receive(:plan).and_return("unknown") }

      it "デフォルト 30日後を返す" do
        expect(described_class.expires_at_for(customer)).to be_within(5.seconds).of(30.days.from_now)
      end
    end
  end

  describe ".retention_label_for" do
    {
      "free"    => "30日",
      "light"   => "60日",
      "core"    => "180日",
      "premium" => "無期限",
    }.each do |plan, label|
      it "#{plan} プランは「#{label}」を返す" do
        allow(customer).to receive(:plan).and_return(plan)
        expect(described_class.retention_label_for(customer)).to eq(label)
      end
    end
  end
end
