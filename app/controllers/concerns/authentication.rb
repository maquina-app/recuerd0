module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?

    attr_reader :current_access_token

    # Bearer tokens reach only the controllers that opt in below. Everything
    # else — profile, password, account, OAuth consent, pins — is browser-only,
    # so a leaked or read-only agent credential cannot manage its owner's
    # credentials or escalate through an HTML action.
    class_attribute :token_authentication_allowed, default: false, instance_predicate: false
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end

    def allow_token_authentication
      self.token_authentication_allowed = true
    end
  end

  private

  def authenticated?
    Current.user.present?
  end

  def redirect_authenticated_user
    resume_session
    redirect_to workspaces_path if authenticated?
  end

  # A presented Bearer header is authoritative: it never falls back to the
  # session cookie. An invalid token, or a valid one aimed at a controller
  # outside the API surface, ends the request with the standard 401 envelope
  # whatever the requested format.
  def require_authentication
    if extract_bearer_token
      return render_unauthorized unless token_authentication_allowed
      return render_unauthorized unless authenticate_via_token
    else
      resume_session || request_authentication
    end

    check_account_not_deleted if Current.user
  end

  def resume_session
    Current.session ||= find_session_by_cookie
  end

  def find_session_by_cookie
    return unless cookies.signed[:session_id]

    session = Session.find_by(id: cookies.signed[:session_id])
    return unless session

    if session.expired?
      session.destroy
      cookies.delete(:session_id)
      return
    end

    session.touch # roll the idle-timeout window forward
    session
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
    if api_request?
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
      cookies.signed.permanent[:session_id] = {value: session.id, httponly: true, same_site: :lax, secure: Rails.env.production?}
    end
  end

  def terminate_session
    Current.session.destroy
    cookies.delete(:session_id)
  end

  def check_account_not_deleted
    return unless Current.account&.deleted?

    if api_request?
      render_unauthorized
    else
      terminate_session if Current.session
      redirect_to new_session_path, alert: I18n.t("authentication.account_deleted")
    end
  end
end
