FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

# Noctalia build environment — discarded after building
FROM ghcr.io/void-linux/void-glibc-full:latest AS source-builder

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/sourcebuild.sh

# Actual OS image — clean starting point
FROM ghcr.io/void-linux/void-glibc-full:latest AS final

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh && /ctx/info.sh

# Copy only apps
COPY --from=source-builder /out/ /