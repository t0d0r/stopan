# Content Security Policy (specs/ui.md). Scripts, styles, images and fonts
# come only from the app itself; forms post only to it; nothing may frame
# it. Turbo inserts a <style> for its progress bar and takes the nonce from
# the csp-nonce meta tag (csp_meta_tag in the layout).
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.script_src :self
    policy.style_src :self
    policy.img_src :self, :data
    policy.font_src :self
    policy.connect_src :self
    policy.object_src :none
    policy.base_uri :self
    policy.form_action :self
    policy.frame_ancestors :none
  end

  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[style-src]
end
