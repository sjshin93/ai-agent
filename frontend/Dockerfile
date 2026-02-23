# Build Flutter Web and serve with nginx.
#
# This Dockerfile expects a Flutter project in ./frontend
# with pubspec.yaml and the standard Flutter directory structure.
#
# If you already have a Flutter project elsewhere, copy it into ./frontend
# (or adjust docker-compose.yml build context accordingly).

FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app

# Cache deps
COPY frontend/pubspec.* ./
RUN flutter pub get

# Copy sources & build
COPY frontend/ ./
RUN flutter build web --release

FROM nginx:alpine
# Use nginx built-in envsubst on templates to inject LOG_LEVEL.
COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
