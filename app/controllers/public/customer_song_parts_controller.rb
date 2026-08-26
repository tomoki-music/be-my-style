class Public::CustomerSongPartsController < ApplicationController
  before_action :authenticate_customer!

  # 自己申告の演奏可能曲(曲+パート)を登録する。常にcurrent_customer自身に対してのみ
  # 作成し、customer_id/song_master_idはパラメータから受け取らない(mass assignment対策)。
  def create
    song = current_customer.eligible_songs_for_song_part.find_by(id: customer_song_part_params[:song_id])
    if song.blank?
      return redirect_to edit_public_customer_path(current_customer), alert: "指定された曲が見つからないか、登録する権限がありません。"
    end

    song_master = song.song_master || SongMasters::Resolver.call(song_name: song.song_name, artist_name: song.artist_name)
    if song_master.blank?
      return redirect_to edit_public_customer_path(current_customer), alert: "指定された曲を登録できませんでした。"
    end

    customer_song_part = current_customer.customer_song_parts.new(
      song: song,
      song_master: song_master,
      part_name: customer_song_part_params[:part_name]
    )

    if customer_song_part.save
      redirect_to edit_public_customer_path(current_customer), notice: "演奏可能曲を登録しました。"
    else
      redirect_to edit_public_customer_path(current_customer), alert: customer_song_part.errors.full_messages.to_sentence
    end
  end

  # 自分の自己申告データのみ削除できる(他人のデータはscope外のため404になる)。
  def destroy
    customer_song_part = current_customer.customer_song_parts.find(params[:id])
    customer_song_part.destroy
    redirect_to edit_public_customer_path(current_customer), notice: "演奏可能曲を削除しました。"
  rescue ActiveRecord::RecordNotFound
    redirect_to edit_public_customer_path(current_customer), alert: "対象のデータが見つかりませんでした。"
  end

  private

  # customer_id/song_master_idはパラメータから受け取らない(mass assignment対策)。
  # song_idはeligible_songs_for_song_part(所属コミュニティのイベントに紐づくSongのみ)で
  # サーバー側から絞り込んだうえで参照するため、ここではpermitするだけで良い。
  def customer_song_part_params
    params.fetch(:customer_song_part, {}).permit(:song_id, :part_name)
  end
end
