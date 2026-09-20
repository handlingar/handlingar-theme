require_relative '../spec_helper'

RSpec.describe 'Handlingar overlay contracts' do
  def overlay(relative_path)
    File.read(File.expand_path("../../lib/views/#{relative_path}", __dir__))
  end

  it 'keeps Google reCAPTCHA tags on Swedish and English signup' do
    %w[user/_signup.en.html.erb user/_signup.sv.html.erb].each do |path|
      expect(overlay(path)).to include('recaptcha_tags'),
                               "#{path} must keep recaptcha_tags"
    end
  end

  it 'keeps the Stripe.js checkout contract on Pro plan templates' do
    %w[
      alaveteli_pro/plans/show.html.erb
      alaveteli_pro/plans/show.sv.html.erb
    ].each do |path|
      html = overlay(path)
      expect(html).to include("id: 'js-stripe-subscription-form'"),
                      "#{path} must keep js-stripe-subscription-form"
      expect(html).to include('id="card-element"'),
                      "#{path} must keep #card-element"
    end
  end

  it 'keeps design-system chrome classes on core overlays' do
    expect(overlay('general/_frontpage_hero.html.erb')).to include('homepage-hero')
    expect(overlay('user/sign.html.erb')).to include('create-account')
    expect(overlay('public_body/list.html.erb')).to include('search-hero')
    expect(File).to exist(File.expand_path('../../lib/views/help/about.sv.html.erb', __dir__))
    expect(File).to exist(File.expand_path('../../lib/views/help/about.en.html.erb', __dir__))
  end
end
