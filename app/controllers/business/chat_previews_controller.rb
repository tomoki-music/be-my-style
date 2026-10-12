# Business のタイムライン / プロジェクトチャット入力欄の「プレビュー」。
# 送信後の表示と同じ Chat::MarkdownRenderer(サニタイズ済み HTML)を返す。
class Business::ChatPreviewsController < ApplicationController
  def create
    render json: { html: Chat::MarkdownRenderer.call(params[:content]) }
  rescue StandardError => e
    Rails.logger.error("[Business::ChatPreviews] #{e.class}: #{e.message}")
    render json: { error: "プレビューを表示できませんでした" }, status: :unprocessable_entity
  end
end
