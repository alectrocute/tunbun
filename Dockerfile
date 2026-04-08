# tunbun: frp-based tunnel — server (Magic Container) or client (local machine)
ARG FRP_VERSION=0.68.0

FROM alpine:3.21

ARG FRP_VERSION
ARG TARGETARCH

RUN apk add --no-cache ca-certificates wget iproute2 \
  && case "$TARGETARCH" in \
       amd64) FRP_ARCH=amd64 ;; \
       arm64) FRP_ARCH=arm64 ;; \
       *) echo "unsupported TARGETARCH=$TARGETARCH" >&2; exit 1 ;; \
     esac \
  && wget -qO- "https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_${FRP_ARCH}.tar.gz" \
     | tar xz -C /tmp \
  && install -m0755 "/tmp/frp_${FRP_VERSION}_linux_${FRP_ARCH}/frps" /usr/local/bin/frps \
  && install -m0755 "/tmp/frp_${FRP_VERSION}_linux_${FRP_ARCH}/frpc" /usr/local/bin/frpc \
  && rm -rf "/tmp/frp_${FRP_VERSION}_linux_${FRP_ARCH}"

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 7000 80 443 7500

ENTRYPOINT ["/entrypoint.sh"]
