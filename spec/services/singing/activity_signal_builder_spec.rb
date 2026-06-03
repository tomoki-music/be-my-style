require "rails_helper"

RSpec.describe Singing::ActivitySignalBuilder do
  describe ".call" do
    let(:customer) { create(:customer, domain_name: "singing") }

    it "nil customerではinactiveなResultを返す" do
      result = described_class.call(nil)

      expect(result).to be_a(described_class::Result)
      expect(result.active?).to eq(false)
      expect(result.latest_signal).to be_nil
      expect(result.signals).to eq([])
    end

    it "活動がなければinactiveなResultを返す" do
      result = described_class.call(customer)

      expect(result.active?).to eq(false)
      expect(result.latest_signal).to be_nil
      expect(result.signals).to eq([])
    end

    it "completed diagnosis をdiagnosis signalとして返す" do
      diagnosis = create(:singing_diagnosis, :completed, customer: customer, created_at: 2.days.ago)

      result = described_class.call(customer)

      signal = result.signals.first
      expect(result.active?).to eq(true)
      expect(signal.source).to eq(:diagnosis)
      expect(signal.occurred_at).to be_within(1.second).of(diagnosis.created_at)
      expect(signal.target_customer_id).to be_nil
      expect(signal.metadata).to eq({})
    end

    it "reaction_sent signalを返す" do
      target = create(:customer, domain_name: "singing")
      reaction = create(:singing_profile_reaction, customer: customer, target_customer: target, created_at: 1.day.ago)

      signal = described_class.call(customer).signals.first

      expect(signal.source).to eq(:reaction_sent)
      expect(signal.occurred_at).to be_within(1.second).of(reaction.created_at)
      expect(signal.target_customer_id).to eq(target.id)
      expect(signal.metadata).to eq(reaction_type: reaction.reaction_type)
    end

    it "reaction_received signalを返す" do
      sender = create(:customer, domain_name: "singing")
      reaction = create(:singing_profile_reaction, customer: sender, target_customer: customer, created_at: 1.day.ago)

      signal = described_class.call(customer).signals.first

      expect(signal.source).to eq(:reaction_received)
      expect(signal.occurred_at).to be_within(1.second).of(reaction.created_at)
      expect(signal.target_customer_id).to eq(sender.id)
      expect(signal.metadata).to eq(reaction_type: reaction.reaction_type)
    end

    it "challenge_progress signalを返す" do
      progress = create(:singing_ai_challenge_progress, customer: customer, target_key: "pitch", updated_at: 1.day.ago)

      signal = described_class.call(customer).signals.first

      expect(signal.source).to eq(:challenge_progress)
      expect(signal.occurred_at).to be_within(1.second).of(progress.updated_at)
      expect(signal.target_customer_id).to be_nil
      expect(signal.metadata).to eq(target_key: "pitch", completed: false)
    end

    it "latest_signal は最新のsignalを返す" do
      create(:singing_diagnosis, :completed, customer: customer, created_at: 3.days.ago)
      reaction = create(:singing_profile_reaction, customer: customer, created_at: 1.hour.ago)

      result = described_class.call(customer)

      expect(result.latest_signal).to eq(result.signals.first)
      expect(result.latest_signal.source).to eq(:reaction_sent)
      expect(result.latest_signal.occurred_at).to be_within(1.second).of(reaction.created_at)
    end

    it "signals はoccurred_at descで返す" do
      create(:singing_diagnosis, :completed, customer: customer, created_at: 3.days.ago)
      create(:singing_profile_reaction, customer: customer, created_at: 1.hour.ago)
      sender = create(:customer, domain_name: "singing")
      create(:singing_profile_reaction, customer: sender, target_customer: customer, created_at: 2.hours.ago)
      create(:singing_ai_challenge_progress, customer: customer, updated_at: 1.day.ago)

      signals = described_class.call(customer).signals

      expect(signals.map(&:source)).to eq(%i[reaction_sent reaction_received challenge_progress diagnosis])
      expect(signals.map(&:occurred_at)).to eq(signals.map(&:occurred_at).sort.reverse)
    end

    it "source は診断・応援送信・応援受信・チャレンジ進捗を表す" do
      create(:singing_diagnosis, :completed, customer: customer, created_at: 4.days.ago)
      create(:singing_profile_reaction, customer: customer, created_at: 3.days.ago)
      sender = create(:customer, domain_name: "singing")
      create(:singing_profile_reaction, customer: sender, target_customer: customer, created_at: 2.days.ago)
      create(:singing_ai_challenge_progress, customer: customer, updated_at: 1.day.ago)

      sources = described_class.call(customer).signals.map(&:source)

      expect(sources).to contain_exactly(:diagnosis, :reaction_sent, :reaction_received, :challenge_progress)
    end

    it "reaction target_customer_id は送信時は応援した相手、受信時は応援してくれた相手を表す" do
      cheered_customer = create(:customer, domain_name: "singing")
      cheering_customer = create(:customer, domain_name: "singing")
      create(:singing_profile_reaction, customer: customer, target_customer: cheered_customer, created_at: 2.hours.ago)
      create(:singing_profile_reaction, customer: cheering_customer, target_customer: customer, created_at: 1.hour.ago)

      signals = described_class.call(customer).signals

      expect(signals.find { |signal| signal.source == :reaction_sent }.target_customer_id).to eq(cheered_customer.id)
      expect(signals.find { |signal| signal.source == :reaction_received }.target_customer_id).to eq(cheering_customer.id)
    end
  end
end
