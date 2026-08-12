# ============================================
# Stage 1: Build Flutter Web
# ============================================
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

RUN flutter build web --release

# ============================================
# Stage 2: Serve with Caddy (SSL automático)
# ============================================
FROM caddy:alpine

COPY --from=build /app/build/web /srv

COPY Caddyfile /etc/caddy/Caddyfile

EXPOSE 80 443

CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
