module Singing
  class MissionGenerator
    Mission = Struct.new(
      :title,
      :description,
      :reason,
      :difficulty,
      :recommended_score,
      :coach_message,
      keyword_init: true
    )

    def self.call(customer, recommended_journey: nil, roadmap: nil, growth_type: nil, challenges: nil, progresses: nil, include_premium: false)
      new(
        customer,
        recommended_journey: recommended_journey,
        roadmap: roadmap,
        growth_type: growth_type,
        challenges: challenges,
        progresses: progresses,
        include_premium: include_premium
      ).call
    end

    def initialize(customer, recommended_journey: nil, roadmap: nil, growth_type: nil, challenges: nil, progresses: nil, include_premium: false)
      @customer = customer
      @recommended_journey = recommended_journey
      @roadmap = roadmap
      @growth_type = growth_type
      @challenges = challenges
      @progresses = progresses
      @include_premium = include_premium
    end

    def call
      mission_attrs =
        if diagnosis_count.zero?
          beginner_mission
        elsif diagnosis_count < 3
          consistency_mission
        elsif recommended_journey.present?
          recommended_mission
        else
          growth_type_mission
        end

      Mission.new(mission_attrs)
    end

    private

    def beginner_mission
      {
        title: "今月最初の一歩",
        description: "好きな曲を1コーラスだけ歌ってみよう。うまく歌うより、今日の声を残すことを大切に。",
        reason: "最初の録音は、成長のスタート地点になります。小さく始めるほど、次の挑戦につながりやすくなります。",
        difficulty: "やさしい",
        recommended_score: 88,
        coach_message: "今日はここだけやってみよう。完璧じゃなくて大丈夫、声を出した時点でもう一歩進んでいます。"
      }
    end

    def consistency_mission
      {
        title: "1分だけ歌おう",
        description: "完璧を目指さず、好きな曲を1分だけ歌ってみよう。録音できたら、それだけで今日の達成です。",
        reason: "診断回数が増えるほど、自分の声の調子や歌いやすい感覚が見つかっていきます。",
        difficulty: "やさしい",
        recommended_score: 92,
        coach_message: "続ける力は、短い一回から育ちます。今日は低いハードルで、気持ちよく始めよう。"
      }
    end

    def recommended_mission
      case recommended_journey.challenge.challenge_type
      when :expression_growth
        expression_mission(recommended_reason)
      when :rhythm_growth
        rhythm_mission(recommended_reason)
      when :pitch_growth
        pitch_mission(recommended_reason)
      when :streak, :diagnosis_count
        consistency_mission.merge(
          reason: recommended_reason,
          recommended_score: 94
        )
      else
        generic_mission.merge(
          reason: recommended_reason,
          recommended_score: 86
        )
      end
    end

    def growth_type_mission
      case growth_type&.type_key
      when :emotional_singer
        expression_mission("最近あなたの表現力が伸び始めています。今取り組むと、歌の気持ちよさがさらに育ちそうです。")
      when :rhythm_explorer
        rhythm_mission("リズムの感覚があなたの強みになり始めています。今日は体でリズムを感じる練習が合いそうです。")
      when :voice_challenger
        pitch_mission("音程への挑戦が積み上がっています。今日は短いフレーズで、声の当たり方を確かめてみよう。")
      when :consistency_hero
        consistency_mission.merge(
          title: "いつもの1曲を軽く歌おう",
          reason: "続けるリズムが育っています。今日も小さく歌うことで、その流れをやさしく保てます。",
          recommended_score: 91
        )
      when :dynamic_performer
        {
          title: "サビだけ気持ちよく通そう",
          description: "好きな曲のサビだけを、音程・リズム・表現のバランスを感じながら歌ってみよう。",
          reason: "全体のバランスが育っています。今日は細かく直すより、歌っていて気持ちいい流れを味わうのがおすすめです。",
          difficulty: "ふつう",
          recommended_score: 89,
          coach_message: "整ってきた歌は、楽しむほど伸びます。今日はサビだけ、気持ちよく通してみよう。"
        }
      else
        generic_mission
      end
    end

    def expression_mission(reason)
      {
        title: "感情を1つ決めて歌おう",
        description: "好きな曲のサビだけ録音し、嬉しい・切ない・まっすぐ届けたい、など感情を1つだけ意識して歌ってみよう。",
        reason: reason,
        difficulty: "ふつう",
        recommended_score: 92,
        coach_message: "今日は表現をひとつに絞って大丈夫。声に気持ちが乗る瞬間を、ゆっくり探してみよう。"
      }
    end

    def rhythm_mission(reason)
      {
        title: "リズムに乗ってみよう",
        description: "手拍子をしながら、好きな曲を1コーラスだけ歌ってみよう。体が揺れるくらいで十分です。",
        reason: reason,
        difficulty: "やさしい",
        recommended_score: 90,
        coach_message: "リズムは楽しさの土台です。今日は正確さより、曲に乗れた感覚を大切にしよう。"
      }
    end

    def pitch_mission(reason)
      {
        title: "短いフレーズを気持ちよく当てよう",
        description: "歌いやすい1フレーズだけ選んで、最初の音と最後の音を丁寧に歌ってみよう。",
        reason: reason,
        difficulty: "ふつう",
        recommended_score: 88,
        coach_message: "今日は全部を整えなくて大丈夫。短い一節が気持ちよく響けば、それが次の自信になります。"
      }
    end

    def generic_mission
      {
        title: "今日はここだけ歌ってみよう",
        description: "好きな曲から、歌いたい部分を少しだけ選んで録音してみよう。短くても、今日の挑戦になります。",
        reason: "データが少ないときは、まず気軽に歌える入口を作るのがおすすめです。",
        difficulty: "やさしい",
        recommended_score: 84,
        coach_message: "今日できる小さな一歩で十分です。歌えた時間は、ちゃんとあなたの成長に残ります。"
      }
    end

    def recommended_reason
      recommended_journey.reason.presence || recommended_journey.message.presence || "今のあなたに合う挑戦から、今日の一歩を選びました。"
    end

    def recommended_journey
      return @recommended_journey unless @recommended_journey.nil?

      @recommended_journey = Singing::RecommendedJourneyBuilder.call(
        @customer,
        progresses: progresses,
        challenges: @challenges,
        include_premium: @include_premium
      )
    end

    def growth_type
      @growth_type ||= Singing::GrowthTypeAnalyzer.call(@customer)
    rescue NameError, NoMethodError
      nil
    end

    def progresses
      @normalized_progresses ||= begin
        return @progresses unless @progresses.nil?

        Singing::ChallengeProgressBuilder.call(@customer, challenges: @challenges)
      end
    end

    def diagnosis_count
      return 0 if @customer.nil?

      @diagnosis_count ||= @customer.singing_diagnoses.completed.count
    rescue NoMethodError
      0
    end
  end
end
