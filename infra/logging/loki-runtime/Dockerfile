ARG LOKI_BASE_IMAGE=grafana/loki:3.6.10
FROM busybox:1.36.1-musl AS busybox

FROM ${LOKI_BASE_IMAGE}
COPY --from=busybox /bin/busybox /bin/wget
