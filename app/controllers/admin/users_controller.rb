require_dependency 'user_destroyer'

class Admin::UsersController < Admin::AdminController

  before_filter :fetch_user, only: [:ban, :unban, :refresh_browsers, :revoke_admin, :grant_admin, :revoke_moderation, :grant_moderation, :approve, :activate, :deactivate, :block, :unblock]

  def index
    # Sort order
    if params[:query] == "active"
      @users = User.order("COALESCE(last_seen_at, to_date('1970-01-01', 'YYYY-MM-DD')) DESC, username")
    else
      @users = User.order("created_at DESC, username")
    end

    if ['newuser', 'basic', 'regular', 'leader', 'elder'].include?(params[:query])
      @users = @users.where('trust_level = ?', TrustLevel.levels[params[:query].to_sym])
    end

    @users = @users.where('admin = ?', true)      if params[:query] == 'admins'
    @users = @users.where('moderator = ?', true)  if params[:query] == 'moderators'
    @users = @users.blocked                       if params[:query] == 'blocked'
    @users = @users.where('approved = false')     if params[:query] == 'pending'
    @users = @users.where('username_lower like :filter or email like :filter', filter: "%#{params[:filter]}%") if params[:filter].present?
    @users = @users.take(100)
    render_serialized(@users, AdminUserSerializer)
  end

  def show
    @user = User.where(username_lower: params[:id]).first
    raise Discourse::NotFound.new unless @user
    render_serialized(@user, AdminDetailedUserSerializer, root: false)
  end

  def delete_all_posts
    @user = User.where(id: params[:user_id]).first
    @user.delete_all_posts!(guardian)
    render nothing: true
  end

  def ban
    guardian.ensure_can_ban!(@user)
    @user.banned_till = params[:duration].to_i.days.from_now
    @user.banned_at = DateTime.now
    @user.save!
    # TODO logging
    render nothing: true
  end

  def unban
    guardian.ensure_can_ban!(@user)
    @user.banned_till = nil
    @user.banned_at = nil
    @user.save!
    # TODO logging
    render nothing: true
  end

  def refresh_browsers
    MessageBus.publish "/file-change", ["refresh"], user_ids: [@user.id]
    render nothing: true
  end

  def revoke_admin
    guardian.ensure_can_revoke_admin!(@user)
    @user.revoke_admin!
    render nothing: true
  end

  def grant_admin
    guardian.ensure_can_grant_admin!(@user)
    @user.grant_admin!
    render_serialized(@user, AdminUserSerializer)
  end

  def revoke_moderation
    guardian.ensure_can_revoke_moderation!(@user)
    @user.revoke_moderation!
    render nothing: true
  end

  def grant_moderation
    guardian.ensure_can_grant_moderation!(@user)
    @user.grant_moderation!
    render_serialized(@user, AdminUserSerializer)
  end

  def approve
    guardian.ensure_can_approve!(@user)
    @user.approve(current_user)
    render nothing: true
  end

  def approve_bulk
    User.where(id: params[:users]).each do |u|
      u.approve(current_user) if guardian.can_approve?(u)
    end
    render nothing: true
  end

  def activate
    guardian.ensure_can_activate!(@user)
    @user.activate
    render nothing: true
  end

  def deactivate
    guardian.ensure_can_deactivate!(@user)
    @user.deactivate
    render nothing: true
  end

  def block
    guardian.ensure_can_block_user! @user
    SpamRulesEnforcer.punish! @user
    render nothing: true
  end

  def unblock
    guardian.ensure_can_unblock_user! @user
    SpamRulesEnforcer.clear @user
    render nothing: true
  end

  def destroy
    user = User.where(id: params[:id]).first
    guardian.ensure_can_delete_user!(user)
    if UserDestroyer.new(current_user).destroy(user)
      render json: {deleted: true}
    else
      render json: {deleted: false, user: AdminDetailedUserSerializer.new(user, root: false).as_json}
    end
  end


  private

    def fetch_user
      @user = User.where(id: params[:user_id]).first
    end

end
