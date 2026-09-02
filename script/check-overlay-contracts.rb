# frozen_string_literal: true
# Fast overlay checks that do not boot Alaveteli. The full RSpec suite in
# spec/ still needs `RAILS_ENV=test` inside the Alaveteli app.

root = File.expand_path('..', __dir__)
failures = []

def read(root, relative)
  File.read(File.join(root, relative))
end

{
  'lib/views/user/_signup.en.html.erb' => ['recaptcha_tags'],
  'lib/views/user/_signup.sv.html.erb' => ['recaptcha_tags'],
  'lib/views/alaveteli_pro/plans/show.html.erb' => [
    "id: 'js-stripe-subscription-form'",
    'id="card-element"'
  ],
  'lib/views/alaveteli_pro/plans/show.sv.html.erb' => [
    "id: 'js-stripe-subscription-form'",
    'id="card-element"'
  ],
  'lib/views/general/_frontpage_hero.html.erb' => ['homepage-hero'],
  'lib/views/user/sign.html.erb' => ['create-account'],
  'lib/views/public_body/list.html.erb' => ['search-hero']
}.each do |path, needles|
  unless File.exist?(File.join(root, path))
    failures << "#{path} is missing"
    next
  end
  html = read(root, path)
  needles.each do |needle|
    next if html.include?(needle)

    failures << "#{path} is missing #{needle}"
  end
end

%w[
  lib/views/help/about.sv.html.erb
  lib/views/help/about.en.html.erb
].each do |path|
  failures << "#{path} is missing" unless File.exist?(File.join(root, path))
end

if failures.empty?
  puts 'overlay contracts ok'
  exit 0
end

warn failures.join("\n")
exit 1
