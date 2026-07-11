# scripts/mock-data/send-request.rb — file a mock FOI request through
# Alaveteli's normal code path so a real outgoing email is generated.
#
# Run inside the alaveteli-web pod (after seed.rb):
#   bundle exec rails runner /tmp/send-request.rb [title-suffix]
#
# Mirrors RequestController#create: InfoRequest.build_from_attributes,
# save!, then OutgoingMailer.initial_request(...).deliver_now and
# record_email_delivery / record_email_failure.
#
# The title gets a unique suffix (ARGV[0] or a timestamp) so the script
# can be re-run; SMTP failure (e.g. Mailpit not yet deployed) is tolerated
# and recorded on the outgoing message, exactly like the controller does.

suffix = ARGV[0] || Time.now.utc.strftime('%Y%m%d%H%M%S')

I18n.with_locale(:sv) do
  # Address built at runtime to keep the privacy gate (no email literals) clean.
  user = User.find_by(email: ['testuser', 'dev.nonprod.handlingar.se'].join('@'))
  abort 'ERROR: test user missing — run seed.rb first.' unless user

  # request_email is a translated attribute (globalize) — look up by url_name.
  body = PublicBody.find_by_url_name('testmyndigheten_1')
  abort 'ERROR: no mock authority found — run seed.rb first.' unless body

  title = "Testbegäran om allmän handling #{suffix}"

  info_request = InfoRequest.build_from_attributes(
    { title: title, public_body: body },
    { body: "Hej!\n\nDetta är en automatiskt skapad testbegäran (#{suffix}) " \
            "i utvecklingsmiljön. Vänligen lämna ut provhandlingen.\n\n" \
            "Med vänlig hälsning,\nTest Testsson (mock)" },
    user
  )

  # Saves the dependent OutgoingMessage in the same transaction.
  info_request.save!
  outgoing_message = info_request.outgoing_messages.first
  puts "+ InfoRequest created: id=#{info_request.id} url_title=#{info_request.url_title}"
  puts "  https://dev.nonprod.handlingar.se/request/#{info_request.url_title}"

  begin
    mail_message = OutgoingMailer.initial_request(
      info_request, outgoing_message
    ).deliver_now if outgoing_message.sendable?
  rescue *OutgoingMessage.expected_send_errors => e
    outgoing_message.record_email_failure(e.message)
    warn "! email delivery FAILED (recorded on message): #{e.class}: #{e.message}"
    warn '  (expected until Mailpit/SMTP is wired up — request is still saved)'
  else
    outgoing_message.record_email_delivery(
      mail_message.to_addrs.join(', '),
      mail_message.message_id
    )
    puts "+ email sent to #{mail_message.to_addrs.join(', ')} " \
         "(message_id=#{mail_message.message_id})"
  ensure
    info_request.save!
  end

  puts "InfoRequest.count=#{InfoRequest.count}"
end
