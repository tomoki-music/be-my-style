module Singing
  class DailyChallengeGenerator
    CHALLENGE_POOL = [
      { challenge_type: "score_threshold", target_attribute: "overall",    threshold_value: 70,  xp_reward: 30, title: "今日は総合70点を目指せ！",   description: "総合スコア70点以上を1回達成しよう。" },
      { challenge_type: "score_threshold", target_attribute: "overall",    threshold_value: 80,  xp_reward: 40, title: "今日は総合80点チャレンジ！", description: "総合スコア80点以上を1回達成しよう。" },
      { challenge_type: "score_threshold", target_attribute: "pitch",      threshold_value: 75,  xp_reward: 30, title: "ピッチ精度75点に挑戦！",     description: "ピッチスコア75点以上を1回達成しよう。" },
      { challenge_type: "score_threshold", target_attribute: "pitch",      threshold_value: 85,  xp_reward: 40, title: "ピッチマスターを目指せ！",   description: "ピッチスコア85点以上を1回達成しよう。" },
      { challenge_type: "score_threshold", target_attribute: "rhythm",     threshold_value: 75,  xp_reward: 30, title: "リズム感75点チャレンジ！",   description: "リズムスコア75点以上を1回達成しよう。" },
      { challenge_type: "score_threshold", target_attribute: "rhythm",     threshold_value: 85,  xp_reward: 40, title: "リズムマスターに挑戦！",     description: "リズムスコア85点以上を1回達成しよう。" },
      { challenge_type: "score_threshold", target_attribute: "expression", threshold_value: 70,  xp_reward: 30, title: "表現力70点チャレンジ！",     description: "表現力スコア70点以上を1回達成しよう。" },
      { challenge_type: "score_threshold", target_attribute: "expression", threshold_value: 80,  xp_reward: 40, title: "表現力の達人を目指せ！",     description: "表現力スコア80点以上を1回達成しよう。" },
      { challenge_type: "count",           target_attribute: "overall",    threshold_value: 1,   xp_reward: 20, title: "今日1回診断してみよう！",     description: "1回でも診断を完了させよう。まずは記録から！" },
      { challenge_type: "count",           target_attribute: "overall",    threshold_value: 2,   xp_reward: 35, title: "今日2回チャレンジ！",         description: "今日2回診断を完了させよう。練習の積み重ねが大事！" },
    ].freeze

    def self.ensure_today
      new.ensure_today
    end

    def ensure_today
      date = Date.current
      SingingDailyChallenge.find_or_create_by!(challenge_date: date) do |challenge|
        template = pick_template(date)
        challenge.assign_attributes(template)
      end
    end

    private

    def pick_template(date)
      index = date.to_time.to_i % CHALLENGE_POOL.size
      CHALLENGE_POOL[index]
    end
  end
end
