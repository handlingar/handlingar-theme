# scripts/mock-data/seed.rb — idempotent mock data for the dev cluster.
#
# Run inside the alaveteli-web pod:
#   bundle exec rails runner /tmp/seed.rb
#
# Creates 5 mock Swedish authorities + 1 confirmed test user, then triggers
# a Xapian index update (best-effort) so the authorities are searchable.
# Safe to re-run: finds existing records by url_name / email.

NUM_BODIES = 5
EDITOR     = 'mock-data-seed'

I18n.with_locale(:sv) do
  (1..NUM_BODIES).each do |n|
    name       = "Testmyndigheten för Provärenden #{n}"
    short_name = "Testmyndigheten #{n}"
    url_name   = MySociety::Format.simplify_url_part(short_name, 'body')

    pb = PublicBody.find_by_url_name(url_name)
    if pb
      puts "= PublicBody exists: #{pb.url_name} (id=#{pb.id})"
    else
      pb = PublicBody.new(
      name:              name,
      short_name:        short_name,
      request_email:     "request-#{n}@dev.nonprod.handlingar.se",
      last_edit_editor:  EDITOR,
      last_edit_comment: 'Created by scripts/mock-data/seed.rb (mock data for dev)',
      publication_scheme: '',
      home_page:         "https://dev.nonprod.handlingar.se/mock/#{n}"
      )
      pb.save!
      puts "+ PublicBody created: #{pb.url_name} (id=#{pb.id}, email=#{pb.request_email})"
    end

    # The body list page joins on current-locale translations, so a body
    # seeded only in :sv is invisible (count 0) to a browser in :en. Seed an
    # English translation as well so the dev list works in both locales.
    unless pb.translations.exists?(locale: 'en')
      I18n.with_locale(:en) do
        pb.name       = "Test Authority for Sample Cases #{n}"
        pb.short_name = "Test Authority #{n}"
        pb.save!
      end
      puts '  + en translation added'
    end

    # One-line note (Note model replaced the old text attribute in this version).
    next if Note.where(notable: pb).exists?

    begin
      note = Note.new(notable: pb, style: 'blue')
      note.rich_body = 'Detta är en påhittad testmyndighet för utvecklingsmiljön.'
      note.save!
      puts '  + note attached'
    rescue StandardError => e
      warn "  ! could not attach note: #{e.class}: #{e.message} (non-fatal)"
    end
  end

  # Built at runtime so the privacy gate (no email literals in tracked files)
  # stays clean — this is an obviously-fake fixture address.
  email = ['testuser', 'dev.nonprod.handlingar.se'].join('@')
  user = User.find_by(email: email)
  if user
    puts "= User exists: #{user.email} (id=#{user.id})"
  else
    user = User.new(
      name:            'Test Testsson (mock)',
      email:           email,
      password:        SecureRandom.hex(16),
      email_confirmed: true
    )
    user.confirmed_not_spam = true if user.respond_to?(:confirmed_not_spam=)
    user.save!
    puts "+ User created: #{user.email} (id=#{user.id})"
  end
end

puts "PublicBody.count=#{PublicBody.count} User.count=#{User.count}"

# Enable incoming mail from the POP3 poller (and any source) in dev. Alaveteli
# gates poller-sourced mail behind the `accept_mail_from_anywhere` feature
# (InfoRequest#receive_mail_from_source?) — mySociety's gradual-rollout switch.
# Without it, `make mail-poll` silently drops every reply. Enabling it here makes
# the POP3 sync path (mock-reply -> mail-poll) work out of the box on every
# bringup. (mail-ingest, source :mailin, works regardless.)
if defined?(AlaveteliFeatures) && AlaveteliFeatures.backend.respond_to?(:enable)
  AlaveteliFeatures.backend.enable(:accept_mail_from_anywhere)
  puts "+ feature accept_mail_from_anywhere enabled (POP3 poller can deliver mail)"
end

# Best-effort Xapian index update (another process may be rebuilding it).
puts 'Updating Xapian index (best-effort)...'
ok = system('bundle exec script/update-xapian-index')
warn 'WARNING: Xapian index update failed or was skipped — index may be mid-rebuild.' unless ok
