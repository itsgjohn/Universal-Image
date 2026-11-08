FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

# Actual OS image — clean starting point
FROM ghcr.io/void-linux/void-glibc-full:latest AS final

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh && /ctx/info.sh

# Fail the build if the desktop apps or a runtime library are missing.
RUN test -x /usr/bin/noctalia \
    && test -x /usr/bin/mango \
    && ! ldd /usr/bin/noctalia | grep -q "not found"