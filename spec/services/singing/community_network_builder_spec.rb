require "rails_helper"

RSpec.describe Singing::CommunityNetworkBuilder do
  def completed_diagnosis(customer, attrs = {})
    create(
      :singing_diagnosis,
      :completed,
      {
        customer: customer,
        overall_score: 75,
        pitch_score: 72,
        rhythm_score: 74,
        expression_score: 73,
        created_at: Time.current
      }.merge(attrs)
    )
  end

  def expression_pair(customer)
    completed_diagnosis(
      customer,
      overall_score: 70,
      pitch_score: 70,
      rhythm_score: 70,
      expression_score: 60,
      created_at: 2.days.ago
    )
    completed_diagnosis(
      customer,
      overall_score: 78,
      pitch_score: 71,
      rhythm_score: 70,
      expression_score: 82,
      created_at: 1.day.ago
    )
  end

  describe ".call" do
    it "customer nilでも生成される" do
      network = described_class.call(nil)

      expect(network).to be_a(described_class::CommunityNetwork)
      expect(network.connections).to eq([])
      expect(network.message).to be_present
    end

    it "DTOを返し、connections配列を持つ" do
      customer = create(:customer, domain_name: "singing")

      network = described_class.call(customer)

      expect(network).to be_a(described_class::CommunityNetwork)
      expect(network.connections).to be_an(Array)
      expect(network.message).to be_present
    end

    it "最大件数を制御する" do
      customer = create(:customer, domain_name: "singing")
      completed_diagnosis(customer)

      3.times do
        candidate = create(:customer, domain_name: "singing")
        completed_diagnosis(candidate)
      end

      network = described_class.call(customer, limit: 2)

      expect(network.connections.size).to eq(2)
    end

    it "GrowthType一致の仲間を返す" do
      customer = create(:customer, domain_name: "singing")
      candidate = create(:customer, domain_name: "singing", name: "近い仲間")
      completed_diagnosis(customer)
      completed_diagnosis(candidate)

      connection = described_class.call(customer).connections.first

      expect(connection.customer_id).to eq(candidate.id)
      expect(connection.connection_type).to eq(:growth_type)
      expect(connection.reason).to eq("同じ成長タイプです")
    end

    it "Mission一致の仲間を返す" do
      customer = create(:customer, domain_name: "singing")
      candidate = create(:customer, domain_name: "singing")
      expression_pair(customer)
      completed_diagnosis(
        candidate,
        overall_score: 68,
        pitch_score: 80,
        rhythm_score: 70,
        expression_score: 70,
        created_at: 2.days.ago
      )
      completed_diagnosis(
        candidate,
        overall_score: 78,
        pitch_score: 82,
        rhythm_score: 80,
        expression_score: 88,
        created_at: 1.day.ago
      )

      connection = described_class.call(customer).connections.first

      expect(connection.connection_type).to eq(:mission)
      expect(connection.reason).to eq("似た挑戦をしています")
    end

    it "Cheer関係の仲間を返す" do
      customer = create(:customer, domain_name: "singing")
      candidate = create(:customer, domain_name: "singing")
      completed_diagnosis(candidate)
      create(:singing_cheer_reaction, customer: customer, target_customer: candidate)

      connection = described_class.call(customer).connections.first

      expect(connection.connection_type).to eq(:cheer)
      expect(connection.reason).to eq("応援でつながっています")
    end

    it "活動頻度が近い仲間を返す" do
      customer = create(:customer, domain_name: "singing")
      candidate = create(:customer, domain_name: "singing")
      completed_diagnosis(customer)
      expression_pair(candidate)

      connection = described_class.call(customer).connections.first

      expect(connection.connection_type).to eq(:activity)
      expect(connection.reason).to eq("似たペースで活動しています")
    end

    it "候補がいない場合は空状態メッセージを返す" do
      customer = create(:customer, domain_name: "singing")
      completed_diagnosis(customer)

      network = described_class.call(customer)

      expect(network.connections).to eq([])
      expect(network.message).to include("これからつながりが広がっていきます")
    end

    it "nil安全" do
      expect { described_class.call(nil) }.not_to raise_error
    end
  end
end
