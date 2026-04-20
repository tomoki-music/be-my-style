class Public::EventsController < ApplicationController
  include CsvModule
  before_action :authenticate_customer!
  before_action :set_event, only: [:show, :edit, :update, :destroy, :copy]
  before_action :authorize_event_creation!, only: [:new, :create]
  before_action :authorize_event_edit!, only: [:edit, :update, :destroy, :copy]

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
        events.order("events.event_start_time ASC")
      end

    @events = events.page(params[:page]).per(5)
    @available_communities = current_customer.available_communities_for_event
    @search_communities = Community.where(domain_id: @current_domain.id).order(:name)
  end

  def show
    @owner = Customer.find(@event.customer.id)
    @community = Community.find(@event.community_id)
    @request = Request.new

    #参加人数
    joined_member_ids = []
    @event.songs.each do |song|
      song.join_parts.each do |join_part|
        joined_member_ids += join_part.customers.pluck(:id)
      end
    end
    @joined_member_counts = joined_member_ids.uniq.length

    #参加メンバー名
    @join_members = []
    joined_member_ids.uniq.each do |member_id|
      @join_members << Customer.find(member_id)
    end

    #成立楽曲数
    @complete_song_ids = []
    @event.songs.each do |song|
      unless song.join_parts.map{|join_part| join_part.customers.length }.include?(0)
        @complete_song_ids << song.id
      end
    end
    @complete_count = @complete_song_ids.length

    #成立楽曲リスト
    @complete_songs = []
    @complete_song_ids.each do |song_id|
      @complete_songs << Song.find(song_id)
    end

    #募集中楽曲数
    @recruiting_song_ids = []
    @event.songs.each do |song|
      if song.join_parts.map{|join_part| join_part.customers.length }.include?(0)
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
    @current_customer_session_credit_available = current_customer.session_credit_available_for?(@event)
    @current_customer_session_credit_amount = current_customer.session_credit_amount_for(@event)
    @current_customer_remaining_fee = [@event.entrance_fee.to_i - @current_customer_session_credit_amount, 0].max
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
            member_ids += community.customers.pluck(:id)
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
        current_customer.followers.each do |customer|
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
    if params[:event][:join_part_ids] == [""] 
      redirect_to public_event_path(event), alert: "参加したパートにチェックを入れて下さい。"
    else
      @join_part_ids = params[:event][:join_part_ids].reject {|i| i == "" }
      customer = current_customer
      @join_parts = []
      @join_part_ids.each_with_index do |join_part_id, index|
        @join_parts << "【" + JoinPart.find(join_part_id).song.song_name + "】の曲に" + "【" + JoinPart.find(join_part_id).join_part_name + "】で参加！"
      end
      @session_credit_available = current_customer.session_credit_available_for?(@event)
      @session_credit_amount = current_customer.session_credit_amount_for(@event)
      @remaining_fee_after_credit = [@event.entrance_fee.to_i - @session_credit_amount, 0].max
    end
  end

  def join
    event = Event.find(params[:event_id])
    community = Community.find(event.community_id)
    customer_ids = community.customers.pluck(:id)
    if customer_ids.include?(current_customer.id)
      join_part_ids = params[:join_part_ids]&.values
      join_part_ids_array = join_part_ids.map{ |i| i.to_i }
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
          customer_ids += join_part.customers.pluck(:id)
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

  private

  def event_params
    params.require(:event).permit(
      :customer_id,
      :community_id,
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
      join_part_ids:[],
      part_ids:[],
      songs_attributes: [:id, :event_id, :song_name, :performance_time, :performance_start_time, :youtube_url, :introduction, :position, :_destroy,
        join_parts_attributes:[:id, :join_part_name, :_destroy]
      ],
    )
  end

  def set_event
    @event = Event.find(params[:id])
  end

  def authorize_event_creation!
    community =
      if params[:community_id].present?
        Community.find_by(id: params[:community_id], domain_id: @current_domain.id)
      elsif params.dig(:event, :community_id).present?
        Community.find_by(id: params[:event][:community_id], domain_id: @current_domain.id)
      end

    unless current_customer.can_create_event?(community)
      redirect_to public_events_path, alert: "イベントを作成する権限がありません。"
    end
  end

  def authorize_event_edit!
    unless current_customer.can_edit_event?(@event)
      redirect_to public_events_path, alert: "このイベントを編集する権限がありません。"
    end
  end

  def apply_session_credit_if_needed!(event, customer, created_join_records)
    return if created_join_records.blank?
    return unless customer.session_credit_available_for?(event)

    credit_record = created_join_records.first
    credit_record.update!(
      session_credit_applied: true,
      session_credit_amount: customer.session_credit_amount_for(event),
      plan_snapshot: customer.plan
    )
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
