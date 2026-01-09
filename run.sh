#!/bin/sh
set -e

export GEM_HOME="/usr/local/bundle"
export GEM_PATH="/usr/local/bundle"
export PATH="/usr/local/bundle/bin:$PATH"

mkdir -p /rdbg
chmod 777 /rdbg

cd /app/alaveteli

echo "Starting Rails with rdbg…"

#!/bin/sh
set -e

export GEM_HOME="/usr/local/bundle"
export GEM_PATH="/usr/local/bundle"
export PATH="/usr/local/bundle/bin:$PATH"

# Force TCP mode for rdbg
export RUBY_DEBUG_OPEN="tcp://0.0.0.0:12345"
export RUBY_DEBUG_NO_REATTACH=1

cd /app/alaveteli

echo "Starting Rails with rdbg on TCP 0.0.0.0:12345…"

# exec rdbg \
#   --nonstop \
#   -- \
#   /usr/local/bundle/bin/bundle exec rails server -b 0.0.0.0 -p 3000

bundle exec rdbg --open --nonstop --port=12345 --host 0.0.0.0 --command -- rails s -p 3000 -b 0.0.0.0