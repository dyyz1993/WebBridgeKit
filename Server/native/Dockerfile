# This image deliberately uses no external base image. `drel-selfhosted` is a
# CGO-free Linux binary built by tools/build-drel-selfhosted-native.sh, so an
# isolated host can build it even when Docker Hub is unavailable.
FROM scratch

COPY --chown=65532:65532 dist/drel-selfhosted /usr/local/bin/drel-selfhosted
# Docker copies this owned placeholder into a newly-created named volume,
# making the persisted registration store writable by the unprivileged relay.
COPY --chown=65532:65532 data/ /var/lib/drel-selfhosted/

USER 65532:65532
ENV DREL_LISTEN_ADDR=0.0.0.0:8080
ENV DREL_DATA_DIR=/var/lib/drel-selfhosted
ENTRYPOINT ["/usr/local/bin/drel-selfhosted"]
