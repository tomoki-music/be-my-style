# frozen_string_literal: true

# ═══════════════════════════════════════════════════════════════════
# 使い方
#
# 【全Learningユーザーへ一括投入】
#   RAILS_ENV=production bundle exec rails learning:seed_training_masters
#
# 【特定顧客のみ】
#   RAILS_ENV=production bundle exec rails learning:seed_training_masters CUSTOMER_ID=5
#
# 【Dry-run（DBへの書き込みなし）】
#   RAILS_ENV=production bundle exec rails learning:seed_training_masters DRY_RUN=1
#
# ■ 冪等性保証
#   find_or_initialize_by(customer_id:, part:, level:, period:, title:) で
#   同一レコードが存在する場合は description / achievement_criteria /
#   frequency / is_band_training だけを更新し、件数は増えない。
#
# ■ 禁止事項
#   destroy_all / delete_all は一切使用していない。
# ═══════════════════════════════════════════════════════════════════

namespace :learning do
  desc "Learning トレーニングマスターをデフォルトデータで冪等投入する"
  task seed_training_masters: :environment do
    dry_run    = ENV["DRY_RUN"].present?
    customer_id = ENV["CUSTOMER_ID"]

    targets = if customer_id
                Customer.where(id: customer_id)
                        .select { |c| c.learning_user? || c.admin? }
              else
                Customer.all.select { |c| c.learning_user? || c.admin? }
              end

    if targets.empty?
      puts "[learning:seed_training_masters] 対象顧客が見つかりません。終了します。"
      next
    end

    puts "[learning:seed_training_masters] #{dry_run ? '【DRY-RUN】' : ''}開始"
    puts "  対象顧客数: #{targets.size}"
    puts "  実行前 LearningTrainingMaster.count = #{LearningTrainingMaster.count}"
    puts ""

    total_created = 0
    total_updated = 0

    LearningTrainingMasters::DEFAULT_MASTERS.each do |attrs|
      targets.each do |customer|
        record = LearningTrainingMaster.find_or_initialize_by(
          customer_id:     customer.id,
          part:            attrs[:part],
          level:           attrs[:level],
          period:          attrs[:period],
          title:           attrs[:title],
          is_band_training: attrs[:is_band_training]
        )

        is_new = record.new_record?
        record.assign_attributes(
          description:          attrs[:description],
          achievement_criteria: attrs[:achievement_criteria],
          frequency:            attrs[:frequency]
        )

        unless dry_run
          record.save!
          is_new ? (total_created += 1) : (record.changed? ? (total_updated += 1) : nil)
        else
          is_new ? (total_created += 1) : (record.changed? ? (total_updated += 1) : nil)
        end
      end
    end

    puts "  新規作成: #{total_created} 件"
    puts "  更新:     #{total_updated} 件"
    puts "  スキップ: #{LearningTrainingMasters::DEFAULT_MASTERS.size * targets.size - total_created - total_updated} 件"
    puts ""
    puts "  実行後 LearningTrainingMaster.count = #{LearningTrainingMaster.count}"
    puts "[learning:seed_training_masters] 完了"
  end
end

