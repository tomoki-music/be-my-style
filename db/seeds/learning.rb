learning = Domain.find_by!(name: "learning")

manager = Customer.find_or_create_by!(email: "learning.manager@example.com") do |customer|
  customer.domain_name = "learning"
  customer.name = "スクール講師"
  customer.password = "password"
  customer.prefecture_id = 13
  customer.introduction = "音楽スクールの進捗管理を担当しています。"
end
manager.domains << learning unless manager.domains.include?(learning)

owner = manager
learning_customers = Customer.joins(:domains).where(domains: { name: "learning" }).distinct

students = [
  { name: "山田太郎", email: "yamada.learning@example.com", main_part: "vocal", grade: "高校1年", status: "active", memo: "腹式呼吸の安定感が伸びてきている。", school_group_name: "A高校" },
  { name: "鈴木花子", email: "suzuki.learning@example.com", main_part: "guitar", grade: "高校2年", status: "active", memo: "コードチェンジの滑らかさを強化中。", school_group_name: "A高校" },
  { name: "佐藤健", email: "sato.learning@example.com", main_part: "bass", grade: "高校1年", status: "active", memo: "テンポキープが安定してきた。", school_group_name: "B高校" },
  { name: "高橋優", email: "takahashi.learning@example.com", main_part: "drums", grade: "高校3年", status: "active", memo: "8ビートとフィルのつなぎを練習中。", school_group_name: "B高校" },
  { name: "伊藤葵", email: "ito.learning@example.com", main_part: "keyboard", grade: "高校2年", status: "active", memo: "コード理解と両手演奏の精度を上げたい。", school_group_name: "A高校" }
]

school_groups = {
  "A高校" => owner.learning_school_groups.find_or_create_by!(name: "A高校"),
  "B高校" => owner.learning_school_groups.find_or_create_by!(name: "B高校")
}

students.each do |attributes|
  student = owner.learning_students.find_or_create_by!(name: attributes[:name]) do |record|
    record.main_part = attributes[:main_part]
    record.grade = attributes[:grade]
    record.status = attributes[:status]
    record.memo = attributes[:memo]
    record.learning_school_group = school_groups[attributes[:school_group_name]]
  end
  student.update!(attributes.except(:school_group_name).merge(learning_school_group: school_groups[attributes[:school_group_name]]))
  student.sync_parts!([attributes[:main_part]])
end

