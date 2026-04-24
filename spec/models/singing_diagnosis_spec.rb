require 'rails_helper'

RSpec.describe SingingDiagnosis, type: :model do
  describe 'アソシエーションのテスト' do
    it 'customerとN:1となっている' do
      expect(SingingDiagnosis.reflect_on_association(:customer).macro).to eq :belongs_to
    end

    it 'audio_fileを添付できること' do
      diagnosis = FactoryBot.build(:singing_diagnosis)

      diagnosis.audio_file.attach(
        io: StringIO.new("audio"),
        filename: "sample.mp3",
        content_type: "audio/mpeg"
      )

      expect(diagnosis.audio_file).to be_attached
    end
  end

  describe 'enumのテスト' do
    it 'statusを定義していること' do
      expect(SingingDiagnosis.statuses).to eq(
        "queued" => 0,
        "processing" => 1,
        "completed" => 2,
        "failed" => 3
      )
    end

    it 'performance_typeを定義していること' do
      expect(SingingDiagnosis.performance_types).to eq(
        "vocal" => 0,
        "guitar" => 1,
        "bass" => 2,
        "drums" => 3,
        "keyboard" => 4,
        "band" => 5
      )
    end
  end

  describe "performance_type options" do
    it "bandを選択肢と表示ラベルに含むこと" do
      expect(SingingDiagnosis.performance_type_options).to include(["バンド演奏", "band"])
      expect(FactoryBot.build(:singing_diagnosis, performance_type: :band).performance_type_label).to eq("バンド演奏")
    end
  end

  describe 'バリデーションのテスト' do
    it 'statusが必須であること' do
      diagnosis = FactoryBot.build(:singing_diagnosis, status: nil)

      expect(diagnosis.valid?).to eq false
    end

    it 'audio_fileが必須であること' do
      diagnosis = FactoryBot.build(:singing_diagnosis)
      diagnosis.audio_file.detach

      expect(diagnosis.valid?).to eq false
    end

    it 'song_titleは未入力でも有効であること' do
      diagnosis = FactoryBot.build(:singing_diagnosis, song_title: nil)

      expect(diagnosis.valid?).to eq true
    end

    it 'performance_typeの初期値はvocalであること' do
      diagnosis = SingingDiagnosis.new

      expect(diagnosis.performance_type).to eq "vocal"
    end

    it 'scoreは0から100の整数であること' do
      diagnosis = FactoryBot.build(:singing_diagnosis, overall_score: 101)

      expect(diagnosis.valid?).to eq false
    end
  end

  describe '前回診断との比較' do
    let(:customer) { FactoryBot.create(:customer, domain_name: "singing") }

    it '直近の前回completed診断を取得できること' do
      older_completed = FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed, created_at: 3.days.ago)
      FactoryBot.create(:singing_diagnosis, customer: customer, status: :failed, created_at: 2.days.ago)
      previous_completed = FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed, created_at: 1.day.ago)
      current = FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed, created_at: Time.current)

      expect(current.previous_completed_diagnosis).to eq previous_completed
      expect(current.previous_completed_diagnosis).not_to eq older_completed
    end

    it '現在より後のcompleted診断は比較対象にしないこと' do
      previous_completed = FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed, created_at: 2.days.ago)
      current = FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed, created_at: 1.day.ago)
      FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed, created_at: Time.current)

      expect(current.previous_completed_diagnosis).to eq previous_completed
    end

    it '現在の診断がcompletedでない場合は比較対象を返さないこと' do
      FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed, created_at: 1.day.ago)
      current = FactoryBot.create(:singing_diagnosis, customer: customer, status: :processing, created_at: Time.current)

      expect(current.previous_completed_diagnosis).to be_nil
      expect(current.score_comparison).to be_nil
    end

    it '別ユーザーのcompleted診断は比較対象にしないこと' do
      other_customer = FactoryBot.create(:customer, domain_name: "singing")
      FactoryBot.create(:singing_diagnosis, customer: other_customer, status: :completed, created_at: 1.day.ago)
      current = FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed, created_at: Time.current)

      expect(current.previous_completed_diagnosis).to be_nil
    end

    it '別のperformance_typeのcompleted診断は比較対象にしないこと' do
      FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed, performance_type: :guitar, created_at: 1.day.ago)
      current = FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed, performance_type: :vocal, created_at: Time.current)

      expect(current.previous_completed_diagnosis).to be_nil
    end

    it 'スコア差分を今回から前回を引いて計算すること' do
      previous_completed = FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        overall_score: 70,
        pitch_score: 65,
        rhythm_score: 80,
        expression_score: 75,
        created_at: 1.day.ago
      )
      current = FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        overall_score: 73,
        pitch_score: 63,
        rhythm_score: 80,
        expression_score: 82,
        created_at: Time.current
      )

      comparison = current.score_comparison(previous_completed)

      expect(comparison[:overall_score][:delta]).to eq 3
      expect(comparison[:pitch_score][:delta]).to eq(-2)
      expect(comparison[:rhythm_score][:delta]).to eq 0
      expect(comparison[:expression_score][:delta]).to eq 7
    end

    it 'specificスコア差分を同じkeyだけ計算すること' do
      previous_completed = FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        result_payload: {
          "specific" => {
            "volume_score" => 70,
            "pronunciation_score" => 80,
            "relax_score" => 60
          }
        },
        created_at: 1.day.ago
      )
      current = FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        result_payload: {
          "specific" => {
            "volume_score" => 73,
            "pronunciation_score" => 78,
            "mix_voice_score" => 66
          }
        },
        created_at: Time.current
      )

      comparison = current.specific_score_comparison(previous_completed)

      expect(comparison.keys).to contain_exactly(:volume_score, :pronunciation_score)
      expect(comparison[:volume_score][:delta]).to eq 3
      expect(comparison[:pronunciation_score][:delta]).to eq(-2)
    end

    it 'performance_typeが異なる場合はspecificスコア比較を返さないこと' do
      previous_completed = FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        performance_type: :guitar,
        result_payload: { "specific" => { "attack_score" => 70 } },
        created_at: 1.day.ago
      )
      current = FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        performance_type: :vocal,
        result_payload: { "specific" => { "volume_score" => 73 } },
        created_at: Time.current
      )

      expect(current.specific_score_comparison(previous_completed)).to be_nil
    end
  end

  describe '#priority_analysis?' do
    it 'premiumユーザーは優先解析対象になること' do
      customer = FactoryBot.create(:customer, domain_name: "singing")
      customer.create_subscription!(status: "active", plan: "premium")
      diagnosis = FactoryBot.build(:singing_diagnosis, customer: customer)

      expect(diagnosis.priority_analysis?).to eq true
    end

    it 'premium以外のユーザーは優先解析対象にならないこと' do
      customer = FactoryBot.create(:customer, domain_name: "singing")
      customer.create_subscription!(status: "active", plan: "core")
      diagnosis = FactoryBot.build(:singing_diagnosis, customer: customer)

      expect(diagnosis.priority_analysis?).to eq false
    end
  end

  describe '既存domainとの独立性のテスト' do
    it 'customerの既存domain判定に影響しないこと' do
      customer = FactoryBot.create(:customer, domain_name: "music")
      music = Domain.find_or_create_by!(name: "music")
      CustomerDomain.find_or_create_by!(customer: customer, domain: music)

      FactoryBot.create(:singing_diagnosis, customer: customer)

      expect(customer.music_user?).to eq true
      expect(customer.business_user?).to eq false
      expect(customer.learning_user?).to eq false
    end
  end
end
