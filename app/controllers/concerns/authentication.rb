module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?

    attr_reader :current_access_token
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private

  def authenticated?
    Current.user.present?
  end

  def require_authentication
    authenticate_via_token || resume_session || request_authentication
    check_account_not_deleted if Current.user
  end

  def resume_session
    Current.session ||= find_session_by_cookie
  end

  def find_session_by_cookie
    Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
  end

  def authenticate_via_token
    token = extract_bearer_token
    return false unless token

    access_token = AccessToken.find_by_token(token)
    unless access_token
      track_event("auth.token_failed")
      return false
    end

    access_token.touch_last_used!
    Current.session = nil
    Current.user = access_token.user
    @current_access_token = access_token
    true
  end

  def extract_bearer_token
    auth_header = request.headers["Authorization"]
    return nil unless auth_header&.start_with?("Bearer ")
    auth_header.split(" ", 2).last
  end

  def request_authentication
    if request.format.json?
      render_unauthorized
    elsif !Rails.application.config.multi_tenant && !Account.exists?
      redirect_to new_first_run_path
    else
      session[:return_to_after_authenticating] = request.url
      redirect_to new_session_path
    end
  end

  def after_authentication_url
    return_url = session.delete(:return_to_after_authenticating)

    # If return URL is home or not set, go to workspaces
    if return_url.blank? || return_url == root_url
      workspaces_url
    else
      return_url
    end
  end

  def start_new_session_for(user)
    user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
      Current.session = session
      cookies.signed.permanent[:session_id] = {value: session.id, httponly: true, same_site: :lax}
    end
  end

  def terminate_session
    Current.session.destroy
    cookies.delete(:session_id)
  end

  def check_account_not_deleted
    return unless Current.account&.deleted?

    if request.format.json?
      render_unauthorized
    else
      terminate_session if Current.session
      redirect_to new_session_path, alert: I18n.t("authentication.account_deleted")
    end
  end
end
