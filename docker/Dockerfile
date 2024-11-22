FROM alpine:3.20.3

RUN \
  apk add --no-cache \
    cryptsetup \
    device-mapper \
    lvm2 \
    ruby \
    && \
  gem update irb

COPY app /app
