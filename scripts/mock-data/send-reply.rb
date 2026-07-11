# scripts/mock-data/send-reply.rb — simulate an AUTHORITY replying to an FOI
# request, delivered into the mock mail server (Mailpit) over SMTP so the
# platform can then pull it back in over POP3 (lib/alaveteli_mail_poller.rb) —
# exactly the path a real incoming MTA + POP3 mailbox would exercise.
#
# Run inside the alaveteli-web pod (after a request exists):
#   bundle exec rails runner /tmp/send-reply.rb [request-id]
#
# With no arg it answers the most recent InfoRequest. The reply is addressed to
# the request's *incoming* address (info_request.incoming_email, e.g.
# foi+request-<id>-<hash>@localhost) — that magic address is what RequestMailer
# routes on, so the message attaches to the right request regardless of sender.
require 'net/smtp'

ir = ARGV[0] ? InfoRequest.find(ARGV[0]) : InfoRequest.last
abort 'ERROR: no InfoRequest found — run mock-request first.' unless ir

incoming = ir.incoming_email                 # foi+request-<id>-<hash>@localhost
body     = ir.public_body
from     = body.request_email                # the authority's address
msg_id   = "reply-#{ir.id}-#{Time.now.utc.to_i}@dev.nonprod.handlingar.se"

raw = <<~EMAIL
  From: #{body.name} <#{from}>
  To: #{incoming}
  Subject: Re: #{ir.title}
  Date: #{Time.now.utc.rfc2822}
  Message-ID: <#{msg_id}>
  Content-Type: text/plain; charset=UTF-8

  Hej,

  Tack för din begäran. Här kommer myndighetens svar: den begärda
  provhandlingen bifogas nedan och lämnas härmed ut i sin helhet.

  Detta är ett automatiskt genererat testsvar i utvecklingsmiljön.

  Med vänlig hälsning,
  #{body.name}
EMAIL

# Mailpit's SMTP listener (cluster-internal, no auth/TLS) catches everything.
Net::SMTP.start('mailpit', 1025) do |smtp|
  smtp.send_message(raw, from, incoming)
end

puts "+ reply delivered to Mailpit (SMTP)"
puts "  request id=#{ir.id} url_title=#{ir.url_title}"
puts "  From: #{from}"
puts "  To (incoming address): #{incoming}"
puts "  -> next: pull it into Alaveteli over POP3 (make mail-poll)"
