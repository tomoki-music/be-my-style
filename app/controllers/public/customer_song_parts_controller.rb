class Public::CustomerSongPartsController < ApplicationController
  before_action :authenticate_customer!

  # 曲名・アーティスト名の自由入力の上限文字数。SongMaster.song_name/artist_nameの
  # DBカラム上限(varchar(255))より十分小さく、フォーム側でも同じ値をmaxlengthに使う。
  MAX_TEXT_LENGTH = 100

  # 自己申告の演奏可能曲(曲+パート)を登録する。常にcurrent_customer自身に対してのみ
  # 作成し、customer_id/song_master_idはパラメータから受け取らない(mass assignment対策)。
  #
  # song_idが指定されていれば既存Song(所属コミュニティのイベント由来)を使う経路、
  # 指定がなければ曲名・アーティスト名の自由入力(イベントに存在しない曲)経路になる。
  def create
    if customer_song_part_params[:song_id].present?
      create_from_existing_song
    else
      create_from_free_input
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

  def create_from_existing_song
    song = current_customer.eligible_songs_for_song_part.find_by(id: customer_song_part_params[:song_id])
    if song.blank?
      return redirect_to edit_public_customer_path(current_customer), alert: "指定された曲が見つからないか、登録する権限がありません。"
    end

    save_customer_song_part(song: song) { resolve_song_master_for(song) }
  end

  # イベントに存在しない曲を、曲名・アーティスト名・パートの自由入力で登録する経路。
  # 正規化キーが完全一致する既存SongMasterがあれば再利用し、なければ新規作成する
  # (SongMasters::Resolverが name/table両方をNFKC正規化キーで一括して行う)。
  def create_from_free_input
    song_name = customer_song_part_params[:song_name].to_s.strip.slice(0, MAX_TEXT_LENGTH)
    artist_name = customer_song_part_params[:artist_name].to_s.strip.slice(0, MAX_TEXT_LENGTH)

    if song_name.blank?
      return redirect_to edit_public_customer_path(current_customer), alert: "曲名を入力してください。"
    end

    # 自由入力経路では対応する既存Song行を持たない(song: nil)。
    save_customer_song_part(song: nil) { SongMasters::Resolver.call(song_name: song_name, artist_name: artist_name) }
  end

  # 既存Songの song_master_id が未解決(移行前データ等)の場合にResolverで解決し、
  # 以降このSongを参照する画面(経験者検索等)のためSong側にも書き戻しておく
  # (SongPerformances::EventSync#resolve_song_masterと同じ考え方)。
  def resolve_song_master_for(song)
    return song.song_master if song.song_master_id.present?

    song_master = SongMasters::Resolver.call(song_name: song.song_name, artist_name: song.artist_name)
    song.update_column(:song_master_id, song_master.id) if song_master.present?
    song_master
  end

  # SongMasterの解決(必要なら新規作成)とCustomerSongPartの作成を1つのtransactionにまとめる。
  # part_nameが不正(候補外)等でCustomerSongPartの保存に失敗した場合、このtransaction内で
  # 新規作成されたSongMaster(・Song側へのsong_master_id書き戻し)もまとめてロールバックし、
  # 参照されない中途半端なSongMasterを残さない。
  #
  # 同時リクエスト(同じ曲・パートの二重送信等)によるUNIQUE制約違反はRecordNotUniqueとして
  # 安全に処理し、「既に登録されています」という分かりやすいメッセージにする
  # (バリデーションのuniqueness checkと実際のINSERTの間の競合はアプリ側だけでは防げないため)。
  def save_customer_song_part(song:)
    customer_song_part = nil
    song_master = nil

    ActiveRecord::Base.transaction do
      song_master = yield
      raise ActiveRecord::Rollback if song_master.blank?

      customer_song_part = current_customer.customer_song_parts.new(
        song: song,
        song_master: song_master,
        part_name: customer_song_part_params[:part_name]
      )
      customer_song_part.save!
    end

    if song_master.blank?
      return redirect_to edit_public_customer_path(current_customer), alert: "指定された曲を登録できませんでした。"
    end

    redirect_to edit_public_customer_path(current_customer), notice: "演奏可能曲を登録しました。"
  rescue ActiveRecord::RecordInvalid
    redirect_to edit_public_customer_path(current_customer), alert: customer_song_part.errors.full_messages.to_sentence
  rescue ActiveRecord::RecordNotUnique
    redirect_to edit_public_customer_path(current_customer), alert: "既にこの曲・パートで演奏可能曲として登録されています。"
  end

  # customer_id/song_master_idはパラメータから受け取らない(mass assignment対策)。
  # song_idはeligible_songs_for_song_part(所属コミュニティのイベントに紐づくSongのみ)で
  # サーバー側から絞り込んだうえで参照するため、ここではpermitするだけで良い。
  # song_name/artist_nameは自由入力経路用(trim・長さ制限はcreate_from_free_input側で行う)。
  def customer_song_part_params
    params.fetch(:customer_song_part, {}).permit(:song_id, :part_name, :song_name, :artist_name)
  end
end
