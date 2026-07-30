class Admin::CustomersController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_customer, only: [:approval, :purge, :edit, :update]
  before_action :set_member_profile, only: [:edit, :update]

  def edit
    @singing_diagnoses = @customer.singing_diagnoses
      .order(created_at: :desc)
      .limit(20)
  end

  def update
    @customer.skip_reconfirmation!

    ActiveRecord::Base.transaction do
      updated = @customer.update_without_password(customer_params.except(:subscription_plan, :owned_community_ids))
      raise ActiveRecord::Rollback unless updated

      @customer.sync_subscription_plan!(customer_params[:subscription_plan])

      sync_managed_communities! if params[:customer][:owned_community_ids]

      redirect_to admin_homes_top_path, notice: "会員情報を更新しました。"
      return
    end

    render :edit
  rescue ActiveRecord::RecordInvalid
    render :edit
  end

  def approval
    if @customer.update(confirmed_at: Time.current)
      redirect_to admin_homes_top_path, notice: "メール承認の更新が完了しました!"
    else
      render "index"
    end
  end

  def purge
    if @customer.destroy
      redirect_to admin_homes_top_path, alert: "アカウントを完全削除しました!"
    else
      render "index"
    end
  end

  private

  def set_customer
    @customer = Customer.includes(:owned_communities).find(params[:id] || params[:customer_id])
  end

  # 管理画面の「管理コミュニティ」欄は単一のUI(owned_community_ids)だが、
  # 送信先テーブルはis_ownerの値によって切り替える。
  # - community_owner/admin: 既存どおりcommunity_ownersへ保存(既存処理を維持)
  # - manager: community_event_editorsへ保存(公開側と同じCommunityEventEditor.assignable?を利用)
  # - general: どちらにも保存せず、両方の関連を解除する
  def sync_managed_communities!
    requested_ids = params[:customer][:owned_community_ids]

    case @customer.is_owner
    when "community_owner", "admin"
      sync_owned_communities!(requested_ids)
      clear_event_editor_assignments!
    when "manager"
      # CommunityOwnerが残ったままだとCommunityEventEditor.assignable?がfalseになり
      # 同じコミュニティへ切り替えられないため、必ず先にオーナー関連を解除する。
      clear_community_owner_assignments!
      sync_event_editor_communities!(requested_ids)
    else # general
      clear_community_owner_assignments!
      clear_event_editor_assignments!
    end
  end

  # 既存のオーナー更新処理(全置換方式)。ロジックは変更していない。
  def sync_owned_communities!(requested_ids)
    @customer.community_owners.destroy_all
    requested_ids.reject(&:blank?).each do |community_id|
      @customer.community_owners.create!(community_id: community_id)
    end
  end

  def clear_community_owner_assignments!
    @customer.community_owners.destroy_all
  end

  # 送信されたcommunity_idのうち、実在するCommunityかつ、まだオーナー/管理者権限を
  # 持っていない(=CommunityEventEditor.assignable?)ものだけに絞り込んでから保存する。
  # 存在しないIDや既にオーナー等であるIDは、エラーにはせず安全に無視する。
  def sync_event_editor_communities!(requested_ids)
    assignable_ids = assignable_event_editor_community_ids(requested_ids)
    @customer.community_event_editors.where.not(community_id: assignable_ids).destroy_all
    assignable_ids.each do |community_id|
      @customer.community_event_editors.find_or_create_by!(community_id: community_id)
    end
  end

  def clear_event_editor_assignments!
    @customer.community_event_editors.destroy_all
  end

  def assignable_event_editor_community_ids(requested_ids)
    ids = requested_ids.reject(&:blank?).map(&:to_i)
    Community.where(id: ids).select { |community| CommunityEventEditor.assignable?(@customer, community) }.map(&:id)
  end

  def set_member_profile
    @member_profile = @customer.member_profile || @customer.build_member_profile
  end

  def customer_params
    params.require(:customer).permit(
      :name,
      :email,
      :sex,
      :birthday,
      :activity_stance,
      :favorite_artist1,
      :favorite_artist2,
      :favorite_artist3,
      :favorite_artist4,
      :favorite_artist5,
      :introduction,
      :profile_image,
      :prefecture_id,
      :url,
      :confirm_mail,
      :subscription_plan,
      :password,
      :password_confirmation,
      :is_deleted,
      :is_owner,
      owned_community_ids: [],
      community_owners_attributes: [:id, :community_id, :_destroy],

      member_profile_attributes: [
        :id,
        :entry_source,
        :join_reason,
        :want_to_do,
        :music_experience_level,
        :engagement_style,
        :suggested_member_type,
        :contact_preference,
        :admin_memo
      ]
    )
  end

end
