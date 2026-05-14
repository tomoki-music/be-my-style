class Singing::BattlesController < Singing::BaseController
  skip_before_action :authenticate_customer!, only: [:join]
  skip_before_action :ensure_singing_access!, only: [:join]

  before_action :set_battle_by_token, only: [:join, :accept]
  before_action :set_battle, only: [:show]

  def create
    diagnosis = current_customer.singing_diagnoses.completed.find_by(id: params[:diagnosis_id])
    return redirect_to singing_diagnoses_path, alert: "診断が見つかりません。" unless diagnosis

    battle = SingingBattle.create!(
      challenger:           current_customer,
      challenger_diagnosis: diagnosis,
      song_title:           diagnosis.song_title.presence || "無題",
      performance_type:     diagnosis.performance_type
    )

    redirect_to singing_battle_path(battle), notice: "挑戦状を作成しました！リンクを友達に送ろう。"
  end

  def show
    @battle = current_customer.singing_battles_as_challenger.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to singing_diagnoses_path, alert: "バトルが見つかりません。"
  end

  def join
    return redirect_to singing_root_path, alert: "この挑戦状は期限切れです。" if @battle.expired?
    return redirect_to singing_root_path, alert: "このバトルは既に完了しています。" if @battle.completed?
  end

  def accept
    return redirect_to singing_root_path, alert: "この挑戦状は期限切れです。" if @battle.expired?
    return redirect_to singing_root_path, alert: "このバトルは既に完了しています。" if @battle.completed?
    return redirect_to singing_join_battle_path(token: @battle.token), alert: "ログインが必要です。" unless current_customer
    return redirect_to singing_join_battle_path(token: @battle.token), alert: "自分への挑戦状には受けられません。" if current_customer == @battle.challenger

    redirect_to new_singing_diagnosis_path(
      battle_token: @battle.token,
      song_title:   @battle.song_title,
      performance_type: @battle.performance_type
    )
  end

  private

  def set_battle
    @battle = SingingBattle.find(params[:id])
  end

  def set_battle_by_token
    @battle = SingingBattle.find_by!(token: params[:token])
  rescue ActiveRecord::RecordNotFound
    redirect_to singing_root_path, alert: "挑戦状が見つかりません。"
  end
end