master_seed = [
  { part: "vocal", period: "1-2ヶ月", level: "基礎", title: "腹式呼吸", description: "仰向けになりお腹に手を当てて、4秒吸って8秒吐く呼吸を行う", achievement_criteria: "8秒吐きを10回連続で安定してできる", frequency: "毎日5分" },
  { part: "vocal", period: "1-2ヶ月", level: "基礎", title: "ロングトーン", description: "ピアノのドに合わせて「あー」で発声し10秒キープ", achievement_criteria: "音程を外さず10秒×5回キープできる", frequency: "毎日5分" },
  { part: "vocal", period: "1-2ヶ月", level: "基礎", title: "音程認識", description: "ピアノで単音（ドレミ）を鳴らし同じ音を声で再現する", achievement_criteria: "10問中8問以上正解する", frequency: "週3回" },
  { part: "vocal", period: "3-4ヶ月", level: "基礎", title: "簡単な曲", description: "テンポを70%に落として1曲通して歌う", achievement_criteria: "音程ミスが全体の20%以内", frequency: "週3回" },
  { part: "vocal", period: "3-4ヶ月", level: "基礎", title: "リズム理解", description: "メトロノームに合わせて手拍子＋歌唱を行う", achievement_criteria: "テンポからズレず1コーラス維持できる", frequency: "週3回" },
  { part: "vocal", period: "5-6ヶ月", level: "安定", title: "音程修正", description: "歌いながら音程ズレを自覚し即修正する", achievement_criteria: "録音でズレ箇所を3回以内に修正できる", frequency: "週3回" },
  { part: "vocal", period: "5-6ヶ月", level: "安定", title: "強弱", description: "サビ前→サビで声量を変える練習", achievement_criteria: "サビで明確に音圧が上がる（録音で確認）", frequency: "週3回" },
  { part: "vocal", period: "7-9ヶ月", level: "応用", title: "感情表現", description: "歌詞を3行ごとに意味を理解して歌う", achievement_criteria: "第三者が「感情が伝わる」と評価する", frequency: "週2回" },
  { part: "vocal", period: "7-9ヶ月", level: "応用", title: "声量コントロール", description: "1フレーズ内で小→中→大の変化をつける", achievement_criteria: "3段階の変化が聞き分けられる", frequency: "週2回" },
  { part: "vocal", period: "10-12ヶ月", level: "実践", title: "バンド対応", description: "マイクを使いバンド音源に合わせて歌う", achievement_criteria: "伴奏に埋もれず声が聞こえる", frequency: "月2回" },
  { part: "vocal", period: "10-12ヶ月", level: "実践", title: "表現確立", description: "同じ曲を2パターンで歌い分ける", achievement_criteria: "意図した違いを説明できる", frequency: "月2回" },

  { part: "guitar", period: "1-2ヶ月", level: "基礎", title: "チューニング", description: "チューナーを使い6弦〜1弦まで順番に音を合わせる", achievement_criteria: "全弦±5セント以内で合わせられる", frequency: "毎回" },
  { part: "guitar", period: "1-2ヶ月", level: "基礎", title: "基本コード", description: "C / G / D / Em をフォーム確認しながら押さえる", achievement_criteria: "全コードでビビりなく鳴らせる", frequency: "毎日5分" },
  { part: "guitar", period: "1-2ヶ月", level: "基礎", title: "ストローク", description: "ダウンストロークで4分音符を刻む（テンポ60）", achievement_criteria: "テンポ60で1分間ズレずに維持できる", frequency: "毎日5分" },
  { part: "guitar", period: "3-4ヶ月", level: "基礎", title: "コードチェンジ", description: "C→G→D→Emをループで切り替え", achievement_criteria: "テンポ60で止まらず1分間継続できる", frequency: "毎日5分" },
  { part: "guitar", period: "3-4ヶ月", level: "基礎", title: "簡単な曲", description: "テンポ70%に落として1曲通して弾く", achievement_criteria: "止まらず1曲通せる（ミス3回以内）", frequency: "週3回" },
  { part: "guitar", period: "5-6ヶ月", level: "安定", title: "バレーコード", description: "Fコードをフォーム確認しながら押さえる", achievement_criteria: "全弦しっかり鳴る状態で3回連続成功", frequency: "毎日5分" },
  { part: "guitar", period: "5-6ヶ月", level: "安定", title: "リズム安定", description: "メトロノームに合わせてストローク（テンポ70〜80）", achievement_criteria: "テンポ80で2分間ズレずに維持", frequency: "週3回" },
  { part: "guitar", period: "7-9ヶ月", level: "応用", title: "アルペジオ", description: "親指→人差し指→中指→薬指で順番に弾く", achievement_criteria: "テンポ60で1分間ミスなく継続", frequency: "週3回" },
  { part: "guitar", period: "7-9ヶ月", level: "応用", title: "強弱", description: "ストロークで弱→中→強の変化をつける", achievement_criteria: "録音で強弱の違いが明確に分かる", frequency: "週3回" },
  { part: "guitar", period: "10-12ヶ月", level: "実践", title: "アンサンブル", description: "バンド音源に合わせてリズムとコードを合わせる", achievement_criteria: "ドラムとズレず1曲通せる", frequency: "月2回" },
  { part: "guitar", period: "10-12ヶ月", level: "実践", title: "簡単アドリブ", description: "ペンタトニックスケールでフレーズを弾く", achievement_criteria: "同じフレーズを繰り返さず30秒弾ける", frequency: "週2回" },

  { part: "bass", period: "1-2ヶ月", level: "基礎", title: "姿勢", description: "ストラップを使い立った状態でベースを構え、右手・左手のフォームを確認", achievement_criteria: "無理な力みなく5分間安定して構えられる", frequency: "毎日5分" },
  { part: "bass", period: "1-2ヶ月", level: "基礎", title: "ルート音", description: "コード進行（C→G→Am→F）に合わせてルート音のみ弾く", achievement_criteria: "テンポ60で1分間ミスなく継続できる", frequency: "毎日5分" },
  { part: "bass", period: "1-2ヶ月", level: "基礎", title: "8分音符", description: "メトロノーム60に合わせて同じ音で8分音符を弾く", achievement_criteria: "テンポ60で1分間ズレずに維持できる", frequency: "毎日5分" },
  { part: "bass", period: "3-4ヶ月", level: "基礎", title: "リズムキープ", description: "メトロノーム70〜80に合わせてルート音を弾く", achievement_criteria: "テンポ80で2分間ズレずに維持できる", frequency: "週3回" },
  { part: "bass", period: "3-4ヶ月", level: "基礎", title: "ミュート", description: "弾いていない弦を右手・左手でミュートする練習", achievement_criteria: "不要な弦のノイズが出ない状態で演奏できる", frequency: "週3回" },
  { part: "bass", period: "5-6ヶ月", level: "安定", title: "フレーズ", description: "ルート＋5度＋オクターブを使った基本フレーズを弾く", achievement_criteria: "テンポ70で1分間ミス3回以内", frequency: "週3回" },
  { part: "bass", period: "5-6ヶ月", level: "安定", title: "ドラム合わせ", description: "ドラム音源のキックに合わせてルート音を弾く", achievement_criteria: "キックとズレず1曲通せる", frequency: "週3回" },
  { part: "bass", period: "7-9ヶ月", level: "応用", title: "グルーヴ", description: "同じフレーズで前ノリ・後ノリを弾き分ける", achievement_criteria: "録音で違いが明確に分かる", frequency: "週2回" },
  { part: "bass", period: "7-9ヶ月", level: "応用", title: "ゴーストノート", description: "フレーズの合間に軽くミュート音を入れる", achievement_criteria: "リズムを崩さず自然に入れられる", frequency: "週2回" },
  { part: "bass", period: "10-12ヶ月", level: "実践", title: "フレーズ作成", description: "コード進行に合わせてベースラインを自作する", achievement_criteria: "同じフレーズを繰り返さず1分間演奏できる", frequency: "週2回" },
  { part: "bass", period: "10-12ヶ月", level: "実践", title: "表現", description: "曲ごとにピッキング位置・強さを変える", achievement_criteria: "曲の雰囲気に合わせた違いを説明できる", frequency: "月2回" },

  { part: "drums", period: "1-2ヶ月", level: "基礎", title: "スティックの持ち方", description: "親指と人差し指を支点にしてスティックを持ち、リバウンドを使って叩く", achievement_criteria: "力まずに1分間連続で均一な音量で叩ける", frequency: "毎日5分" },
  { part: "drums", period: "1-2ヶ月", level: "基礎", title: "8ビート", description: "ハイハット8分・スネア2拍4拍・キック1拍3拍で叩く（テンポ60）", achievement_criteria: "テンポ60で1分間ズレずに維持できる", frequency: "毎日5分" },
  { part: "drums", period: "1-2ヶ月", level: "基礎", title: "テンポキープ", description: "メトロノームに合わせてスネアのみで4分音符を叩く", achievement_criteria: "テンポ60で1分間±ズレなしで維持", frequency: "毎日5分" },
  { part: "drums", period: "3-4ヶ月", level: "基礎", title: "フィルイン", description: "4小節ごとにタムを使ったフィルを入れる", achievement_criteria: "テンポ60で崩れず4回連続成功", frequency: "週3回" },
  { part: "drums", period: "3-4ヶ月", level: "基礎", title: "ハイハット操作", description: "ハイハットの開閉（クローズ・オープン）を使い分ける", achievement_criteria: "意図したタイミングで開閉できる", frequency: "週3回" },
  { part: "drums", period: "5-6ヶ月", level: "安定", title: "曲通し", description: "簡単な楽曲に合わせてドラムパターンを叩く", achievement_criteria: "止まらず1曲通せる（ミス3回以内）", frequency: "週3回" },
  { part: "drums", period: "5-6ヶ月", level: "安定", title: "ダイナミクス", description: "Aメロ・Bメロ・サビで音量を変える", achievement_criteria: "録音で強弱の違いが明確に分かる", frequency: "週3回" },
  { part: "drums", period: "7-9ヶ月", level: "応用", title: "16ビート", description: "ハイハット16分で8ビートを叩く（テンポ60→80）", achievement_criteria: "テンポ80で1分間安定して維持", frequency: "週3回" },
  { part: "drums", period: "7-9ヶ月", level: "応用", title: "バンド合わせ", description: "バンド音源に合わせてキックとベースを合わせる", achievement_criteria: "キックとベースがズレず1曲通せる", frequency: "週2回" },
  { part: "drums", period: "10-12ヶ月", level: "実践", title: "展開理解", description: "イントロ・Aメロ・Bメロ・サビの構成を理解して叩く", achievement_criteria: "構成を覚えてミスなく演奏できる", frequency: "週2回" },
  { part: "drums", period: "10-12ヶ月", level: "実践", title: "グルーヴ", description: "同じパターンで前ノリ・後ノリを叩き分ける", achievement_criteria: "録音で違いが明確に分かる", frequency: "週2回" },

  { part: "keyboard", period: "1-2ヶ月", level: "基礎", title: "ドレミ理解", description: "鍵盤のドの位置を基準に全音階（ドレミファソラシド）を確認する", achievement_criteria: "鍵盤を見ずにドの位置を3箇所特定できる", frequency: "毎日5分" },
  { part: "keyboard", period: "1-2ヶ月", level: "基礎", title: "コード基礎", description: "C / G / Am / F を右手で押さえる", achievement_criteria: "全コードを止まらずに切り替えられる（テンポ60で1分間）", frequency: "毎日5分" },
  { part: "keyboard", period: "1-2ヶ月", level: "基礎", title: "片手演奏", description: "右手で簡単なメロディを弾く（ドレミレベル）", achievement_criteria: "テンポ60で1フレーズミス3回以内", frequency: "週3回" },
  { part: "keyboard", period: "3-4ヶ月", level: "基礎", title: "両手演奏", description: "右手メロディ＋左手単音（ルート）で演奏", achievement_criteria: "テンポ50で1分間止まらず継続", frequency: "週3回" },
  { part: "keyboard", period: "3-4ヶ月", level: "基礎", title: "リズム", description: "メトロノームに合わせてコードを弾く", achievement_criteria: "テンポ70で1分間ズレずに維持", frequency: "週3回" },
  { part: "keyboard", period: "5-6ヶ月", level: "安定", title: "コード進行", description: "楽曲のコード進行に合わせて両手で演奏", achievement_criteria: "止まらず1曲通せる（ミス3回以内）", frequency: "週3回" },
  { part: "keyboard", period: "5-6ヶ月", level: "安定", title: "音色選択", description: "曲に合う音色（ピアノ・ストリングス等）を選ぶ", achievement_criteria: "3種類以上の音色を使い分け説明できる", frequency: "週2回" },
  { part: "keyboard", period: "7-9ヶ月", level: "応用", title: "バッキング", description: "コードをリズムに合わせて刻む（8分・16分）", achievement_criteria: "テンポ80で1分間安定して継続", frequency: "週3回" },
  { part: "keyboard", period: "7-9ヶ月", level: "応用", title: "メロディ強化", description: "強弱やタッチで表現をつける", achievement_criteria: "録音で強弱の違いが分かる", frequency: "週2回" },
  { part: "keyboard", period: "10-12ヶ月", level: "実践", title: "アレンジ", description: "同じコード進行で異なるパターンを作る", achievement_criteria: "2パターン以上の違いを演奏できる", frequency: "週2回" },
  { part: "keyboard", period: "10-12ヶ月", level: "実践", title: "バンド対応", description: "他パートを聴きながら音量・役割を調整", achievement_criteria: "埋もれず出過ぎずバランス良く弾ける", frequency: "月2回" },

  { part: "band", period: "常時", level: "基礎", title: "テンポ統一", description: "メトロノームに合わせて全員で演奏する", achievement_criteria: "1曲通してテンポズレなく演奏できる", frequency: "毎回" },
  { part: "band", period: "常時", level: "基礎", title: "音量バランス", description: "各パートの音量を調整しながら演奏する", achievement_criteria: "全パートが埋もれず聞き取れる状態", frequency: "毎回" },
  { part: "band", period: "1-3ヶ月", level: "基礎", title: "目合わせ", description: "セクション前にアイコンタクトを取る", achievement_criteria: "全員が同時に入れる（ズレなし）", frequency: "毎回" },
  { part: "band", period: "3-6ヶ月", level: "安定", title: "キック同期", description: "ドラムのキックとベースを合わせる", achievement_criteria: "ズレなく1曲通して演奏できる", frequency: "毎回" },
  { part: "band", period: "3-6ヶ月", level: "安定", title: "構成理解", description: "イントロ・Aメロ・Bメロ・サビの構成を共有する", achievement_criteria: "全員が構成を説明できる", frequency: "毎回" },
  { part: "band", period: "6-9ヶ月", level: "応用", title: "ダイナミクス", description: "Aメロ→サビで全体の強弱をつける", achievement_criteria: "録音で強弱の差が明確に分かる", frequency: "週1回" },
  { part: "band", period: "6-9ヶ月", level: "応用", title: "間（スペース）", description: "不要な音を減らして隙間を作る", achievement_criteria: "音の余白があり聴きやすい状態", frequency: "週1回" },
  { part: "band", period: "9-12ヶ月", level: "実践", title: "グルーヴ統一", description: "前ノリ・後ノリを全員で揃える", achievement_criteria: "録音で一体感が感じられる", frequency: "週1回" },
  { part: "band", period: "9-12ヶ月", level: "実践", title: "表現設計", description: "曲ごとの演奏コンセプトを決める", achievement_criteria: "全員がコンセプトを説明できる", frequency: "月2回" }
]

