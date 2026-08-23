class Public::EventsController < ApplicationController
  include CsvModule
  before_action :authenticate_customer!
  before_action :set_event, only: [:show, :edit, :update, :destroy, :copy]
  before_action :authorize_event_creation!, only: [:new, :create]
  before_action :authorize_event_edit!, only: [:edit, :update]
  before_action :authorize_event_destroy!, only: [:destroy]
  before_action :authorize_event_copy!, only: [:copy]
  before_action :set_song_templates, only: [:new, :create, :edit, :update]
  before_action :set_requested_by_customer_candidates, only: [:new, :create, :edit, :update]

  def index
    events = Event.left_joins(:community, songs: { join_parts: :join_part_customers }).distinct

    if params[:keyword].present?
      keyword = "%#{params[:keyword].strip}%"
      events = events.where(
        "events.event_name LIKE :keyword OR events.place LIKE :keyword OR "\
        "events.address LIKE :keyword OR communities.name LIKE :keyword OR songs.song_name LIKE :keyword",
        keyword: keyword
      )
    end

    if params[:community_id].present?
      events = events.where(community_id: params[:community_id])
    end

    events =
      case params[:status]
      when "recruiting"
        events.where("events.event_end_time > ?", Time.current)
              .group("events.id")
              .having("COUNT(DISTINCT join_parts.id) > COUNT(DISTINCT join_part_customers.join_part_id)")
      when "ended"
        events.where("events.event_end_time < ?", Time.current)
      when "upcoming"
        events.where("events.event_end_time > ?", Time.current)
      else
        events
      end

    events =
      case params[:sort]
      when "newest"
        events.order("events.created_at DESC")
      when "start_later"
        events.order("events.event_start_time DESC")
      else
        events.order("events.event_start_time DESC")
      end

    @events = events.page(params[:page]).per(5)
    @available_communities = current_customer.available_communities_for_event
    @search_communities = Community.where(domain_id: @current_domain.id).order(:name)
  end

  def show
    @owner = Customer.find(@event.customer.id)
    @community = Community.find(@event.community_id)
    @request = Request.new

    #参加人数(退会ユーザーは一般・公開画面上は現役参加者として数えない)
    joined_member_ids = []
    @event.songs.each do |song|
      song.join_parts.each do |join_part|
        joined_member_ids += join_part.active_customers.pluck(:id)
      end
    end
    @joined_member_counts = joined_member_ids.uniq.length

    #参加メンバー名
    @join_members = []
    joined_member_ids.uniq.each do |member_id|
      @join_members << Customer.find(member_id)
    end

    #成立楽曲数(退会ユーザーだけのパートは現役参加者0人=募集中として扱う)
    @complete_song_ids = []
    @event.songs.each do |song|
      unless song.join_parts.map{|join_part| join_part.active_customers.length }.include?(0)
        @complete_song_ids << song.id
      end
    end
    @complete_count = @complete_song_ids.length

    #成立楽曲リスト
    @complete_songs = []
    @complete_song_ids.each do |song_id|
      @complete_songs << Song.find(song_id)
    end

    #募集中楽曲数(退会ユーザーだけのパートは現役参加者0人=募集中として扱う)
    @recruiting_song_ids = []
    @event.songs.each do |song|
      if song.join_parts.map{|join_part| join_part.active_customers.length }.include?(0)
        @recruiting_song_ids << song.id
      end
    end
    @recruiting_count = @recruiting_song_ids.length

    #募集中楽曲リスト
    @recruiting_songs = []
    @recruiting_song_ids.each do |song_id|
      @recruiting_songs << Song.find(song_id)
    end

    #googleMap
    @latitude = @event.latitude
    @longitude = @event.longitude
    @address = @event.address

    #CSVダウロード
    @songs = @event.songs
    @current_customer_event_credit_applied = @event.session_credit_applied_for?(current_customer)
    if @current_customer_event_credit_applied
      # このイベント自身にすでに特典が適用済みのため、月次の残枠有無に関わらずDB実績を優先する
      @current_customer_session_credit_available = false
      @current_customer_session_credit_amount = @event.session_credit_amount_for(current_customer)
      @current_customer_remaining_fee = @event.participant_remaining_fee_for(current_customer)
    else
      @current_customer_session_credit_available = current_customer.session_credit_available_for?(event: @event)
      @current_customer_session_credit_amount = current_customer.session_credit_amount_for(@event)
      @current_customer_remaining_fee = [@event.entrance_fee.to_i - @current_customer_session_credit_amount, 0].max
    end
    respond_to do |format|
      format.html
      format.csv do
        generate_csv(@event)
      end
    end
  end

  def new
    @event = Event.new
    @song = @event.songs.build
  
    %w[Vocal Guitar Bass Drums Keyboard].each do |part_name|
      @song.join_parts.build(join_part_name: part_name)
    end
  
    @community_id = params[:community_id]
  end

  def create
    @event = Event.new(event_params)
    @event.customer_id = current_customer.id
    @event.community_id = params[:event][:community_id].to_i
    if @event.save
      if current_customer.communities.present?
        community_ids = current_customer.communities.pluck(:id)
        member_ids = []
        community_ids.each do |community_id|
          Community.where(id: community_id).each do |community|
            member_ids += community.active_customers.pluck(:id)
          end
        end
        member_ids.uniq.each do |member_id|
          if Customer.find(member_id) != current_customer
            Customer.find(member_id).create_notification_event_for_community(current_customer, @event.id)
            if Customer.find(member_id).confirm_mail
              CustomerMailer.with(ac_customer: current_customer, ps_customer: Customer.find(member_id), event_id: @event.id).create_event_mail.deliver_later
            end
          end
        end
      elsif current_customer.followers.present?
        current_customer.followers.active.each do |customer|
          customer.create_notification_event_for_follow(current_customer, @event.id)
        end
      end
      redirect_to public_event_path(@event), notice: "イベントを投稿しました！"
    else
      @community_id = params[:event][:community_id].to_i
      render :new, alert: "登録できませんでした。お手数ですが、入力内容をご確認のうえ再度お試しください"
    end
  end

  def edit
    @community_id = params[:community_id]
    @latitude = @event.latitude
    @longitude = @event.longitude
    @address = @event.address
  end

  def update
    if @event.update(event_params)
      redirect_to public_event_path(@event), notice: "イベントの編集が完了しました!"
    else
      render "edit", alert: "もう一度お試しください。"
    end
  end

  def copy
    @old_event = @event  # set_eventで取得済み
  
    # 🎨 新しいイベントを複製（community_idはオプション）
    @event = @old_event.dup
    @event.community_id = params[:community_id] || @old_event.community_id
    @event.event_name = "#{@old_event.event_name}（コピー）"
    @event.customer_id = current_customer.id # コピー作成者を変更しておく（安全）

    @community_id = @event.community_id
  
    # 🎵 楽曲とパートをコピー
    @old_event.songs.each do |old_song|
      new_song = old_song.dup
      new_song.event = @event
      new_song.requested_by_customer_id = nil unless requested_by_customer_copyable?(old_song)

      # 各曲にデフォルトパートを作成
      ["Vocal", "Guitar", "Bass", "Drums", "Keyboard"].each do |part_name|
        new_song.join_parts.build(join_part_name: part_name)
      end

      @event.songs << new_song
    end
  
    # 🗺️ 地図情報など
    @latitude = @event.latitude
    @longitude = @event.longitude
    @address = @event.address

    # コピー先コミュニティが確定した後で、テンプレート・リクエスト者候補を
    # そのコミュニティ基準に揃え直す。set_song_templates/set_requested_by_customer_candidates は
    # before_action実行時点(コピー元の@eventしかない段階)のままだと、community_id引数付き
    # コピー(別コミュニティ指定)先の候補に対応できないため、ここで明示的に再計算する。
    @template_community = Community.find_by(id: @community_id, domain_id: @current_domain.id)
    @song_templates = @template_community ? @template_community.song_templates.order(:song_name) : SongTemplate.none
    set_requested_by_customer_candidates

    flash.now[:notice] = "イベントをコピーしました！必要に応じて編集してください♪"
    render :new
  end
  
  

  def destroy
    @event.songs.destroy_all
    @event.destroy
    redirect_to public_events_path, alert: "イベントを削除しました!"
  end

  def join_confirm
    @event = Event.find(params[:event_id])
    join_part_ids = valid_join_part_ids_for(@event, params.dig(:event, :join_part_ids))
    if join_part_ids.nil?
      redirect_to public_event_path(@event), alert: "参加したパートにチェックを入れて下さい。"
    else
      @join_part_ids = join_part_ids.map(&:to_s)
      customer = current_customer
      @join_parts = []
      @join_part_ids.each_with_index do |join_part_id, index|
        @join_parts << "【" + JoinPart.find(join_part_id).song.song_name + "】の曲に" + "【" + JoinPart.find(join_part_id).join_part_name + "】で参加！"
      end
      @current_customer_event_credit_applied = @event.session_credit_applied_for?(customer)
      if @current_customer_event_credit_applied
        # 同一イベントへの追加パート登録。既にこのイベントへ特典適用済みなら
        # 月次の残枠有無に関わらず「別イベントで利用済み」ではなくDB実績を表示する
        @session_credit_available = false
        @session_credit_amount = @event.session_credit_amount_for(customer)
        @remaining_fee_after_credit = @event.participant_remaining_fee_for(customer)
      else
        @session_credit_available = current_customer.session_credit_available_for?(event: @event)
        @session_credit_amount = current_customer.session_credit_amount_for(@event)
        @remaining_fee_after_credit = [@event.entrance_fee.to_i - @session_credit_amount, 0].max
      end
    end
  end

  def join
    event = Event.find(params[:event_id])
    community = Community.find(event.community_id)
    customer_ids = community.customers.pluck(:id)
    if customer_ids.include?(current_customer.id)
      join_part_ids_array = valid_join_part_ids_for(event, params[:join_part_ids]&.values)
      if join_part_ids_array.nil?
        redirect_to public_event_path(event), alert: "参加したパートにチェックを入れて下さい。"
        return
      end
      customer = current_customer
      created_join_records = []
      join_part_ids_array.each do |join_part_id|
        unless JoinPart.find(join_part_id).customers.pluck(:id).include?(customer.id)
          join_part = JoinPart.find(join_part_id)
          join_part.customers << customer
          created_join_records << JoinPartCustomer.find_by(customer_id: customer.id, join_part_id: join_part.id)
        end
      end
      apply_session_credit_if_needed!(event, customer, created_join_records.compact)
      #イベント開催者への通知
      if current_customer != event.customer
        event.customer.create_notification_join_event(current_customer, event.id)
        if event.customer.confirm_mail
          CustomerMailer.with(ac_customer: current_customer, ps_customer: event.customer, event_id: event.id).join_event_mail.deliver_later
        end
      end
      #イベント参加者への通知
      customer_ids = []
      event.songs.each do |song|
        song.join_parts.each do |join_part|
          customer_ids += join_part.active_customers.pluck(:id)
        end
      end
      customer_ids.uniq.each do |customer_id|
        if current_customer != Customer.find(customer_id)
          if Customer.find(customer_id).confirm_mail
            CustomerMailer.with(ac_customer: current_customer, ps_customer: Customer.find(customer_id), event_id: event.id).member_join_event_mail.deliver_later
          end
        end
      end
      redirect_to public_event_path(event), notice: "イベントへの参加が完了しました!"
    else
      redirect_to public_community_path(community), alert: "まずこちらのコミュニティに参加してください"
    end
  end

  def delete
    event = Event.find(params[:event_id])
    join_part = JoinPart.find(params[:join_part_id])
    customer = Customer.find(params[:customer_id])
    join_record = JoinPartCustomer.find_by(customer_id: customer.id, join_part_id: join_part.id)
    credited_record = join_record if join_record&.session_credit_applied?
    join_part.customers.delete(customer)
    transfer_session_credit_if_needed!(event, customer, credited_record)
    redirect_to public_event_path(event), alert: "参加を取消しました!"
  end

  # イベントリクエスト欄の@メンション候補API。イベント自体の閲覧(showアクション)に
  # コミュニティメンバー限定等の追加認可が無いのに合わせ、ここもauthenticate_customer!
  # (全アクション共通のbefore_action)のみを要求する。候補の母集団自体は
  # Chat::MentionCandidates.for_eventが「このイベントの現在の参加者」に厳密に絞るため、
  # 他イベントの参加者情報が漏れることはない。
  def mention_candidates
    event = Event.find(params[:id])
    query = params[:q]

    candidates = Chat::MentionCandidates.for_event(event: event, current_customer: current_customer, query: query)
    json = candidates.map { |customer| mention_candidate_json(customer) }
    json.unshift(all_mention_candidate_json) if include_all_candidate?(query)

    render json: json
  rescue StandardError => e
    Rails.logger.error("[EventsController#mention_candidates] #{e.class}: #{e.message}")
    render json: { error: "候補を取得できませんでした" }, status: :unprocessable_entity
  end

  private

  def event_params
    attributes = [
      :event_name,
      :event_start_time,
      :event_end_time,
      :event_entry_deadline,
      :request_deadline,
      :entrance_fee,
      :place,
      :introduction,
      :address,
      :latitude,
      :longitude,
      :event_image,
      :url,
      :url_comment,
    ]
    attributes += [:customer_id, :community_id] if can_reassign_event_ownership?

    params.require(:event).permit(
      *attributes,
      join_part_ids:[],
      part_ids:[],
      songs_attributes: [:id, :event_id, :song_name, :artist_name, :performance_time, :performance_start_time, :youtube_url,
        :chord_sheet_url, :tab_sheet_url, :musical_key, :capo, :chord_sheet_note, :introduction, :position, :_destroy,
        :requested_by_customer_id,
        join_parts_attributes:[:id, :join_part_name, :_destroy]
      ],
    )
  end

  # community_id/customer_idは「イベント編集者には変更させない」項目。
  # createでは@event未設定の時点でこのメソッドが呼ばれ(その後createアクション内で
  # customer_id/community_idを明示的に上書きするため無害)、update/copyでは@event.communityを
  # 基準に、削除権限と同じ範囲(管理者/投稿者本人/コミュニティ管理者)のみ許可する。
  def can_reassign_event_ownership?
    @event.blank? || current_customer.can_destroy_event?(@event)
  end

  def set_event
    # join_parts: :customersをpreloadしておくことで、showビューで使う
    # Song#recruiting_join_parts(customers(preload済みならメモリ上)を見る設計)が
    # 楽曲数・パート数に応じた追加クエリを発生させないようにする。
    @event = Event.includes(songs: [:requested_by_customer, { join_parts: :customers }]).find(params[:id])
  end

  # 送信されたjoin_part_idsが、URL上のeventに属するJoinPartの集合と完全に一致するかを検証する。
  # 1件でも対象イベント外・存在しない・不正な値であれば安全側に倒してnilを返し、
  # 呼び出し元(join_confirm/join)で「1件も処理しない」判断をできるようにする
  # (一部のIDだけを登録すると、確認画面でユーザーが見た内容と実登録内容がずれるため)。
  # join_confirmでの検証結果をjoin側で信用せず、両アクションから毎回このメソッドを呼び
  # 独立して再検証する(確認後にPOSTパラメータが改ざんされるケースに対応するため)。
  def valid_join_part_ids_for(event, raw_ids)
    normalized_ids = normalize_join_part_ids(raw_ids)
    return nil if normalized_ids.empty?

    scoped_ids = event.join_parts.where(id: normalized_ids).pluck(:id)
    return nil unless scoped_ids.sort == normalized_ids.sort

    normalized_ids
  end

  # "12"のような正の整数文字列だけを許可する。空白・空配列・重複・非数値(不正な文字列)が
  # 1件でも混じっていれば空配列を返し、呼び出し元で不正リクエストとして扱わせる。
  def normalize_join_part_ids(raw_ids)
    ids = Array(raw_ids).map { |id| id.to_s.strip }.reject(&:blank?)
    return [] if ids.empty?
    return [] unless ids.all? { |id| id.match?(/\A\d+\z/) }

    ids.map(&:to_i).uniq
  end

  # イベントコピー時、requested_by_customer_idを引き継いでよいかの判定。
  # 「同一コミュニティ内のコピー」かつ「コピー時点でそのコミュニティの有効メンバーである」
  # 場合だけ引き継ぐ。別コミュニティへのコピー、退会・論理削除済みの場合は
  # 無効なリクエスト者を新規Songへ持ち込まないようnilにする。
  def requested_by_customer_copyable?(old_song)
    return false if old_song.requested_by_customer_id.blank?
    return false if @old_event.community_id != @event.community_id

    @event.community.active_customers.exists?(id: old_song.requested_by_customer_id)
  end

  def mention_candidate_json(customer)
    {
      id: customer.id,
      name: customer.name,
      avatar_url: mention_candidate_avatar_url(customer),
      type: "customer"
    }
  end

  def mention_candidate_avatar_url(customer)
    if customer.profile_image.attached?
      rails_blob_path(customer.profile_image, only_path: true)
    else
      helpers.asset_path("no_image.jpg")
    end
  end

  # "ALL"は候補一覧の先頭に固定表示する予約候補(実Customerではない)。
  # customer:数値IDを偽装せず、保存時はcustomer:all(Requests::MentionResolver参照)という
  # 明確に区別できる予約トークンとして扱う。
  def include_all_candidate?(query)
    return true if query.blank?

    "ALL".downcase.include?(query.to_s.strip.downcase)
  end

  def all_mention_candidate_json
    { id: "all", name: "ALL", avatar_url: helpers.asset_path("no_image.jpg"), type: "all" }
  end

  def set_song_templates
    @template_community =
      if @event&.persisted?
        @event.community
      else
        community_id = params[:community_id] || params.dig(:event, :community_id)
        Community.find_by(id: community_id, domain_id: @current_domain.id) if community_id.present?
      end

    @song_templates = @template_community ? @template_community.song_templates.order(:song_name) : SongTemplate.none
  end

  # 「リクエストした人」候補。楽曲行ごとに同じコミュニティメンバー一覧を再取得しないよう、
  # イベント単位で1回だけ用意し(_song_fieldsパーシャルへは@requested_by_customer_candidatesとして
  # 共有)、set_song_templatesが確定させた@template_communityをそのまま利用する。
  # コミュニティが未確定(新規作成画面でcommunity_idがまだ選ばれていない)場合はCustomer.noneとし、
  # 「リクエストした人」欄はView側で選択不可にする。
  def set_requested_by_customer_candidates
    @requested_by_customer_candidates =
      if @template_community
        @template_community.active_customers.distinct.order(:name)
      else
        Customer.none
      end
  end

  def authorize_event_creation!
    community_param_present = params[:community_id].present? || params.dig(:event, :community_id).present?
    community =
      if params[:community_id].present?
        Community.find_by(id: params[:community_id], domain_id: @current_domain.id)
      elsif params.dig(:event, :community_id).present?
        Community.find_by(id: params[:event][:community_id], domain_id: @current_domain.id)
      end

    if community_param_present && community.blank?
      redirect_to public_events_path, alert: "イベントを作成するコミュニティを確認してください。"
    elsif community&.premium_event_creation_required? && !current_customer.premium? && !current_customer.admin? && !current_customer.can_manage_community?(community)
      redirect_to public_community_path(community), alert: premium_event_creation_required_message
    elsif !current_customer.can_create_event?(community)
      redirect_to public_events_path, alert: "イベントを作成する権限がありません。"
    end
  end

  def premium_event_creation_required_message
    "このコミュニティでイベントを作成するにはPremiumプランが必要です。Premiumプランでは、コミュニティ運営・イベント作成・メンバー募集を継続して利用できます。"
  end

  def authorize_event_edit!
    unless current_customer.can_edit_event?(@event)
      redirect_to public_events_path, alert: "このイベントを編集する権限がありません。"
    end
  end

  def authorize_event_destroy!
    unless current_customer.can_destroy_event?(@event)
      redirect_to public_events_path, alert: "このイベントを削除する権限がありません。"
    end
  end

  # copyは新規イベント作成を伴うため、削除権限と同じ範囲(管理者/投稿者本人/コミュニティ管理者)に限定し、
  # 編集のみ許可されたイベント編集者には許可しない。
  def authorize_event_copy!
    unless current_customer.can_destroy_event?(@event)
      redirect_to public_events_path, alert: "このイベントをコピーする権限がありません。"
    end
  end

  def apply_session_credit_if_needed!(event, customer, created_join_records)
    return if created_join_records.blank?

    ActiveRecord::Base.transaction do
      customer.lock!
      next unless customer.session_credit_available_for?(event: event)

      credit_record = created_join_records.first
      credit_record.update!(
        session_credit_applied: true,
        session_credit_amount: customer.session_credit_amount_for(event),
        plan_snapshot: customer.plan
      )
    end
  end

  def transfer_session_credit_if_needed!(event, customer, credited_record)
    return if credited_record.blank?

    remaining_records = event.participation_records_for(customer)
    return if remaining_records.blank?

    remaining_records.first.update!(
      session_credit_applied: true,
      session_credit_amount: credited_record.session_credit_amount,
      plan_snapshot: credited_record.plan_snapshot.presence || customer.plan
    )
  end

end
