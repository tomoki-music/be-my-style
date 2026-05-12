require 'rails_helper'

RSpec.describe "Singing::Diagnoses", type: :request do
  include ActiveJob::TestHelper

  let(:singing_customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let(:music_customer) { FactoryBot.create(:customer, domain_name: "music") }
  let!(:singing_domain) { Domain.find_or_create_by!(name: "singing") }
  let!(:music_domain) { Domain.find_or_create_by!(name: "music") }

  around do |example|
    original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs
    example.run
    clear_enqueued_jobs
    clear_performed_jobs
    ActiveJob::Base.queue_adapter = original_adapter
  end

  before do
    CustomerDomain.find_or_create_by!(customer: singing_customer, domain: singing_domain)
    CustomerDomain.find_or_create_by!(customer: music_customer, domain: music_domain)
  end

  describe "GET /singing/diagnoses/new" do
    it "singingユーザーがアクセスできること" do
      sign_in singing_customer

      get new_singing_diagnosis_path

      expect(response).to have_http_status(:ok)
    end

    it "freeユーザーに今月の歌唱・演奏診断回数を表示すること" do
      sign_in singing_customer

      get new_singing_diagnosis_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("今月の歌唱・演奏診断")
      expect(response.body).to include("今月の完了済み診断 0 / 1 回")
    end

    it "診断対象はボーカル・ギター・ベース・ドラム・キーボード・バンド演奏を選択可能として表示すること" do
      sign_in singing_customer

      get new_singing_diagnosis_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("診断対象")
      expect(response.body).to include("ボーカル")
      expect(response.body).to include("ギター")
      expect(response.body).to include("ベース")
      expect(response.body).to include("ドラム")
      expect(response.body).to include("キーボード")
      expect(response.body).to include("バンド演奏")
      expect(response.body).not_to include("今後対応予定です。")
    end

    it "band診断の説明文と推奨音源を表示すること" do
      sign_in singing_customer

      get new_singing_diagnosis_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("「うまいのにバンドだと微妙」を、アンサンブル力から見える化。")
      expect(response.body).to include("バンド演奏診断")
      expect(response.body).to include("音量バランス・リズムの揃い・グルーヴ・一体感を診断")
      expect(response.body).to include("30秒以上のバンド演奏音源がおすすめです。")
      expect(response.body).to include("NEW")
      expect(response.body).to include("アンサンブル対応")
      expect(response.body).to include("Premium相性◎")
    end

    it "band向けPremium案内文に週間アドバイスの説明を含むこと" do
      sign_in singing_customer

      get new_singing_diagnosis_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("今週のバンド練習テーマ")
      expect(response.body).to include("スタジオでやること")
      expect(response.body).to include("録音チェックポイント")
    end

    it "lightユーザーに月5回の診断回数を表示すること" do
      singing_customer.create_subscription!(status: "active", plan: "light")
      sign_in singing_customer

      get new_singing_diagnosis_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("今月の完了済み診断 0 / 5 回")
    end

    it "premiumユーザーには無制限の案内を表示すること" do
      singing_customer.create_subscription!(status: "active", plan: "premium")
      sign_in singing_customer

      get new_singing_diagnosis_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("今月の診断回数を気にせず依頼できます")
    end

    it "premiumユーザーには優先解析の案内を表示すること" do
      singing_customer.create_subscription!(status: "active", plan: "premium")
      sign_in singing_customer

      get new_singing_diagnosis_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Premium 優先解析")
      expect(response.body).to include("優先解析対象として受け付けます")
    end

    it "freeユーザーが上限到達済みの場合はアップグレード導線を表示すること" do
      sign_in singing_customer
      FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :completed)

      get new_singing_diagnosis_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("今月の完了済み診断回数を使い切りました")
      expect(response.body).to include("歌唱・演奏診断のプランを見る")
    end

    it "musicユーザーも共通診断フォームにアクセスできること" do
      sign_in music_customer

      get new_singing_diagnosis_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("歌唱・演奏診断を依頼する")
    end
  end

  describe "GET /singing/diagnoses" do
    it "singingユーザーが自分の診断履歴を表示できること" do
      sign_in singing_customer
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        song_title: "My Singing",
        status: :completed,
        overall_score: 88
      )
      other_customer = FactoryBot.create(:customer, domain_name: "singing")
      FactoryBot.create(:singing_diagnosis, customer: other_customer, song_title: "Other Singing")

      get singing_diagnoses_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("成長記録")
      expect(response.body).to include("My Singing")
      expect(response.body).to include("ボーカル")
      expect(response.body).to include("88")
      expect(response.body).to include(singing_diagnosis_path(diagnosis))
      expect(response.body).not_to include("Other Singing")
    end

    it "診断履歴がない場合は空状態を表示すること" do
      sign_in singing_customer

      get singing_diagnoses_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("まだ診断履歴はありません")
    end

    it "解析中の診断がある場合は自動更新対象になること" do
      sign_in singing_customer
      FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :processing)

      get singing_diagnoses_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-singing-diagnosis-polling')
    end

    it "完了済みの診断のみの場合は自動更新対象にならないこと" do
      sign_in singing_customer
      FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :completed)

      get singing_diagnoses_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('data-singing-diagnosis-polling')
    end

    it "musicユーザーも共通診断履歴にアクセスできること" do
      sign_in music_customer

      get singing_diagnoses_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("成長記録")
    end
  end

  describe "POST /singing/diagnoses" do
    it "queued状態で診断リクエストを作成し音声ファイルを添付できること" do
      sign_in singing_customer

      expect do
        post singing_diagnoses_path, params: {
          singing_diagnosis: {
            song_title: "Sample Song",
            memo: "高音を確認したい",
            audio_file: fixture_file_upload(Rails.root.join("spec/fixtures/11megabytes_sample.png"), "audio/mpeg")
          }
        }
      end.to change(SingingDiagnosis, :count).by(1)

      diagnosis = SingingDiagnosis.last
      expect(diagnosis.customer).to eq singing_customer
      expect(diagnosis).to be_queued
      expect(diagnosis).to be_performance_type_vocal
      expect(diagnosis.audio_file).to be_attached
      expect(response).to redirect_to(singing_diagnosis_path(diagnosis))
    end

    it "作成成功時に解析送信Jobをenqueueすること" do
      sign_in singing_customer

      expect do
        post singing_diagnoses_path, params: {
          singing_diagnosis: {
            song_title: "Sample Song",
            memo: "高音を確認したい",
            audio_file: fixture_file_upload(Rails.root.join("spec/fixtures/11megabytes_sample.png"), "audio/mpeg")
          }
        }
      end.to have_enqueued_job(SingingDiagnoses::SubmitToAnalyzerJob)
    end

    it "guitarの診断対象を指定して作成できること" do
      sign_in singing_customer

      post singing_diagnoses_path, params: {
        singing_diagnosis: {
          performance_type: "guitar",
          song_title: "Sample Song",
          memo: "ギターのリズムを確認したい",
          audio_file: fixture_file_upload(Rails.root.join("spec/fixtures/11megabytes_sample.png"), "audio/mpeg")
        }
      }

      expect(SingingDiagnosis.last).to be_performance_type_guitar
    end

    it "bassの診断対象を作成できること" do
      sign_in singing_customer

      post singing_diagnoses_path, params: {
        singing_diagnosis: {
          performance_type: "bass",
          song_title: "Sample Song",
          memo: "ベースを確認したい",
          audio_file: fixture_file_upload(Rails.root.join("spec/fixtures/11megabytes_sample.png"), "audio/mpeg")
        }
      }

      expect(SingingDiagnosis.last).to be_performance_type_bass
    end

    it "drumsの診断対象を作成できること" do
      sign_in singing_customer

      post singing_diagnoses_path, params: {
        singing_diagnosis: {
          performance_type: "drums",
          song_title: "Sample Song",
          memo: "ドラムを確認したい",
          audio_file: fixture_file_upload(Rails.root.join("spec/fixtures/11megabytes_sample.png"), "audio/mpeg")
        }
      }

      expect(SingingDiagnosis.last).to be_performance_type_drums
    end

    it "keyboardの診断対象を作成できること" do
      sign_in singing_customer

      post singing_diagnoses_path, params: {
        singing_diagnosis: {
          performance_type: "keyboard",
          song_title: "Sample Song",
          memo: "キーボードを確認したい",
          audio_file: fixture_file_upload(Rails.root.join("spec/fixtures/11megabytes_sample.png"), "audio/mpeg")
        }
      }

      expect(SingingDiagnosis.last).to be_performance_type_keyboard
    end

    it "bandの診断対象を作成できること" do
      sign_in singing_customer

      post singing_diagnoses_path, params: {
        singing_diagnosis: {
          performance_type: "band",
          song_title: "Sample Song",
          memo: "バンド全体のまとまりを確認したい",
          audio_file: fixture_file_upload(Rails.root.join("spec/fixtures/11megabytes_sample.png"), "audio/mpeg")
        }
      }

      expect(SingingDiagnosis.last).to be_performance_type_band
    end

    it "未対応の診断対象が送信されても当面はvocalとして作成すること" do
      sign_in singing_customer

      post singing_diagnoses_path, params: {
        singing_diagnosis: {
          performance_type: "violin",
          song_title: "Sample Song",
          memo: "未対応楽器の送信",
          audio_file: fixture_file_upload(Rails.root.join("spec/fixtures/11megabytes_sample.png"), "audio/mpeg")
        }
      }

      expect(SingingDiagnosis.last).to be_performance_type_vocal
    end

    it "premiumユーザーは優先度付きで解析送信Jobをenqueueすること" do
      singing_customer.create_subscription!(status: "active", plan: "premium")
      sign_in singing_customer

      post singing_diagnoses_path, params: {
        singing_diagnosis: {
          song_title: "Sample Song",
          memo: "高音を確認したい",
          audio_file: fixture_file_upload(Rails.root.join("spec/fixtures/11megabytes_sample.png"), "audio/mpeg")
        }
      }

      expect(enqueued_jobs.last[:job]).to eq SingingDiagnoses::SubmitToAnalyzerJob
      expect(enqueued_jobs.last["priority"]).to eq 0
    end

    it "freeユーザーが今月の診断回数を使い切っている場合は作成できないこと" do
      sign_in singing_customer
      FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :completed)

      expect do
        post singing_diagnoses_path, params: {
          singing_diagnosis: {
            song_title: "Sample Song",
            memo: "高音を確認したい",
            audio_file: fixture_file_upload(Rails.root.join("spec/fixtures/11megabytes_sample.png"), "audio/mpeg")
          }
        }
      end.not_to change(SingingDiagnosis, :count)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("今月の完了済み診断回数を使い切りました")
    end

    it "freeユーザーでもfailed診断のみの場合は再度作成できること" do
      sign_in singing_customer
      FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :failed)

      expect do
        post singing_diagnoses_path, params: {
          singing_diagnosis: {
            song_title: "Sample Song",
            memo: "失敗後の再診断",
            audio_file: fixture_file_upload(Rails.root.join("spec/fixtures/11megabytes_sample.png"), "audio/mpeg")
          }
        }
      end.to change(SingingDiagnosis, :count).by(1)

      expect(response).to redirect_to(singing_diagnosis_path(SingingDiagnosis.last))
    end

    it "lightユーザーは月5回未満なら作成できること" do
      singing_customer.create_subscription!(status: "active", plan: "light")
      sign_in singing_customer
      FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :completed)

      expect do
        post singing_diagnoses_path, params: {
          singing_diagnosis: {
            song_title: "Sample Song",
            memo: "高音を確認したい",
            audio_file: fixture_file_upload(Rails.root.join("spec/fixtures/11megabytes_sample.png"), "audio/mpeg")
          }
        }
      end.to change(SingingDiagnosis, :count).by(1)

      expect(response).to redirect_to(singing_diagnosis_path(SingingDiagnosis.last))
    end

    it "lightユーザーが月5回使い切っている場合は作成できないこと" do
      singing_customer.create_subscription!(status: "active", plan: "light")
      sign_in singing_customer
      FactoryBot.create_list(:singing_diagnosis, 5, customer: singing_customer, status: :completed)

      expect do
        post singing_diagnoses_path, params: {
          singing_diagnosis: {
            song_title: "Sample Song",
            memo: "高音を確認したい",
            audio_file: fixture_file_upload(Rails.root.join("spec/fixtures/11megabytes_sample.png"), "audio/mpeg")
          }
        }
      end.not_to change(SingingDiagnosis, :count)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("今月の完了済み診断回数を使い切りました")
    end

    it "premiumユーザーは診断数に関係なく作成できること" do
      singing_customer.create_subscription!(status: "active", plan: "premium")
      sign_in singing_customer
      FactoryBot.create_list(:singing_diagnosis, 5, customer: singing_customer)

      expect do
        post singing_diagnoses_path, params: {
          singing_diagnosis: {
            song_title: "Sample Song",
            memo: "高音を確認したい",
            audio_file: fixture_file_upload(Rails.root.join("spec/fixtures/11megabytes_sample.png"), "audio/mpeg")
          }
        }
      end.to change(SingingDiagnosis, :count).by(1)

      expect(response).to redirect_to(singing_diagnosis_path(SingingDiagnosis.last))
    end

    it "作成失敗時は解析送信Jobをenqueueしないこと" do
      sign_in singing_customer

      expect do
        post singing_diagnoses_path, params: {
          singing_diagnosis: {
            song_title: "Sample Song",
            memo: "音声なし"
          }
        }
      end.not_to have_enqueued_job(SingingDiagnoses::SubmitToAnalyzerJob)
    end
  end

  describe "GET /singing/diagnoses/:id" do
    it "singingユーザーが自分の診断を表示できること" do
      sign_in singing_customer
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: singing_customer)

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("診断対象")
      expect(response.body).to include("ボーカル")
    end

    it "解析待ちの診断は自動更新対象になること" do
      sign_in singing_customer
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :queued)

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-singing-diagnosis-polling')
    end

    it "premiumユーザーの診断には優先解析表示を出すこと" do
      singing_customer.create_subscription!(status: "active", plan: "premium")
      sign_in singing_customer
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :queued)

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Premium 優先解析")
      expect(response.body).to include("解析種別")
    end

    it "coreユーザーの完了vocal診断には6つのボイスタイプ診断を表示すること" do
      singing_customer.create_subscription!(status: "active", plan: "core")
      sign_in singing_customer
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :completed)

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("歌唱の深掘り診断")
      expect(response.body).to include("歌唱チェック項目")
      expect(response.body).to include("ミックスボイスチェック項目")
      expect(response.body).to include("あなたの歌声タイプ診断")
      expect(response.body).to include("6つの歌声タイプマップ")
      expect(response.body).to include("パワフルボイス")
      expect(response.body).to include("ハイトーンボイス")
      expect(response.body).to include("クリスタルボイス")
      expect(response.body).to include("Core以上")
    end

    it "premiumユーザーの完了vocal診断にも6つのボイスタイプ診断を表示すること" do
      singing_customer.create_subscription!(status: "active", plan: "premium")
      sign_in singing_customer
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :completed)

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("6つの歌声タイプマップ")
      expect(response.body).to include("パワフルボイス")
    end

    it "coreユーザーの完了診断には次のおすすめ練習メニューの詳細を表示すること" do
      singing_customer.create_subscription!(status: "active", plan: "core")
      sign_in singing_customer
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :completed, pitch_score: 60)

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("次のおすすめ練習メニュー")
      expect(response.body).to include("音程安定トレーニング")
      expect(response.body).to include("まずは短いフレーズをゆっくり歌い")
      expect(response.body).not_to include("あなた専用の練習メニューを確認しよう")
    end

    it "premiumユーザーの完了診断には次のおすすめ練習メニューの詳細を表示すること" do
      singing_customer.create_subscription!(status: "active", plan: "premium")
      sign_in singing_customer
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :completed, rhythm_score: 60)

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("次のおすすめ練習メニュー")
      expect(response.body).to include("リズムキープ練習")
      expect(response.body).to include("メトロノームに合わせて")
    end

    it "coreユーザーの完了診断には月次成長レポート詳細を表示すること" do
      singing_customer.create_subscription!(status: "active", plan: "core")
      sign_in singing_customer
      previous_time = 1.month.ago
      FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :completed, created_at: previous_time, overall_score: 75, pitch_score: 70, rhythm_score: 70, expression_score: 70)
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :completed, overall_score: 85, pitch_score: 85, rhythm_score: 60, expression_score: 80)

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("今月の成長レポート")
      expect(response.body).to include("今月の診断回数")
      expect(response.body).to include("前月比")
      expect(response.body).to include("+10点")
      expect(response.body).to include("一番伸びた項目")
      expect(response.body).to include("音程")
      expect(response.body).to include("今月の重点練習")
      expect(response.body).to include("リズム")
      expect(response.body).to include("今月はリズム安定を重点的に練習しましょう。")
      expect(response.body).to include("次のおすすめ練習メニュー")
    end

    it "premiumユーザーの完了診断にも月次成長レポート詳細を表示すること" do
      singing_customer.create_subscription!(status: "active", plan: "premium")
      sign_in singing_customer
      FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :completed, created_at: 1.month.ago, overall_score: 70, pitch_score: 70, rhythm_score: 70, expression_score: 70)
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :completed, overall_score: 80, pitch_score: 72, rhythm_score: 78, expression_score: 82)

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("今月の成長レポート")
      expect(response.body).to include("今月の診断回数")
      expect(response.body).to include("+10点")
    end

    it "lightユーザーの完了vocal診断には6つのボイスタイプ診断のCore導線を表示すること" do
      singing_customer.create_subscription!(status: "active", plan: "light")
      sign_in singing_customer
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :completed)

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("6つのボイスタイプ診断はCoreプラン以上で解放されます")
      expect(response.body).to include("Core以上のプランを見る")
      expect(response.body).not_to include("6つの歌声タイプマップ")
    end

    it "lightユーザーの完了診断には次のおすすめ練習メニューのCore導線を表示すること" do
      singing_customer.create_subscription!(status: "active", plan: "light")
      sign_in singing_customer
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :completed, expression_score: 60)

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("次のおすすめ練習メニュー")
      expect(response.body).to include("表現力アップ練習")
      expect(response.body).to include("あなた専用の練習メニューを確認しよう")
      expect(response.body).to include("Coreプランで詳しく見る")
    end

    it "lightユーザーの完了診断には月次成長レポートのCTAだけを表示すること" do
      singing_customer.create_subscription!(status: "active", plan: "light")
      sign_in singing_customer
      FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :completed, created_at: 1.month.ago, overall_score: 75, pitch_score: 70, rhythm_score: 70, expression_score: 70)
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :completed, overall_score: 85, pitch_score: 85, rhythm_score: 60, expression_score: 80)

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("今月の成長レポート")
      expect(response.body).to include("月ごとの成長を確認しよう")
      expect(response.body).to include("Coreプランで成長レポートを見る")
      expect(response.body).not_to include("前月 1回")
      expect(response.body).not_to include("前月比")
      expect(response.body).not_to include("+10点")
      expect(response.body).not_to include("今月はリズム安定を重点的に練習しましょう。")
    end

    it "freeユーザーの完了vocal診断には6つのボイスタイプ診断のCore導線を表示すること" do
      sign_in singing_customer
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :completed)

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("6つのボイスタイプ診断はCoreプラン以上で解放されます")
      expect(response.body).to include("Core以上のプランを見る")
      expect(response.body).not_to include("6つの歌声タイプマップ")
    end

    it "freeユーザーの完了診断には次のおすすめ練習メニューのCore導線を表示すること" do
      sign_in singing_customer
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :completed, pitch_score: 60, rhythm_score: 60)

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("次のおすすめ練習メニュー")
      expect(response.body).to include("音程安定トレーニング")
      expect(response.body).not_to include("リズムキープ練習")
      expect(response.body).to include("Coreプランでは、診断結果に応じた練習メニュー")
    end

    it "freeユーザーの完了診断には月次成長レポートのCTAだけを表示すること" do
      sign_in singing_customer
      FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :completed, created_at: 1.month.ago, overall_score: 75, pitch_score: 70, rhythm_score: 70, expression_score: 70)
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :completed, overall_score: 85, pitch_score: 85, rhythm_score: 60, expression_score: 80)

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("今月の成長レポート")
      expect(response.body).to include("月ごとの成長を確認しよう")
      expect(response.body).to include("Coreプランで成長レポートを見る")
      expect(response.body).not_to include("前月 1回")
      expect(response.body).not_to include("前月比")
      expect(response.body).not_to include("+10点")
      expect(response.body).not_to include("今月はリズム安定を重点的に練習しましょう。")
    end

    it "premiumユーザーのguitar診断にはタイプ別詳細診断を表示すること" do
      singing_customer.create_subscription!(status: "active", plan: "premium")
      sign_in singing_customer
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        performance_type: :guitar,
        result_payload: {
          "performance_type" => "guitar",
          "specific" => {
            "attack_score" => 74,
            "muting_score" => 68,
            "stability_score" => 72
          }
        }
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ギター演奏の深掘り診断")
      expect(response.body).to include("発音の輪郭")
      expect(response.body).to include("余韻の整理")
      expect(response.body).to include("演奏の芯")
      expect(response.body).not_to include("取り入れると良い歌声タイプ")
    end

    it "premiumユーザーのbass診断にはタイプ別詳細診断を表示すること" do
      singing_customer.create_subscription!(status: "active", plan: "premium")
      sign_in singing_customer
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        performance_type: :bass,
        result_payload: {
          "performance_type" => "bass",
          "specific" => {
            "groove_score" => 78,
            "note_length_score" => 69,
            "stability_score" => 74
          }
        }
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ベース演奏の土台診断")
      expect(response.body).to include("ノリの土台")
      expect(response.body).to include("音価コントロール")
      expect(response.body).to include("低音の支え")
      expect(response.body).not_to include("コード安定")
    end

    it "premiumユーザーのdrums診断にはタイプ別詳細診断を表示すること" do
      singing_customer.create_subscription!(status: "active", plan: "premium")
      sign_in singing_customer
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        performance_type: :drums,
        result_payload: {
          "performance_type" => "drums",
          "specific" => {
            "tempo_stability_score" => 76,
            "rhythm_precision_score" => 71,
            "fill_control_score" => 73
          }
        }
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ドラム演奏のリズム診断")
      expect(response.body).to include("テンポの支え")
      expect(response.body).to include("リズムの芯")
      expect(response.body).to include("展開のまとまり")
      expect(response.body).not_to include("ハーモニー")
    end

    it "premiumユーザーのkeyboard診断にはタイプ別詳細診断を表示すること" do
      singing_customer.create_subscription!(status: "active", plan: "premium")
      sign_in singing_customer
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        performance_type: :keyboard,
        result_payload: {
          "performance_type" => "keyboard",
          "specific" => {
            "chord_stability_score" => 77,
            "note_connection_score" => 72,
            "touch_score" => 69
          }
        }
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("キーボード演奏の響き診断")
      expect(response.body).to include("和音の安定")
      expect(response.body).to include("音のつながり")
      expect(response.body).to include("タッチと響き")
      expect(response.body).not_to include("フィル")
    end

    it "完了済みの診断は自動更新対象にならないこと" do
      sign_in singing_customer
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :completed)

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('data-singing-diagnosis-polling')
    end

    it "完了済みの診断はレーダーチャート表示対象になること" do
      sign_in singing_customer
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :completed)

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-singing-diagnosis-radar')
      expect(response.body).to include("音程")
      expect(response.body).to include("リズム")
      expect(response.body).to include("表現")
    end

    it "診断履歴が1件だけでも成長推移の初回表示を出すこと" do
      sign_in singing_customer
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :completed)

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("成長推移")
      expect(response.body).to include('data-singing-diagnosis-growth')
      expect(response.body).to include("初回診断データです")
    end

    it "specificスコアがある場合は診断タイプ別の補足スコアを表示すること" do
      sign_in singing_customer
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        result_payload: {
          "specific" => {
            "volume_score" => 78,
            "pronunciation_score" => 72,
            "relax_score" => 68,
            "mix_voice_score" => 70
          }
        }
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ボーカル詳細スコア")
      expect(response.body).to include("声量")
      expect(response.body).to include("発音")
      expect(response.body).to include("リラックス")
      expect(response.body).to include("ミックスボイス")
    end

    it "guitarのspecificスコアがある場合はギター詳細スコアを表示すること" do
      sign_in singing_customer
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        performance_type: :guitar,
        result_payload: {
          "performance_type" => "guitar",
          "specific" => {
            "attack_score" => 74,
            "muting_score" => 68,
            "stability_score" => 72
          }
        }
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ギター詳細スコア")
      expect(response.body).to include("アタック")
      expect(response.body).to include("ミュート")
      expect(response.body).to include("安定感")
      expect(response.body).to include("ギター演奏ならではの補足スコア")
      expect(response.body).to include('data-singing-diagnosis-radar')
      expect(response.body).to include("ギター演奏の特徴バランス")
      expect(response.body).not_to include("ミックスボイスチェック項目")
      expect(response.body).not_to include("取り入れると良い歌声タイプ")
    end

    it "bassのspecificスコアがある場合はベース詳細スコアを表示すること" do
      sign_in singing_customer
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        performance_type: :bass,
        result_payload: {
          "performance_type" => "bass",
          "specific" => {
            "groove_score" => 78,
            "note_length_score" => 69,
            "stability_score" => 74
          }
        }
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ベース詳細スコア")
      expect(response.body).to include("グルーヴ")
      expect(response.body).to include("音価")
      expect(response.body).to include("安定感")
      expect(response.body).to include("ベース演奏ならではの補足スコア")
      expect(response.body).to include('data-singing-diagnosis-radar')
      expect(response.body).to include("ベース演奏の特徴バランス")
      expect(response.body).not_to include("ミックスボイスチェック項目")
      expect(response.body).not_to include("取り入れると良い歌声タイプ")
    end

    it "drumsのspecificスコアがある場合はドラム詳細スコアを表示すること" do
      sign_in singing_customer
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        performance_type: :drums,
        result_payload: {
          "performance_type" => "drums",
          "specific" => {
            "tempo_stability_score" => 76,
            "rhythm_precision_score" => 71,
            "dynamics_score" => 68,
            "fill_control_score" => 73
          }
        }
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ドラム詳細スコア")
      expect(response.body).to include("テンポ安定")
      expect(response.body).to include("リズム精度")
      expect(response.body).to include("ダイナミクス")
      expect(response.body).to include("フィル")
      expect(response.body).to include("ドラム演奏ならではの補足スコア")
      expect(response.body).to include("Core以上のプランを見る")
      expect(response.body).not_to include("テンポ安定の読み解き")
      expect(response.body).to include('data-singing-diagnosis-radar')
      expect(response.body).to include("ドラム演奏の特徴バランス")
      expect(response.body).not_to include("ミックスボイスチェック項目")
      expect(response.body).not_to include("取り入れると良い歌声タイプ")
    end

    it "keyboardのspecificスコアがある場合はキーボード詳細スコアを表示すること" do
      sign_in singing_customer
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        performance_type: :keyboard,
        result_payload: {
          "performance_type" => "keyboard",
          "specific" => {
            "chord_stability_score" => 77,
            "note_connection_score" => 65,
            "touch_score" => 69,
            "harmony_score" => 74
          }
        }
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("キーボード詳細スコア")
      expect(response.body).to include("コード安定")
      expect(response.body).to include("音のつながり")
      expect(response.body).to include("タッチ")
      expect(response.body).to include("ハーモニー")
      expect(response.body).to include("キーボード演奏ならではの補足スコア")
      expect(response.body).to include('data-singing-diagnosis-radar')
      expect(response.body).to include("キーボード演奏の特徴バランス")
      expect(response.body).to include("おすすめ練習メニュー")
      expect(response.body).to include("打鍵の粒そろえ練習")
      expect(response.body).to include("フレーズ接続練習")
      expect(response.body).to include("Core以上のプランを見る")
      expect(response.body).not_to include("ミックスボイスチェック項目")
      expect(response.body).not_to include("取り入れると良い歌声タイプ")
      expect(response.body).not_to include("ピッキング")
      expect(response.body).not_to include("ミュート")
      expect(response.body).not_to include("フィル")
    end

    it "keyboardのspecificが不足している場合も共通3軸でレーダーチャートを表示すること" do
      sign_in singing_customer
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        performance_type: :keyboard,
        pitch_score: 81,
        rhythm_score: 73,
        expression_score: 77,
        result_payload: {}
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-singing-diagnosis-radar')
      expect(response.body).to include("キーボード演奏の特徴バランス")
      expect(response.body).not_to include("コード安定の読み解き")
    end

    it "bassのspecificが不足している場合も共通3軸でレーダーチャートを表示すること" do
      sign_in singing_customer
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        performance_type: :bass,
        result_payload: {}
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-singing-diagnosis-radar')
      expect(response.body).to include("ベース演奏の特徴バランス")
    end

    it "guitarのspecificが不足している場合も共通3軸でレーダーチャートを表示すること" do
      sign_in singing_customer
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        performance_type: :guitar,
        result_payload: {}
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-singing-diagnosis-radar')
      expect(response.body).to include("ギター演奏の特徴バランス")
    end

    it "bandでquality_messageがある場合は注意メッセージを表示すること" do
      sign_in singing_customer
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        performance_type: :band,
        result_payload: {
          "specific" => {
            "balance" => 72,
            "tightness" => 68,
            "groove" => 66,
            "role_clarity" => 70,
            "dynamics" => 64,
            "cohesion" => 67
          },
          "quality_message" => "今回の音源は少し短めのため、診断結果は参考値としてご覧ください。次回は30秒以上の演奏を録音すると、より安定した診断ができます。"
        }
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("診断精度に関するお知らせ")
      expect(response.body).to include("今回の音源は少し短めのため、診断結果は参考値としてご覧ください。")
    end

    it "bandでlow_confidenceがtrueの場合は補完の注意メッセージを表示すること" do
      sign_in singing_customer
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        performance_type: :band,
        result_payload: {
          "specific" => {
            "balance" => 60,
            "tightness" => 58,
            "groove" => 55,
            "role_clarity" => 62,
            "dynamics" => 57,
            "cohesion" => 59
          },
          "quality_flags" => {
            "low_confidence" => true,
            "too_short" => true,
            "mostly_silent" => true
          }
        }
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("診断精度に関するお知らせ")
      expect(response.body).to include("診断結果は参考値としてご覧ください")
      expect(response.body).to include("30秒以上の演奏")
    end

    it "bandでquality_flagsがnilでも画面が落ちないこと" do
      sign_in singing_customer
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        performance_type: :band,
        result_payload: {
          "specific" => {
            "balance" => 72,
            "tightness" => 68,
            "groove" => 66,
            "role_clarity" => 70,
            "dynamics" => 64,
            "cohesion" => 67
          },
          "quality_flags" => nil
        }
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("アンサンブル診断")
      expect(response.body).not_to include("診断精度に関するお知らせ")
    end

    it "premiumユーザーのband診断にはband向け週間アドバイスを表示すること" do
      singing_customer.create_subscription!(status: "active", plan: "premium")
      sign_in singing_customer
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        performance_type: :band,
        result_payload: {
          "specific" => {
            "balance" => 52,
            "tightness" => 68,
            "groove" => 65,
            "role_clarity" => 70,
            "dynamics" => 66,
            "cohesion" => 69
          }
        }
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Premium限定：今週の練習テーマ")
      expect(response.body).to include("今週の練習ゴール")
      expect(response.body).to include("スタジオ練習でやること")
      expect(response.body).to include("録音して確認するポイント")
      expect(response.body).to include("次回までの宿題")
      expect(response.body).to include("ボーカルが聴こえる音量バランスを作る週")
    end

    it "band以外にはquality_messageがあっても注意メッセージを表示しないこと" do
      sign_in singing_customer
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        performance_type: :vocal,
        result_payload: {
          "specific" => {
            "volume_score" => 72
          },
          "quality_message" => "参考値としてご覧ください。"
        }
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("診断精度に関するお知らせ")
    end

    it "premium以外のguitar診断ではタイプ別詳細診断をロック表示にすること" do
      sign_in singing_customer
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        performance_type: :guitar,
        result_payload: {}
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Premium タイプ別詳細診断")
      expect(response.body).to include("発音・ミュート・安定感")
      expect(response.body).to include("Premiumプランを見る")
      expect(response.body).not_to include("ギター タイプ別詳細診断")
    end

    it "specificスコアがない場合は補足スコアを表示しないこと" do
      sign_in singing_customer
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :completed, result_payload: {})

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("ボーカル詳細スコア")
    end

    it "comparison featureがある場合はspecificスコアの前回比を表示すること" do
      singing_customer.create_subscription!(status: "active", plan: "light")
      sign_in singing_customer
      FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        result_payload: {
          "specific" => {
            "volume_score" => 70,
            "pronunciation_score" => 80
          }
        },
        created_at: 1.day.ago
      )
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        result_payload: {
          "specific" => {
            "volume_score" => 73,
            "pronunciation_score" => 78
          }
        },
        created_at: Time.current
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ボーカル詳細スコアの前回比")
      expect(response.body).to include("声量")
      expect(response.body).to include("+3")
      expect(response.body).to include("発音")
      expect(response.body).to include("-2")
    end

    it "specificの共通keyがない場合はspecificスコアの前回比を表示しないこと" do
      singing_customer.create_subscription!(status: "active", plan: "light")
      sign_in singing_customer
      FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        result_payload: { "specific" => { "volume_score" => 70 } },
        created_at: 1.day.ago
      )
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        result_payload: { "specific" => { "mix_voice_score" => 73 } },
        created_at: Time.current
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("ボーカル詳細スコアの前回比")
    end

    it "未完了の診断はレーダーチャート表示対象にならないこと" do
      sign_in singing_customer
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :queued)

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('data-singing-diagnosis-radar')
    end

    it "featureがないfreeユーザーには比較セクションを表示しないこと" do
      sign_in singing_customer
      FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :completed, overall_score: 70, created_at: 1.day.ago)
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :completed, overall_score: 75, created_at: Time.current)

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("前回診断との比較")
    end

    it "featureがあるlightユーザーには比較差分を表示すること" do
      singing_customer.create_subscription!(status: "active", plan: "light")
      sign_in singing_customer
      FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        overall_score: 70,
        pitch_score: 65,
        rhythm_score: 80,
        expression_score: 75,
        created_at: 1.day.ago
      )
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        overall_score: 73,
        pitch_score: 63,
        rhythm_score: 80,
        expression_score: 82,
        created_at: Time.current
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("前回診断との比較")
      expect(response.body).to include("+3")
      expect(response.body).to include("-2")
      expect(response.body).to include("±0")
    end

    it "featureがあるが比較対象がない場合は空状態を表示すること" do
      singing_customer.create_subscription!(status: "active", plan: "light")
      sign_in singing_customer
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :completed)

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("比較できる前回診断がまだありません")
    end

    it "freeユーザーには詳細フィードバック本文を表示せず導線を表示すること" do
      sign_in singing_customer
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :completed)

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("詳しく振り返りたい方へ")
      expect(response.body).to include("Core以上のプランを見る")
      expect(response.body).not_to include("音程の読み解き")
    end

    it "lightユーザーには詳細フィードバック本文を表示せず導線を表示すること" do
      singing_customer.create_subscription!(status: "active", plan: "light")
      sign_in singing_customer
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :completed)

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Core以上のプランを見る")
      expect(response.body).not_to include("音程の読み解き")
    end

    it "coreユーザーには詳細フィードバック本文を表示すること" do
      singing_customer.create_subscription!(status: "active", plan: "core")
      sign_in singing_customer
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        pitch_score: 82,
        rhythm_score: 70,
        expression_score: 55
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("詳しく振り返る")
      expect(response.body).to include("音程の読み解き")
      expect(response.body).to include("リズムの読み解き")
      expect(response.body).to include("表現の読み解き")
      expect(response.body).not_to include("Core以上のプランを見る")
    end

    it "coreユーザーのguitar診断にはguitar詳細フィードバック本文を表示すること" do
      singing_customer.create_subscription!(status: "active", plan: "core")
      sign_in singing_customer
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        performance_type: :guitar,
        overall_score: 76,
        result_payload: {
          "specific" => {
            "attack_score" => 84,
            "muting_score" => 68,
            "stability_score" => 45
          }
        }
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("詳しく振り返る")
      expect(response.body).to include("アタックの読み解き")
      expect(response.body).to include("ミュートの読み解き")
      expect(response.body).to include("安定感の読み解き")
      expect(response.body).to include("全体のまとまり")
      expect(response.body).to include("音の立ち上がりがはっきり")
      expect(response.body).not_to include("音程の読み解き")
      expect(response.body).not_to include("Core以上のプランを見る")
    end

    it "freeユーザーのguitar診断にはguitar詳細フィードバック本文を表示せず導線を表示すること" do
      sign_in singing_customer
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        performance_type: :guitar,
        result_payload: {
          "specific" => {
            "attack_score" => 84,
            "muting_score" => 68,
            "stability_score" => 45
          }
        }
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("詳しく振り返りたい方へ")
      expect(response.body).to include("Core以上のプランを見る")
      expect(response.body).not_to include("アタックの読み解き")
    end

    it "coreユーザーのbass診断にはbass詳細フィードバック本文を表示すること" do
      singing_customer.create_subscription!(status: "active", plan: "core")
      sign_in singing_customer
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        performance_type: :bass,
        overall_score: 76,
        result_payload: {
          "specific" => {
            "groove_score" => 84,
            "note_length_score" => 68,
            "stability_score" => 45
          }
        }
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("詳しく振り返る")
      expect(response.body).to include("グルーヴの読み解き")
      expect(response.body).to include("音価の読み解き")
      expect(response.body).to include("安定感の読み解き")
      expect(response.body).to include("全体のまとまり")
      expect(response.body).to include("気持ちよく前へ進む流れ")
      expect(response.body).not_to include("音程の読み解き")
      expect(response.body).not_to include("アタックの読み解き")
      expect(response.body).not_to include("Core以上のプランを見る")
    end

    it "freeユーザーのbass診断にはbass詳細フィードバック本文を表示せず導線を表示すること" do
      sign_in singing_customer
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        performance_type: :bass,
        result_payload: {
          "specific" => {
            "groove_score" => 84,
            "note_length_score" => 68,
            "stability_score" => 45
          }
        }
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("詳しく振り返りたい方へ")
      expect(response.body).to include("Core以上のプランを見る")
      expect(response.body).not_to include("グルーヴの読み解き")
    end

    it "coreユーザーのdrums診断にはdrums詳細フィードバック本文を表示すること" do
      singing_customer.create_subscription!(status: "active", plan: "core")
      sign_in singing_customer
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        performance_type: :drums,
        overall_score: 76,
        result_payload: {
          "specific" => {
            "tempo_stability_score" => 84,
            "rhythm_precision_score" => 68,
            "dynamics_score" => 45,
            "fill_control_score" => 73
          }
        }
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("詳しく振り返る")
      expect(response.body).to include("テンポ安定の読み解き")
      expect(response.body).to include("リズム精度の読み解き")
      expect(response.body).to include("ダイナミクスの読み解き")
      expect(response.body).to include("フィルコントロールの読み解き")
      expect(response.body).to include("全体のまとまり")
      expect(response.body).to include("ビートの土台が安定")
      expect(response.body).not_to include("音程の読み解き")
      expect(response.body).not_to include("アタックの読み解き")
      expect(response.body).not_to include("グルーヴの読み解き")
      expect(response.body).not_to include("Core以上のプランを見る")
    end

    it "freeユーザーのdrums診断にはdrums詳細フィードバック本文を表示せず導線を表示すること" do
      sign_in singing_customer
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        performance_type: :drums,
        result_payload: {
          "specific" => {
            "tempo_stability_score" => 84,
            "rhythm_precision_score" => 68,
            "dynamics_score" => 45,
            "fill_control_score" => 73
          }
        }
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("詳しく振り返りたい方へ")
      expect(response.body).to include("Core以上のプランを見る")
      expect(response.body).not_to include("テンポ安定の読み解き")
    end

    it "coreユーザーのkeyboard診断にはkeyboard詳細フィードバック本文を表示すること" do
      singing_customer.create_subscription!(status: "active", plan: "core")
      sign_in singing_customer
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        performance_type: :keyboard,
        overall_score: 76,
        result_payload: {
          "specific" => {
            "chord_stability_score" => 84,
            "note_connection_score" => 68,
            "touch_score" => 45,
            "harmony_score" => 73
          }
        }
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("詳しく振り返る")
      expect(response.body).to include("和音の安定の読み解き")
      expect(response.body).to include("音のつながりの読み解き")
      expect(response.body).to include("タッチの読み解き")
      expect(response.body).to include("ハーモニーの読み解き")
      expect(response.body).to include("全体のまとまり")
      expect(response.body).to include("和音のまとまり")
      expect(response.body).not_to include("音程の読み解き")
      expect(response.body).not_to include("アタックの読み解き")
      expect(response.body).not_to include("グルーヴの読み解き")
      expect(response.body).not_to include("テンポ安定の読み解き")
      expect(response.body).not_to include("Core以上のプランを見る")
    end

    it "freeユーザーのkeyboard診断にはkeyboard詳細フィードバック本文を表示せず導線を表示すること" do
      sign_in singing_customer
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        performance_type: :keyboard,
        result_payload: {
          "specific" => {
            "chord_stability_score" => 84,
            "note_connection_score" => 68,
            "touch_score" => 45,
            "harmony_score" => 73
          }
        }
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("詳しく振り返りたい方へ")
      expect(response.body).to include("Core以上のプランを見る")
      expect(response.body).not_to include("和音の安定の読み解き")
    end

    it "未完了の診断には詳細フィードバックを表示しないこと" do
      singing_customer.create_subscription!(status: "active", plan: "core")
      sign_in singing_customer
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: singing_customer, status: :processing)

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("詳しく振り返る")
      expect(response.body).not_to include("音程の読み解き")
    end

    it "premiumユーザーには生成済みAIコメントを表示すること" do
      singing_customer.create_subscription!(status: "active", plan: "premium")
      sign_in singing_customer
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        ai_comment_status: :ai_comment_completed,
        ai_comment: "次は語尾を丁寧に整えてみましょう。",
        ai_commented_at: Time.current
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("AIコメント")
      expect(response.body).to include("次は語尾を丁寧に整えてみましょう")
    end

    it "AIコメント生成失敗時も診断結果表示を維持すること" do
      singing_customer.create_subscription!(status: "active", plan: "premium")
      sign_in singing_customer
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: singing_customer,
        status: :completed,
        ai_comment_status: :ai_comment_failed,
        ai_comment_failure_reason: "StandardError: boom"
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("総合スコア")
      expect(response.body).to include("AIコメントの生成に失敗しました")
    end

    it "最新 closed シーズンのバッジを「今回のあなたの実績」に表示すること" do
      sign_in singing_customer
      closed_season = FactoryBot.create(
        :singing_ranking_season,
        name: "2026年4月シーズン",
        status: "closed",
        starts_on: Date.new(2026, 4, 1),
        ends_on: Date.new(2026, 4, 30)
      )
      FactoryBot.create(
        :singing_badge,
        customer: singing_customer,
        singing_ranking_season: closed_season,
        badge_type: "season_1st",
        awarded_at: 3.days.ago
      )
      diagnosis = FactoryBot.create(
        :singing_diagnosis, :completed, :ranking_participant,
        customer: singing_customer, overall_score: 90
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("今回のあなたの実績")
      expect(response.body).to include("今月の王者")
      expect(response.body).to include("🥇")
      expect(response.body).to include("2026年4月シーズン")
      expect(response.body).to include("NEW")
    end

    it "7日以内に獲得したバッジがある場合はバッジ獲得祝福カードを表示すること" do
      sign_in singing_customer
      closed_season = FactoryBot.create(
        :singing_ranking_season,
        name: "2026年4月シーズン",
        status: "closed",
        starts_on: Date.new(2026, 4, 1),
        ends_on: Date.new(2026, 4, 30)
      )
      FactoryBot.create(
        :singing_badge,
        customer: singing_customer,
        singing_ranking_season: closed_season,
        badge_type: "season_1st",
        awarded_at: 3.days.ago
      )
      diagnosis = FactoryBot.create(
        :singing_diagnosis, :completed, :ranking_participant,
        customer: singing_customer, overall_score: 90
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("新しいバッジを獲得しました！")
      expect(response.body).to include("バッジ一覧を見る")
      expect(response.body).to include("シーズン履歴を見る")
      expect(response.body).to include("もう一度診断する")
    end

    it "7日より前に獲得したバッジのみの場合はバッジ獲得祝福カードを表示しないこと" do
      sign_in singing_customer
      closed_season = FactoryBot.create(
        :singing_ranking_season,
        name: "2026年4月シーズン",
        status: "closed",
        starts_on: Date.new(2026, 4, 1),
        ends_on: Date.new(2026, 4, 30)
      )
      FactoryBot.create(
        :singing_badge,
        customer: singing_customer,
        singing_ranking_season: closed_season,
        badge_type: "season_1st",
        awarded_at: 8.days.ago
      )
      diagnosis = FactoryBot.create(
        :singing_diagnosis, :completed, :ranking_participant,
        customer: singing_customer, overall_score: 90
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("新しいバッジを獲得しました！")
    end

    it "バッジがない場合は「今回のあなたの実績」セクションを表示しないこと" do
      sign_in singing_customer
      diagnosis = FactoryBot.create(
        :singing_diagnosis, :completed, :ranking_participant,
        customer: singing_customer, overall_score: 80
      )

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("今回のあなたの実績")
    end
  end
end