learning_customers.find_each do |customer|
  master_seed.each do |attributes|
    master = customer.learning_training_masters.find_or_initialize_by(
      part: attributes[:part],
      period: attributes[:period],
      level: attributes[:level],
      title: attributes[:title]
    )
    master.description = attributes[:description]
    master.achievement_criteria = attributes[:achievement_criteria]
    master.frequency = attributes[:frequency]
    master.is_band_training = (attributes[:part] == "band")
    master.save!
  end
end

all_band = owner.learning_bands.find_or_create_by!(name: "全体") do |band|
  band.memo = "スクール全体のバンド練習用"
end
all_band.sync_students!(owner.learning_students.pluck(:id))

owner.learning_students.includes(:learning_student_trainings).find_each do |student|
  next if student.learning_student_trainings.exists?

  owner.learning_training_masters.where(part: student.main_part, is_band_training: false).limit(3).each_with_index do |master, index|
    student.learning_student_trainings.create!(
      customer: owner,
      learning_training_master: master,
      status: index.zero? ? "in_progress" : "not_started",
      achievement_mark: index.zero? ? "star" : "triangle",
      weekly_goal: "#{master.title}を今週2回以上取り組む",
      teacher_comment: "前回より安定感が出てきました。次は#{master.achievement_criteria}を意識しましょう。"
    )
  end
