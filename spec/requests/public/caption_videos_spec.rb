require "rails_helper"

RSpec.describe "Public::CaptionVideos", type: :request do
  let(:customer) { create(:customer) }
  let(:other_customer) { create(:customer) }

  # CaptionVideoはActive Storageの自動コンテンツ判定(Marcel)による実ファイル形式チェックを
  # 通過する必要があるため、既存specの「画像にContent-Typeだけ詐称する」慣例は使えない
  # (Marcelが実バイトから image/png と判定し、video/mp4 バリデーションで弾かれてしまう)。
  # そのためリポジトリへバイナリfixtureを追加する代わりに、Marcelがvideo/mp4と認識できる
  # 最小限のftypボックスをテスト内でTempfileとして生成する。
  MP4_MAGIC_BYTES = "\x00\x00\x00\x18ftypmp42\x00\x00\x00\x00mp42isom".b
  # QuickTime(MOV)のftypボックス。major brand "qt  " によりMarcelがvideo/quicktimeと判定する。
  MOV_MAGIC_BYTES = "\x00\x00\x00\x14ftypqt  \x00\x00\x02\x00qt  ".b

  def mp4_fixture
    tempfile = Tempfile.new(["caption_video_sample", ".mp4"])
    tempfile.binmode
    tempfile.write(MP4_MAGIC_BYTES)
    tempfile.rewind
    (@mp4_tempfiles ||= []) << tempfile # GCによる早期unlinkを防ぐため参照を保持
    fixture_file_upload(tempfile.path, "video/mp4")
  end

  def mov_fixture
    tempfile = Tempfile.new(["caption_video_sample", ".mov"])
    tempfile.binmode
    tempfile.write(MOV_MAGIC_BYTES)
    tempfile.rewind
    (@mov_tempfiles ||= []) << tempfile
    fixture_file_upload(tempfile.path, "video/quicktime")
  end

  # 実際にはJPEG画像なファイル。拡張子は.mov、宣言されたContent-Typeもvideo/quicktimeに
  # 詐称しているが、JPEGは強いマジックバイト(\xFF\xD8\xFF)を持つためMarcelが実バイトから
  # image/jpegと判定し、宣言されたcontent_type/拡張子を上書きする。これにより
  # 「拡張子とContent-Typeだけを信用しない」設計(content_typeバリデーション)を検証できる。
  # (なお、あいまいなバイト列=強い署名を持たないファイルの場合はMarcelが拡張子/宣言された
  #  content_typeへフォールバックするため検知できない。そのケースの安全網は
  #  CaptionVideos::ExtractAudioJob のffprobe深層検証であり、
  #  spec/jobs/caption_videos/extract_audio_job_spec.rb で担保している)
  JPEG_MAGIC_BYTES = "\xFF\xD8\xFF\xE0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00".b

  def fake_mov_fixture
    tempfile = Tempfile.new(["caption_video_fake", ".mov"])
    tempfile.binmode
    tempfile.write(JPEG_MAGIC_BYTES)
    tempfile.rewind
    (@fake_mov_tempfiles ||= []) << tempfile
    fixture_file_upload(tempfile.path, "video/quicktime")
  end

  describe "未ログイン" do
    it "一覧画面はログイン画面へリダイレクトされること" do
      get public_caption_videos_path
      expect(response).to redirect_to(new_customer_session_path)
    end

    it "作成できないこと" do
      expect do
        post public_caption_videos_path, params: { caption_video: { title: "テスト", source_video: mp4_fixture } }
      end.not_to change(CaptionVideo, :count)
    end
  end

  describe "ログイン済み" do
    before { sign_in customer }

    describe "GET /caption_videos" do
      it "自分のAIテロップ動画一覧を表示できること" do
        create(:caption_video, customer: customer, title: "自分の動画")
        get public_caption_videos_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("自分の動画")
      end

      it "他人の動画は表示されないこと" do
        create(:caption_video, customer: other_customer, title: "他人の動画")
        get public_caption_videos_path
        expect(response.body).not_to include("他人の動画")
      end
    end

    describe "GET /caption_videos/new" do
      it "アップロード画面を表示できること" do
        get new_public_caption_video_path
        expect(response).to have_http_status(:ok)
      end
    end

    describe "POST /caption_videos" do
      it "動画を作成しExtractAudioJobをenqueueすること" do
        allow(CaptionVideos::ExtractAudioJob).to receive(:perform_later)

        expect do
          post public_caption_videos_path, params: { caption_video: { title: "テスト動画", source_video: mp4_fixture } }
        end.to change(CaptionVideo, :count).by(1)

        video = CaptionVideo.last
        expect(video.customer).to eq(customer)
        expect(video.status).to eq("uploaded")
        expect(CaptionVideos::ExtractAudioJob).to have_received(:perform_later).with(video.id)
        expect(response).to redirect_to(public_caption_video_path(video))
      end

      it "titleが空の場合はエラーになり作成されないこと" do
        expect do
          post public_caption_videos_path, params: { caption_video: { title: "", source_video: mp4_fixture } }
        end.not_to change(CaptionVideo, :count)
        expect(response).to have_http_status(:ok)
      end

      it "他のcustomer_idを注入しても自分の所有物として作られること(Strong Parameters)" do
        allow(CaptionVideos::ExtractAudioJob).to receive(:perform_later)

        post public_caption_videos_path, params: {
          caption_video: { title: "テスト", source_video: mp4_fixture, customer_id: other_customer.id }
        }

        expect(CaptionVideo.last.customer).to eq(customer)
      end

      it "MOVファイルでも動画を作成しExtractAudioJobをenqueueすること" do
        allow(CaptionVideos::ExtractAudioJob).to receive(:perform_later)

        expect do
          post public_caption_videos_path, params: { caption_video: { title: "MOVテスト動画", source_video: mov_fixture } }
        end.to change(CaptionVideo, :count).by(1)

        video = CaptionVideo.last
        expect(video.customer).to eq(customer)
        expect(video.status).to eq("uploaded")
        expect(CaptionVideos::ExtractAudioJob).to have_received(:perform_later).with(video.id)
        expect(response).to redirect_to(public_caption_video_path(video))
      end

      it "拡張子・Content-Typeを詐称したファイル(実体はJPEG)は作成されないこと" do
        expect do
          post public_caption_videos_path, params: { caption_video: { title: "偽装テスト", source_video: fake_mov_fixture } }
        end.not_to change(CaptionVideo, :count)
        expect(response).to have_http_status(:ok)
      end
    end

    describe "GET /caption_videos/:id" do
      it "自分の動画を閲覧できること" do
        video = create(:caption_video, customer: customer)
        get public_caption_video_path(video)
        expect(response).to have_http_status(:ok)
      end

      it "他人の動画は閲覧できず一覧へリダイレクトされること(IDOR対策)" do
        video = create(:caption_video, customer: other_customer)
        get public_caption_video_path(video)
        expect(response).to redirect_to(public_caption_videos_path)
      end
    end

    describe "GET /caption_videos/:id/edit_captions" do
      it "ready_for_editならテロップ編集画面を表示できること" do
        video = create(:caption_video, :ready_for_edit, customer: customer)
        create(:video_caption, caption_video: video)
        get edit_captions_public_caption_video_path(video)
        expect(response).to have_http_status(:ok)
      end

      it "uploaded中は編集できず詳細へリダイレクトされること" do
        video = create(:caption_video, customer: customer, status: "uploaded")
        get edit_captions_public_caption_video_path(video)
        expect(response).to redirect_to(public_caption_video_path(video))
      end

      it "他人の動画のテロップ編集画面は開けないこと(IDOR対策)" do
        video = create(:caption_video, :ready_for_edit, customer: other_customer)
        get edit_captions_public_caption_video_path(video)
        expect(response).to redirect_to(public_caption_videos_path)
      end
    end

    describe "PATCH /caption_videos/:id/update_captions" do
      it "既存テロップを更新できること" do
        video = create(:caption_video, :ready_for_edit, customer: customer)
        caption = create(:video_caption, caption_video: video, text: "旧テキスト", display_order: 0)

        patch update_captions_public_caption_video_path(video), params: {
          caption_video: {
            video_captions_attributes: {
              "0" => { id: caption.id, start_time: 0, end_time: 2, text: "新テキスト", caption_type: "normal" }
            }
          }
        }

        expect(response).to redirect_to(edit_captions_public_caption_video_path(video))
        expect(caption.reload.text).to eq("新テキスト")
      end

      it "新しいテロップを追加できること" do
        video = create(:caption_video, :ready_for_edit, customer: customer)

        expect do
          patch update_captions_public_caption_video_path(video), params: {
            caption_video: {
              video_captions_attributes: {
                "0" => { start_time: 0, end_time: 2, text: "追加テロップ", caption_type: "normal" }
              }
            }
          }
        end.to change { video.video_captions.count }.from(0).to(1)
      end

      it "テロップを削除できること" do
        video = create(:caption_video, :ready_for_edit, customer: customer)
        caption = create(:video_caption, caption_video: video)

        expect do
          patch update_captions_public_caption_video_path(video), params: {
            caption_video: {
              video_captions_attributes: {
                "0" => { id: caption.id, _destroy: "1" }
              }
            }
          }
        end.to change { video.video_captions.count }.from(1).to(0)
      end

      it "本文が空の場合は保存されずエラーになること" do
        video = create(:caption_video, :ready_for_edit, customer: customer)
        caption = create(:video_caption, caption_video: video, text: "元のテキスト")

        patch update_captions_public_caption_video_path(video), params: {
          caption_video: {
            video_captions_attributes: {
              "0" => { id: caption.id, start_time: 0, end_time: 2, text: "", caption_type: "normal" }
            }
          }
        }

        expect(response).to have_http_status(:ok)
        expect(caption.reload.text).to eq("元のテキスト")
      end

      it "開始時間が終了時間より後の場合は保存されずエラーになること" do
        video = create(:caption_video, :ready_for_edit, customer: customer)
        caption = create(:video_caption, caption_video: video, start_time: 0.0, end_time: 2.0)

        patch update_captions_public_caption_video_path(video), params: {
          caption_video: {
            video_captions_attributes: {
              "0" => { id: caption.id, start_time: 5, end_time: 1, text: "テスト", caption_type: "normal" }
            }
          }
        }

        expect(response).to have_http_status(:ok)
        expect(caption.reload.start_time.to_f).to eq(0.0)
      end

      it "他人のvideo_captionのidを指定しても更新できないこと(IDOR対策)" do
        video = create(:caption_video, :ready_for_edit, customer: customer)
        other_video = create(:caption_video, :ready_for_edit, customer: other_customer)
        other_caption = create(:video_caption, caption_video: other_video, text: "他人のテロップ")

        expect do
          patch update_captions_public_caption_video_path(video), params: {
            caption_video: {
              video_captions_attributes: {
                "0" => { id: other_caption.id, start_time: 0, end_time: 2, text: "乗っ取り", caption_type: "normal" }
              }
            }
          }
        end.to raise_error(ActiveRecord::RecordNotFound)

        expect(other_caption.reload.text).to eq("他人のテロップ")
      end

      it "他人の動画のテロップは更新できないこと(IDOR対策)" do
        video = create(:caption_video, :ready_for_edit, customer: other_customer)

        patch update_captions_public_caption_video_path(video), params: {
          caption_video: { video_captions_attributes: {} }
        }

        expect(response).to redirect_to(public_caption_videos_path)
      end
    end

    describe "POST /caption_videos/:id/render_video" do
      it "テロップがあれば動画生成をenqueueすること" do
        video = create(:caption_video, :ready_for_edit, customer: customer)
        create(:video_caption, caption_video: video)
        allow(CaptionVideos::RenderJob).to receive(:perform_later)

        post render_video_public_caption_video_path(video)

        expect(CaptionVideos::RenderJob).to have_received(:perform_later).with(video.id)
        expect(response).to redirect_to(public_caption_video_path(video))
      end

      it "テロップが無い場合は生成を依頼できないこと" do
        video = create(:caption_video, :ready_for_edit, customer: customer)
        expect(CaptionVideos::RenderJob).not_to receive(:perform_later)

        post render_video_public_caption_video_path(video)

        expect(response).to redirect_to(edit_captions_public_caption_video_path(video))
      end

      it "他人の動画の生成は依頼できないこと(IDOR対策)" do
        video = create(:caption_video, :ready_for_edit, customer: other_customer)
        create(:video_caption, caption_video: video)
        expect(CaptionVideos::RenderJob).not_to receive(:perform_later)

        post render_video_public_caption_video_path(video)

        expect(response).to redirect_to(public_caption_videos_path)
      end
    end

    describe "DELETE /caption_videos/:id" do
      it "自分の動画を削除できること" do
        video = create(:caption_video, customer: customer)

        expect do
          delete public_caption_video_path(video)
        end.to change(CaptionVideo, :count).by(-1)

        expect(response).to redirect_to(public_caption_videos_path)
      end

      it "他人の動画は削除できないこと(IDOR対策)" do
        video = create(:caption_video, customer: other_customer)

        expect do
          delete public_caption_video_path(video)
        end.not_to change(CaptionVideo, :count)

        expect(response).to redirect_to(public_caption_videos_path)
      end
    end
  end
end
