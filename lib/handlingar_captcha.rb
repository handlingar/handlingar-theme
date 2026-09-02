# -*- encoding : utf-8 -*-
require 'json'
require 'net/http'
require 'uri'

# Captcha adapter for the Handlingar theme.
#
# Default is Google reCAPTCHA v2 (Alaveteli's recaptcha_tags / verify_recaptcha).
# Set CAPTCHA_PROVIDER=friendly_captcha to switch the widget and verification
# without changing call sites. Requires FRIENDLY_CAPTCHA_SITE_KEY and
# FRIENDLY_CAPTCHA_SECRET. Optional FRIENDLY_CAPTCHA_EU=1 uses the EU API.
module HandlingarCaptcha
  FIELD = 'frc-captcha-solution'
  GLOBAL_VERIFY_URL = 'https://api.friendlycaptcha.com/api/v1/siteverify'
  EU_VERIFY_URL = 'https://eu-api.friendlycaptcha.eu/api/v1/siteverify'
  WIDGET_JS = 'https://cdn.jsdelivr.net/npm/friendly-challenge@0.9.16/widget.min.js'

  module ViewMethods
    def recaptcha_tags(options = {})
      return super unless HandlingarCaptcha.friendly?

      render partial: 'general/friendly_captcha',
             locals: { nonce: options[:nonce] }
    end
  end

  module ControllerMethods
    def verify_recaptcha(options = {})
      return super unless HandlingarCaptcha.friendly?

      HandlingarCaptcha.verify(request)
    end
  end

  module_function

  def provider
    value = ENV['CAPTCHA_PROVIDER'].to_s.strip.downcase
    value.empty? ? 'recaptcha' : value
  end

  def friendly?
    provider == 'friendly_captcha'
  end

  def site_key
    ENV['FRIENDLY_CAPTCHA_SITE_KEY'].to_s.strip.presence
  end

  def secret
    ENV['FRIENDLY_CAPTCHA_SECRET'].to_s.strip.presence ||
      ENV['FRIENDLY_CAPTCHA_API_KEY'].to_s.strip.presence
  end

  def verify_url
    if ENV['FRIENDLY_CAPTCHA_EU'].to_s == '1'
      EU_VERIFY_URL
    else
      GLOBAL_VERIFY_URL
    end
  end

  def verify(request)
    return false if secret.blank?

    solution = request.params[FIELD].to_s
    return false if solution.blank?

    uri = URI.parse(verify_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = 5
    http.read_timeout = 5

    req = Net::HTTP::Post.new(uri.request_uri)
    req.set_form_data(
      'secret' => secret,
      'solution' => solution,
      'sitekey' => site_key.to_s
    )
    response = http.request(req)
    JSON.parse(response.body)['success'] == true
  rescue StandardError
    false
  end
end
