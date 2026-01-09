#!/bin/sh
set -e

cd /app/alaveteli

# Run only once unless reset
if [ -f /setupstate/setup.done ]; then
  echo "[setup] Already initialized — skipping"
  exit 0
fi

echo "[setup] Installing gems…"
bundle install

THEME="handlingar-theme"
echo "[setup] Activating theme: $THEME"
bundle exec script/switch-theme.rb "$THEME"
bundle exec rake assets:clean
bundle exec rake assets:precompile
bundle exec rake assets:link_non_digest
# bundle exec rake themes:install

echo "[setup] Migrating DB…"
bin/rails db:migrate db:seed

echo "[setup] Loading sample data…"
bundle exec script/load-sample-data

echo "[setup] Removing external requests…"
bin/rails runner 'InfoRequest.external.destroy_all'
echo "[setup] Rebuilding Xapian… (explicit model list)"
bundle exec script/update-xapian-index
# bundle exec script/destroy-and-rebuild-xapian-index

echo "[setup] Marking setup complete"
touch /setupstate/setup.done
