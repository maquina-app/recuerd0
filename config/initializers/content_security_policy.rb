# Be sure to restart your server when you modify this file.

# Application-wide Content Security Policy.
# See https://guides.rubyonrails.org/security.html#content-security-policy-header
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src :self, :data
    policy.img_src :self, :https, :data, :blob
    policy.object_src :none
    # Plausible analytics: external script host. Inline init scripts are nonced in the layouts.
    policy.script_src :self, "https://plausible.maquina.app"
    # Tailwind emits inline styles; keep :unsafe_inline for styles until the
    # nonce path is verified, then tighten.
    policy.style_src :self, :unsafe_inline
    # Plausible event beacon (/api/event).
    policy.connect_src :self, "https://plausible.maquina.app"
    policy.base_uri :self
    policy.frame_ancestors :none
  end

  # Per-request nonce for inline scripts. Prefer the session id (stable across a
  # session, so Turbo-cached pages keep matching nonces) but fall back to a random
  # value for anonymous requests with no session — otherwise the nonce would be
  # empty ('nonce-') and every inline script would be refused. csp_meta_tag is in
  # the layouts so Turbo re-applies the nonce across navigations.
  config.content_security_policy_nonce_generator = ->(request) { request.session.id&.to_s.presence || SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end
