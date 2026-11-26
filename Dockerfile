FROM debian:bookworm-slim AS build

RUN apt-get update \
 && apt-get install -y --no-install-recommends bash ca-certificates curl git libstdc++6 xz-utils \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
ENV FLUTTER_VERSION=3.47.3 FLUTTER_ROOT=/opt/flutter
ARG SUPABASE_URL
ARG SUPABASE_PUBLISHABLE_KEY

COPY pubspec.yaml pubspec.lock ./
COPY lib/ lib/
COPY web/ web/
COPY assets/ assets/
COPY tools/build_render.sh tools/build_render.sh

RUN bash tools/build_render.sh

FROM nginx:alpine
COPY --from=build /app/build/web/ /usr/share/nginx/html/
COPY tools/nginx-security.conf /etc/nginx/conf.d/security-headers.conf
EXPOSE 80
CMD ["/bin/sh", "-c", "sed -i \"s/listen 80;/listen ${PORT:-80};/\" /etc/nginx/conf.d/default.conf && exec nginx -g 'daemon off;'"]
