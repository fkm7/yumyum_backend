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

# Runtime stage: only the Dart runtime libs and the compiled binary.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/build/bin/server /app/bin/server

EXPOSE 8080
CMD ["/app/bin/server"]
