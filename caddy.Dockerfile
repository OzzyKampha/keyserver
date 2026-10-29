# syntax=docker/dockerfile:1

# Caddy modules are compiled in, so this needs a custom binary rather than the
# stock caddy image: the OWASP Coraza module, which embeds the OWASP Core Rule
# Set, and the MaxMind geolocation matcher. The result is copied into the
# normal runtime image. The build needs network access to proxy.golang.org.
#
# The geolocation matcher needs a country database at runtime; it is not part
# of the image. See the geo section of the README.

ARG CADDY_VERSION=2

FROM caddy:${CADDY_VERSION}-builder-alpine AS builder

RUN xcaddy build \
    --with github.com/corazawaf/coraza-caddy/v2 \
    --with github.com/porech/caddy-maxmind-geolocation

FROM caddy:${CADDY_VERSION}-alpine

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
