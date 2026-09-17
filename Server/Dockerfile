# Override these only for an explicit build command on a host whose outbound
# network cannot reach Docker Hub. Keeping the defaults preserves ordinary
# Docker Hub builds and avoids a daemon-wide registry-mirror mutation.
ARG SWIFT_IMAGE=swift:6.0-noble
ARG RUNTIME_IMAGE=ubuntu:noble

FROM ${SWIFT_IMAGE} AS build
WORKDIR /build
COPY Package.swift ./
COPY Package.resolved ./
COPY Sources/ Sources/
COPY Tests/ Tests/
RUN swift build -c release --static-swift-stdlib

FROM ${RUNTIME_IMAGE} AS run
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    libcurl4 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /build/.build/release/WebBridgeServer ./WebBridgeServer
RUN mkdir -p /app/data

EXPOSE 8080
ENTRYPOINT ["./WebBridgeServer"]
