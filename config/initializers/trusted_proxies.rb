# Proxies whose X-Forwarded-For Rails may believe (specs/public-form.md
# "Abuse protection"). In production Apache reaches the container through
# pasta, so the app sees the server's own address; TRUSTED_PROXIES lists
# it (and any other proxy) to make request.remote_ip the visitor's.
proxies = ENV["TRUSTED_PROXIES"].to_s.split(",").map(&:strip).reject(&:empty?)
if proxies.any?
  Rails.application.config.action_dispatch.trusted_proxies =
    ActionDispatch::RemoteIp::TRUSTED_PROXIES + proxies.map { |proxy| IPAddr.new(proxy) }
end
