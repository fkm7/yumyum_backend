# Build stage: compile the Dart Frog app to a self-contained executable.
FROM dart:stable AS build

WORKDIR /app

# Resolve dependencies first so this layer is cached until pubspec changes.
COPY pubspec.yaml ./
RUN dart pub get

COPY . .
RUN dart pub get --offline
RUN dart pub global activate dart_frog_cli
RUN dart pub global run dart_frog_cli:dart_frog build
RUN dart compile exe build/bin/server.dart -o build/bin/server

# Runtime stage: minimal Debian with working DNS resolver + CA certs.
FROM debian:bookworm-slim AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=build /app/build/bin/server /app/bin/server
COPY --from=build /app/public ./public

EXPOSE 8080
CMD ["/app/bin/server"]