end

owner.learning_training_masters.where(is_band_training: true).limit(3).each_with_index do |master, index|
  next if all_band.learning_band_trainings.exists?(title: master.title)

  related_parts =
    case master.title
    when "テンポ統一", "音量バランス", "目合わせ", "構成理解", "ダイナミクス", "間（スペース）", "グルーヴ統一", "表現設計"
      %w[vocal guitar bass drums keyboard]
    when "キック同期"
      %w[bass drums]
    else
      []
    end

  all_band.learning_band_trainings.create!(
    customer: owner,
    learning_training_master: master,
    related_parts: related_parts.join(","),
    status: index.zero? ? "in_progress" : "not_started",
    achievement_mark: index.zero? ? "triangle" : "cross",
    teacher_comment: "全員で目線と呼吸を合わせる意識を持っていきましょう。"
  )
end

owner.learning_students.includes(:learning_student_trainings).find_each do |student|
  student.learning_student_trainings.limit(2).each_with_index do |training, index|
    date = Date.current - index.days
    next if student.learning_progress_logs.exists?(training_title: training.title, practiced_on: date)

    student.learning_progress_logs.create!(
      customer: owner,
      learning_student_training: training,
      part: training.part,
      training_title: training.title,
      practiced_on: date,
      achievement_mark: index.zero? ? "star" : "triangle",
      comment: index.zero? ? "良い集中で取り組めた。次回もこの感覚を続けたい。" : "フォームは安定。テンポが少し揺れたので次回意識する。"
    )
  end
end
