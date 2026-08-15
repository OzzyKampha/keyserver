# syntax=docker/dockerfile:1

# Caddy modules are compiled in, so the WAF needs a custom binary rather than
# the stock caddy image. The build needs network access to proxy.golang.org.
#
# caddy-waf requires Go 1.25.1 or newer. If the builder image ships an older
# toolchain, Go downloads a matching one itself (GOTOOLCHAIN defaults to auto),
# which needs the same network access.

ARG CADDY_VERSION=2

FROM caddy:${CADDY_VERSION}-builder-alpine AS builder

RUN xcaddy build \
    --with github.com/fabriziosalmi/caddy-waf@v0.3.10

FROM caddy:${CADDY_VERSION}-alpine

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
