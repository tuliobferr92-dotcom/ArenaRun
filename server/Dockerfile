# REINOS online-multiplayer relay server.
#
# Build from the REPOSITORY ROOT (not from server/), since this package
# depends on ../packages/reinos_engine by relative path:
#   docker build -f server/Dockerfile -t reinos-server .
#
# Produces an AOT-compiled executable — no SDK, no JIT warm-up, tiny
# runtime footprint, which matters on free/low-tier hosting tiers.
FROM dart:3.13 AS build

# Keep the same relative layout the pubspec's path dependency expects.
COPY packages/reinos_engine /packages/reinos_engine

WORKDIR /app
COPY server/pubspec.yaml ./
RUN dart pub get

COPY server/ .
RUN dart pub get
RUN dart compile exe bin/server.dart -o bin/server

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/server
COPY --from=build /app/data /app/data

WORKDIR /app
EXPOSE 8080
ENTRYPOINT ["/app/bin/server"]