# ═══════════════════════════════════════════════════════════════════
# デフォルトデータ定義
# ═══════════════════════════════════════════════════════════════════
module LearningTrainingMasters
  DEFAULT_MASTERS = [

    # ────────────────────────────────────────────
    # GUITAR — 個人
    # ────────────────────────────────────────────
    {
      part: "guitar", level: "基礎", period: "1-2ヶ月",
      title: "チューニング",
      description: "チューナーを使って6弦すべてを正確に合わせる。",
      achievement_criteria: "毎回練習前に1分以内に全弦を合わせられる",
      frequency: "毎回練習前",
      is_band_training: false
    },
    {
      part: "guitar", level: "基礎", period: "1-2ヶ月",
      title: "基本コード（C・G・Am・Em）",
      description: "4つの基本コードをタブ譜通りに押さえ、クリアに鳴らす。",
      achievement_criteria: "それぞれのコードで全弦がクリアに鳴っている",
      frequency: "週3回以上",
      is_band_training: false
    },
    {
      part: "guitar", level: "基礎", period: "1-2ヶ月",
      title: "8ビートストローク",
      description: "メトロノーム60BPMで8分音符のダウン・アップを安定させる。",
      achievement_criteria: "60BPMでリズムが崩れず1分間継続できる",
      frequency: "週3回以上",
      is_band_training: false
    },
    {
      part: "guitar", level: "基礎", period: "1-2ヶ月",
      title: "ペンタトニックスケール（ポジション1）",
      description: "Aマイナーペンタトニックの1st ポジションを上下できる。",
      achievement_criteria: "80BPMで迷わず音を当てられる",
      frequency: "週2回以上",
      is_band_training: false
    },
    {
      part: "guitar", level: "安定", period: "3-4ヶ月",
      title: "バレーコード（F・Bm）",
      description: "人差し指セーハで全弦を押さえ、クリアに鳴らす。",
      achievement_criteria: "FとBmを押さえてから1秒以内にストロークできる",
      frequency: "週3回以上",
      is_band_training: false
    },
    {
      part: "guitar", level: "安定", period: "3-4ヶ月",
      title: "アルペジオ基礎（p-i-m-a）",
      description: "クラシック指法で4弦を順番に弾く基本パターンを習得する。",
      achievement_criteria: "80BPMで途切れず4小節弾ける",
      frequency: "週2回以上",
      is_band_training: false
    },
    {
      part: "guitar", level: "安定", period: "3-4ヶ月",
      title: "コードチェンジをスムーズにする",
      description: "C→G→Am→F のコードチェンジを途切れなく繰り返す。",
      achievement_criteria: "100BPMで1周4小節止まらずコードチェンジができる",
      frequency: "週3回以上",
      is_band_training: false
    },
    {
      part: "guitar", level: "応用", period: "5-6ヶ月",
      title: "カッティング",
      description: "16ビートでミュートを入れたカッティングパターンを習得する。",
      achievement_criteria: "100BPMで8小節のカッティングが安定する",
      frequency: "週2回以上",
      is_band_training: false
    },
    {
      part: "guitar", level: "応用", period: "5-6ヶ月",
      title: "ソロフレーズの音作り",
      description: "アンプのゲイン・トーンを調整し、ソロに合った音を作る。",
      achievement_criteria: "バンド内でソロが抜ける音量と音色になっている",
      frequency: "合わせ前に確認",
      is_band_training: false
    },
    {
      part: "guitar", level: "実践", period: "7-9ヶ月",
      title: "曲のイントロ再現",
      description: "演奏予定曲のイントロを完全コピーし、原曲テンポで弾ける。",
      achievement_criteria: "原曲テンポで通して弾けている",
      frequency: "週3回以上",
      is_band_training: false
    },
    {
      part: "guitar", level: "実践", period: "7-9ヶ月",
      title: "バンドアンサンブルでの音量調整",
      description: "ボーカル・ドラムに合わせてギターの音量を調整できる。",
      achievement_criteria: "他パートの音が聴こえつつ自分の音も届いている",
      frequency: "合わせ毎回",
      is_band_training: false
    },

    # ────────────────────────────────────────────
    # BASS — 個人
    # ────────────────────────────────────────────
    {
      part: "bass", level: "基礎", period: "1-2ヶ月",
      title: "開放弦の音名と基本ポジション",
      description: "4弦の開放弦（E・A・D・G）と1〜5フレットのポジションを把握する。",
      achievement_criteria: "指示されたフレットに迷わず指が移動できる",
      frequency: "週3回以上",
      is_band_training: false
    },
    {
      part: "bass", level: "基礎", period: "1-2ヶ月",
      title: "8分音符ルート弾き",
      description: "コード進行（C-G-Am-F）に合わせてルート音を8分音符で弾く。",
      achievement_criteria: "80BPMで4小節ループを止まらず弾ける",
      frequency: "週3回以上",
      is_band_training: false
    },
    {
      part: "bass", level: "基礎", period: "1-2ヶ月",
      title: "正しいフォームとピッキング",
      description: "親指の位置・右手のピッキング角度を正しく習得する。",
      achievement_criteria: "長時間弾いても手首・肘が痛くならない",
      frequency: "毎練習確認",
      is_band_training: false
    },
    {
      part: "bass", level: "安定", period: "3-4ヶ月",
      title: "ルートとオクターブの交互弾き",
      description: "ルート音と1オクターブ上の音を交互に弾くパターンを習得する。",
      achievement_criteria: "100BPMで8小節安定する",
      frequency: "週3回以上",
      is_band_training: false
    },
    {
      part: "bass", level: "安定", period: "3-4ヶ月",
      title: "ミュートの基礎",
      description: "左手・右手のミュートで不要な弦の鳴りを消す技術を習得する。",
      achievement_criteria: "弾いていない弦が鳴っていない",
      frequency: "週2回以上",
      is_band_training: false
    },
    {
      part: "bass", level: "応用", period: "5-6ヶ月",
      title: "スラップ入門（サムピング）",
      description: "親指でのサムピング（ダウン方向）を習得する。",
      achievement_criteria: "80BPMで「ドンッ」という太い音が出る",
      frequency: "週2回以上",
      is_band_training: false
    },
    {
      part: "bass", level: "応用", period: "5-6ヶ月",
      title: "フィルインの作り方",
      description: "フレーズの最後にシンプルなフィルを入れてメリハリをつける。",
      achievement_criteria: "フィル後に次の頭へ迷わず戻れる",
      frequency: "週2回以上",
      is_band_training: false
    },
    {
      part: "bass", level: "実践", period: "7-9ヶ月",
      title: "ドラムとのグルーヴ合わせ",
      description: "ドラマーのバスドラとタイミングを合わせてグルーヴを作る。",
      achievement_criteria: "合わせ後にバンドメンバーから「気持ちいい」と言われる",
      frequency: "合わせ毎回意識",
      is_band_training: false
    },
    {
      part: "bass", level: "実践", period: "7-9ヶ月",
      title: "演奏予定曲のベースライン完全コピー",
      description: "曲のベースラインを原曲テンポで通して弾ける。",
      achievement_criteria: "原曲に合わせて通して弾ける",
      frequency: "週3回以上",
      is_band_training: false
    },

    # ────────────────────────────────────────────
    # DRUMS — 個人
    # ────────────────────────────────────────────
    {
      part: "drums", level: "基礎", period: "1-2ヶ月",
      title: "基本グリップとポジション",
      description: "マッチドグリップでスティックを正しく持ち、正しい姿勢で座る。",
      achievement_criteria: "先生にフォームを確認してOKをもらう",
      frequency: "毎練習確認",
      is_band_training: false
    },
    {
      part: "drums", level: "基礎", period: "1-2ヶ月",
      title: "8ビートパターン（基本）",
      description: "ハイハット8分・スネア2拍4拍・バスドラ1拍3拍の基本8ビートを叩く。",
      achievement_criteria: "70BPMで4小節ループを安定して叩ける",
      frequency: "週3回以上",
      is_band_training: false
    },
    {
      part: "drums", level: "基礎", period: "1-2ヶ月",
      title: "シングルストローク（左右交互）",
      description: "右・左・右・左を均等なダイナミクスで叩く基礎練習。",
      achievement_criteria: "メトロノーム60BPMで1分間ズレなく叩ける",
      frequency: "週3回以上",
      is_band_training: false
    },
    {
      part: "drums", level: "安定", period: "3-4ヶ月",
      title: "手足の独立：ハイハット+バスドラ",
      description: "右手ハイハットを叩きながら、任意のタイミングでバスドラを踏む。",
      achievement_criteria: "90BPMで8小節を安定して演奏できる",
      frequency: "週3回以上",
      is_band_training: false
    },
    {
      part: "drums", level: "安定", period: "3-4ヶ月",
      title: "シンプルなフィルイン",
      description: "4拍目にタム回しを入れた4小節ループを演奏する。",
      achievement_criteria: "フィル後に次の頭のスネアへ正確に戻れる",
      frequency: "週2回以上",
      is_band_training: false
    },
    {
      part: "drums", level: "応用", period: "5-6ヶ月",
      title: "16ビートパターン",
      description: "ハイハットを16分音符で刻む16ビートパターンを習得する。",
      achievement_criteria: "80BPMで4小節安定する",
      frequency: "週2回以上",
      is_band_training: false
    },
    {
      part: "drums", level: "応用", period: "5-6ヶ月",
      title: "ダブルストローク",
      description: "1打目の跳ね返りを使って2打目を出すダブルストロークを習得する。",
      achievement_criteria: "80BPMで16分音符のダブルが均等に出る",
      frequency: "週2回以上",
      is_band_training: false
    },
    {
      part: "drums", level: "実践", period: "7-9ヶ月",
      title: "テンポキープ（クリックなし）",
      description: "クリックなしで4分間、一定テンポを保って8ビートを叩く。",
      achievement_criteria: "バンドから「走らない・もたらない」と言われる",
      frequency: "合わせ毎回意識",
      is_band_training: false
    },
    {
      part: "drums", level: "実践", period: "7-9ヶ月",
      title: "演奏予定曲の通し",
      description: "曲のドラムパートを原曲テンポで通して叩ける。",
      achievement_criteria: "原曲に合わせて止まらず通して叩ける",
      frequency: "週3回以上",
      is_band_training: false
    },

    # ────────────────────────────────────────────
    # VOCAL — 個人
    # ────────────────────────────────────────────
    {
      part: "vocal", level: "基礎", period: "1-2ヶ月",
      title: "腹式呼吸の基礎",
      description: "横になって腹式呼吸を体感し、立った状態でも再現できるようにする。",
      achievement_criteria: "お腹を触られながら歌って腹式になっている",
      frequency: "毎練習ウォームアップ",
      is_band_training: false
    },
    {
      part: "vocal", level: "基礎", period: "1-2ヶ月",
      title: "発声練習（母音発声）",
      description: "「あえいうえおあお」を音程をつけて発声する基礎練習。",
      achievement_criteria: "全母音で音が途切れず出る",
      frequency: "週3回以上",
      is_band_training: false
    },
    {
      part: "vocal", level: "基礎", period: "1-2ヶ月",
      title: "歌詞の暗記",
      description: "演奏予定曲の歌詞を見ずに最後まで歌える。",
      achievement_criteria: "楽譜なしでAメロ〜サビを歌える",
      frequency: "週3回以上",
      is_band_training: false
    },
    {
      part: "vocal", level: "安定", period: "3-4ヶ月",
      title: "ロングトーン（4拍伸ばし）",
      description: "同じ音量・音程で4拍間ロングトーンを保つ練習。",
      achievement_criteria: "100BPMで4拍間音量が落ちない",
      frequency: "週3回以上",
      is_band_training: false
    },
    {
      part: "vocal", level: "安定", period: "3-4ヶ月",
      title: "ブレスポイントの設定",
      description: "歌詞の中でブレスするタイミングを決め、自然に聴こえるよう練習する。",
      achievement_criteria: "ブレスが目立たず歌のフレーズが繋がって聴こえる",
      frequency: "週3回以上",
      is_band_training: false
    },
    {
      part: "vocal", level: "応用", period: "5-6ヶ月",
      title: "ビブラート入門",
      description: "サビの伸ばす音にビブラートをかける練習。",
      achievement_criteria: "曲の中でビブラートが1箇所以上自然にかかっている",
      frequency: "週2回以上",
      is_band_training: false
    },
    {
      part: "vocal", level: "応用", period: "5-6ヶ月",
      title: "音程の安定（録音チェック）",
      description: "歌声を録音し、音程がずれているフレーズを特定して修正する。",
      achievement_criteria: "録音を聴いて自分でずれを指摘できる",
      frequency: "月2回以上",
      is_band_training: false
    },
    {
      part: "vocal", level: "実践", period: "7-9ヶ月",
      title: "マイクワーク（距離・角度）",
      description: "PAを通した自分の声の音量変化を確認しながらマイクとの距離を調整する。",
      achievement_criteria: "バンド合わせで「声が聴こえる」と言われる",
      frequency: "合わせ毎回意識",
      is_band_training: false
    },
    {
      part: "vocal", level: "実践", period: "7-9ヶ月",
      title: "感情表現・ステージング",
      description: "歌詞の意味を意識しながら表情・視線・ジェスチャーを加えて歌う。",
      achievement_criteria: "見ていたメンバーから「伝わった」という感想をもらう",
      frequency: "週2回以上",
      is_band_training: false
    },

    # ────────────────────────────────────────────
    # KEYBOARD — 個人
    # ────────────────────────────────────────────
    {
      part: "keyboard", level: "基礎", period: "1-2ヶ月",
      title: "鍵盤の音名把握",
      description: "白鍵・黒鍵すべての音名を指差して答えられるようにする。",
      achievement_criteria: "ランダムに指された音名を2秒以内に言える",
      frequency: "週3回以上",
      is_band_training: false
    },
    {
      part: "keyboard", level: "基礎", period: "1-2ヶ月",
      title: "Cメジャースケール（右手）",
      description: "Cから始まる1オクターブのメジャースケールを右手で弾く。",
      achievement_criteria: "60BPMで8分音符として滑らかに弾ける",
      frequency: "週3回以上",
      is_band_training: false
    },
    {
      part: "keyboard", level: "基礎", period: "1-2ヶ月",
      title: "コード（C・G・Am・F）の基本形",
      description: "4つのコードを右手でブロックコードとして弾く。",
      achievement_criteria: "各コードで3音すべてが同時に鳴っている",
      frequency: "週3回以上",
      is_band_training: false
    },
    {
      part: "keyboard", level: "安定", period: "3-4ヶ月",
      title: "両手コード弾き（ルート＋コード）",
      description: "左手でルート、右手でコードを同時に弾く。",
      achievement_criteria: "80BPMでC-G-Am-Fのループが止まらず弾ける",
      frequency: "週3回以上",
      is_band_training: false
    },
    {
      part: "keyboard", level: "安定", period: "3-4ヶ月",
      title: "8ビートのコードバッキング",
      description: "8分音符でリズムを刻みながらコードを弾くバッキングパターン。",
      achievement_criteria: "100BPMで4小節安定する",
      frequency: "週3回以上",
      is_band_training: false
    },
    {
      part: "keyboard", level: "応用", period: "5-6ヶ月",
      title: "コードの転回形",
      description: "同じコードを第1転回・第2転回に変えて弾く。",
      achievement_criteria: "ボイシングを3パターン使い分けられる",
      frequency: "週2回以上",
      is_band_training: false
    },
    {
      part: "keyboard", level: "応用", period: "5-6ヶ月",
      title: "オブリガード（イントロ・間奏）",
      description: "曲のイントロまたは間奏の印象的なフレーズをコピーして弾く。",
      achievement_criteria: "原曲テンポで通して弾ける",
      frequency: "週2回以上",
      is_band_training: false
    },
    {
      part: "keyboard", level: "実践", period: "7-9ヶ月",
      title: "バンドの中での音域・音量調整",
      description: "ギターやベースと音域が被らないようボイシングと音量を調整する。",
      achievement_criteria: "合わせで「キーボードが聴こえて邪魔にならない」と言われる",
      frequency: "合わせ毎回意識",
      is_band_training: false
    },
    {
      part: "keyboard", level: "実践", period: "7-9ヶ月",
      title: "演奏予定曲の通し",
      description: "曲のキーボードパートを原曲テンポで通して弾ける。",
      achievement_criteria: "原曲に合わせて止まらず通して弾ける",
      frequency: "週3回以上",
      is_band_training: false
    },

    # ────────────────────────────────────────────
    # BAND — バンド合わせ
    # ────────────────────────────────────────────
    {
      part: "band", level: "基礎", period: "1-2ヶ月",
      title: "全員チューニング確認",
      description: "合わせ開始前に全メンバーが各自チューニングを完了する。",
      achievement_criteria: "5分以内に全員のチューニングが揃っている",
      frequency: "合わせ毎回",
      is_band_training: true
    },
    {
      part: "band", level: "基礎", period: "1-2ヶ月",
      title: "クリックに合わせたスタート/ストップ",
      description: "クリックを聴きながら全員が同じタイミングで演奏を始め・止める。",
      achievement_criteria: "1小節のカウントで全員が揃ってスタートできる",
      frequency: "週2回以上",
      is_band_training: true
    },
    {
      part: "band", level: "基礎", period: "1-2ヶ月",
      title: "Aメロの通し（止まり有り）",
      description: "Aメロを最後まで演奏する。ミスしても止まらず続ける意識を持つ。",
      achievement_criteria: "Aメロを全員で最後まで演奏できる",
      frequency: "週2回以上",
      is_band_training: true
    },
    {
      part: "band", level: "安定", period: "3-4ヶ月",
      title: "曲の通し（止まりなし）",
      description: "演奏予定曲を1曲止まらずに演奏する。",
      achievement_criteria: "ミスがあっても全員が止まらず最後まで演奏できる",
      frequency: "週2回以上",
      is_band_training: true
    },
    {
      part: "band", level: "安定", period: "3-4ヶ月",
      title: "ダイナミクスの統一",
      description: "Aメロ（小）→サビ（大）のダイナミクス変化を全員で合わせる。",
      achievement_criteria: "サビで全員が音量を上げるタイミングが揃っている",
      frequency: "週2回以上",
      is_band_training: true
    },
    {
      part: "band", level: "安定", period: "3-4ヶ月",
      title: "お互いの音を聴く練習",
      description: "自分のパートを演奏しながら他のパートの音を意識して聴く。",
      achievement_criteria: "合わせ後に他パートの気になる点を言語化できる",
      frequency: "合わせ毎回意識",
      is_band_training: true
    },
    {
      part: "band", level: "応用", period: "5-6ヶ月",
      title: "ソロパートの受け渡し",
      description: "ギターソロや間奏でのパート受け渡しタイミングを全員で確認し揃える。",
      achievement_criteria: "受け渡し箇所で全員のタイミングが一致している",
      frequency: "週2回以上",
      is_band_training: true
    },
    {
      part: "band", level: "応用", period: "5-6ヶ月",
      title: "アレンジの調整（音量バランス）",
      description: "録音を聴き直し、各パートの音量バランスを調整する。",
      achievement_criteria: "録音を聴いてボーカルが埋もれていない",
      frequency: "月2回",
      is_band_training: true
    },
    {
      part: "band", level: "実践", period: "7-9ヶ月",
      title: "MC込み通し練習",
      description: "本番を想定してMC・曲間のつなぎ込みで通す。",
      achievement_criteria: "本番と同じ流れで30分以上演奏できる",
      frequency: "本番2週間前から週1以上",
      is_band_training: true
    },
    {
      part: "band", level: "実践", period: "7-9ヶ月",
      title: "録音して聴き直し・改善",
      description: "スマホで録音し、改善点を3つ以上リストアップして次の練習に活かす。",
      achievement_criteria: "改善点リストを書いて先生に提出できる",
      frequency: "月2回以上",
      is_band_training: true
    },
    {
      part: "band", level: "実践", period: "常時",
      title: "本番前の最終確認",
      description: "本番当日のリハーサルで全員の機材・チューニング・セットリストを確認する。",
      achievement_criteria: "本番30分前に全チェックが完了している",
      frequency: "本番当日",
      is_band_training: true
    }
  ].freeze
end
