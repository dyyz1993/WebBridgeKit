FROM swift:6.0-noble AS build
WORKDIR /build
COPY Package.swift ./
COPY Sources/ Sources/
RUN swift build -c release --static-swift-stdlib

FROM ubuntu:noble AS run
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libcurl4 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /build/.build/release/WebBridgeServer ./WebBridgeServer
COPY .env.example .env
RUN mkdir -p /app/data

EXPOSE 8080
ENTRYPOINT ["./WebBridgeServer"]
