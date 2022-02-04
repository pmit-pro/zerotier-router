FROM alpine
MAINTAINER Markus Past - pm@pixelwarriors.net

COPY scripts/entrypoint.sh /entrypoint.sh

RUN apk add --no-cache \
        zerotier-one \
        iptables \
        bash \
    && echo "tun" >> /etc/modules \
    && chmod +x /entrypoint.sh

EXPOSE 9993/udp

ENTRYPOINT ["/entrypoint.sh"]

