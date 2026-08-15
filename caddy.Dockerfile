# syntax=docker/dockerfile:1

# Caddy modules are compiled in, so the WAF needs a custom binary rather than
# the stock caddy image. This builds Caddy with the OWASP Coraza module, which
# embeds the OWASP Core Rule Set, and copies the result into the normal runtime
# image. The build needs network access to proxy.golang.org.

ARG CADDY_VERSION=2

FROM caddy:${CADDY_VERSION}-builder-alpine AS builder

RUN xcaddy build \
    --with github.com/corazawaf/coraza-caddy/v2

FROM caddy:${CADDY_VERSION}-alpine

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
