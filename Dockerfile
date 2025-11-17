# Multi-stage Dockerfile for MTProxy (build from source, produce runtime image)

FROM debian:stable-slim AS builder
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies (matching README instructions)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential git curl ca-certificates libssl-dev zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# Copy source into the container and build
COPY . /src
RUN make

# Collect the built binary
RUN mkdir -p /out/bin \
    && cp -v objs/bin/mtproto-proxy /out/bin/

FROM debian:stable-slim
ENV DEBIAN_FRONTEND=noninteractive

# Minimal runtime dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create runtime dirs
RUN mkdir -p /opt/MTProxy

# Copy binary from builder
COPY --from=builder /out/bin/mtproto-proxy /usr/local/bin/mtproto-proxy

WORKDIR /opt/MTProxy

# Expose default ports (proxy port and local stats port)
EXPOSE 443 8888

# Default entrypoint: run `mtproto-proxy` (arguments supplied at `docker run`)
ENTRYPOINT ["/usr/local/bin/mtproto-proxy"]
CMD ["--help"]

# Notes:
# - The container does not embed `proxy-secret` or `proxy-multi.conf`.
#   Mount them into `/opt/MTProxy` and pass paths as arguments, e.g.:
#   docker run -v /host/proxy-secret:/opt/MTProxy/proxy-secret \
#     -v /host/proxy-multi.conf:/opt/MTProxy/proxy-multi.conf \
#     --cap-add NET_BIND_SERVICE telegram/proxy:latest \
#     /usr/local/bin/mtproto-proxy -u nobody -p 8888 -H 443 -S <secret> --aes-pwd proxy-secret proxy-multi.conf -M 1
