# Be sure to restart your server when you modify this file.

# Application-wide Content Security Policy.
# See https://guides.rubyonrails.org/security.html#content-security-policy-header
#
# Shipped in REPORT-ONLY mode first: violations are reported (browser console)
# but nothing is blocked, so we can observe real traffic before enforcing.
# Flip `content_security_policy_report_only` to false once the console is clean.
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

  # Generate session nonces for permitted importmap and inline scripts.
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w[script-src]

  # Observe violations without enforcing. Remove once the policy is validated.
  config.content_security_policy_report_only = true
end
