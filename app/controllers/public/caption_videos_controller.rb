class Public::CaptionVideosController < ApplicationController
  before_action :authenticate_customer!
  before_action :set_caption_video, only: [:show, :destroy, :edit_captions, :update_captions, :render_video]

  def index
    @caption_videos = current_customer.caption_videos
                                       .with_attached_source_video
                                       .with_attached_rendered_video
                                       .order(created_at: :desc)
                                       .page(params[:page])
                                       .per(10)
  end

  def new
    @caption_video = current_customer.caption_videos.new
  end

  def create
    @caption_video = current_customer.caption_videos.new(caption_video_params)
    @caption_video.status = "uploaded"

    if @caption_video.save
      CaptionVideos::ExtractAudioJob.perform_later(@caption_video.id)
      redirect_to public_caption_video_path(@caption_video),
                  notice: "アップロードしました。処理状況はこちらで確認できます。"
    else
      render :new
    end
  end

  def show
    @polling_required = @caption_video.processing?
  end

  def edit_captions
    unless @caption_video.editable?
      redirect_to public_caption_video_path(@caption_video), alert: "テロップはまだ準備できていません。"
      return
    end

    @video_captions = @caption_video.video_captions.ordered.to_a
    @video_captions << @caption_video.video_captions.build if @video_captions.empty?
  end

  def update_captions
    if @caption_video.update(caption_update_params)
      redirect_to edit_captions_public_caption_video_path(@caption_video), notice: "テロップを保存しました。"
    else
      # 再表示: 保存に失敗した入力内容とエラーをそのまま見せるため、DBへ再クエリしない
      # (in-memoryのassociation targetには送信済みの値とバリデーションエラーが乗っている)。
      @video_captions = @caption_video.video_captions.sort_by(&:display_order)
      @video_captions << @caption_video.video_captions.build if @video_captions.empty?
      render :edit_captions
    end
  end

  def render_video
    unless @caption_video.render_requestable?
      redirect_to edit_captions_public_caption_video_path(@caption_video),
                  alert: "動画を生成する前にテロップを1件以上保存してください。"
      return
    end

    CaptionVideos::RenderJob.perform_later(@caption_video.id)
    redirect_to public_caption_video_path(@caption_video), notice: "動画の生成を開始しました。"
  end

  def destroy
    @caption_video.destroy
    redirect_to public_caption_videos_path, notice: "削除しました。"
  end

  private

  def set_caption_video
    @caption_video = current_customer.caption_videos.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to public_caption_videos_path, alert: "動画が見つかりません。"
  end

  def caption_video_params
    params.require(:caption_video).permit(:title, :source_video)
  end

  def caption_update_params
    permitted = params.require(:caption_video).permit(
      video_captions_attributes: [:id, :start_time, :end_time, :text, :caption_type, :display_order, :_destroy]
    )
    reindex_video_caption_display_order!(permitted)
    permitted
  end

  # display_orderはクライアントの入力欄を持たない(並べ替えUIはMVP対象外)。
  # フォーム送信順(=画面表示順)をそのまま採用し、削除予定を除いて0始まりで振り直す。
  def reindex_video_caption_display_order!(permitted)
    attrs = permitted[:video_captions_attributes]
    return if attrs.blank?

    order = 0
    attrs.each do |_key, caption_attrs|
      next if caption_attrs[:_destroy].to_s == "1"

      caption_attrs[:display_order] = order
      order += 1
    end
  end
end
