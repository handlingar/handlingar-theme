# bookworm (GCC 12), NOT the newer trixie default: Alaveteli pulls in old C gems
# (statistics2, syck) that don't compile under GCC 14's stricter -Werror defaults.
FROM ruby:3.3-bookworm


# System dependencies
RUN apt-get update && apt-get install -y \
    build-essential git curl nodejs npm libpq-dev imagemagick libmagic-dev postgresql-client \
    && npm install -g corepack \
    && corepack enable \
    && rm -rf /var/lib/apt/lists/*

# Pin Alaveteli to a specific upstream tag for reproducible builds (P1-T4).
# Keep in sync with the top-level ALAVETELI_VERSION file.
ARG ALAVETELI_VERSION=0.46.7.0
RUN git clone --depth=1 --branch ${ALAVETELI_VERSION} \
    https://github.com/mysociety/alaveteli.git /app/alaveteli

WORKDIR /app/alaveteli
RUN git submodule update --init --recursive

# Install dependencies
RUN gem install bundler
RUN echo "gem 'debug', '~> 1.11.0'" >> /app/alaveteli/Gemfile
RUN bundle install
RUN gem install debug

# Install JS dependencies
RUN yarn install

RUN gem install net-pop

COPY database.yml config/database.yml
# COPY storage.yml config/storage.yml

COPY run.sh /run.sh
COPY setup.sh /setup.sh

RUN chmod +x /run.sh
RUN chmod +x /setup.sh

# RUN chown 1000:1000 -R /app

RUN apt-get update && apt-get install -y iproute2
COPY . /app/alaveteli-themes/handlingar-theme

RUN curl -sL https://raw.githubusercontent.com/handlingar/alaveteli/refs/heads/develop/config/general.yml -o /app/alaveteli/config/general-handlingar-theme.yml

RUN ln -s /app/alaveteli/config/storage.yml-example \
          /app/alaveteli/config/storage.yml
          
EXPOSE 3000 12345
# USER 1000

CMD ["bundle", "exec", "rdbg", "--open", "--nonstop", "--port=12345", "--host", "0.0.0.0", "--command", "--", "rails", "s", "-p", "3000", "-b", "0.0.0.0"]