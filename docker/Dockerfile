FROM alpine:3.20.3

COPY app /app

RUN \
  apk add --no-cache \
    cryptsetup \
    device-mapper \
    lvm2 \
    ruby \
    ruby-bundler \
    sqlite \
    && \
  echo 'gem: --no-document' > /etc/gemrc \
    && \
  : "Default irb is broken without rdoc" && \
  gem install rdoc:6.8.1 \
    && \
  : "Install the app's gems" && \
  apk add --no-cache build-base ruby-dev libffi-dev && \
  cd /app && \
  bundle config set --local without test && \
  bundle install \
    && \
  : "Clean up what we can in same layer" && \
  apk del build-base ruby-dev libffi-dev

# Layers above should remain cached, only this one cannot be cached
COPY disk_key* /app/
