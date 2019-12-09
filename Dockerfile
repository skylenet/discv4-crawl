FROM ethereum/client-go:alltools-v1.9.8 as geth

FROM alpine:3.10

ENV CRAWL_GIT_REPO=https://github.com/skylenet/discv4-crawl.git \
    CRAWL_GIT_BRANCH=master \
    CRAWL_GIT_PUSH=false \
    CRAWL_GIT_USER=crawler \
    CRAWL_GIT_EMAIL=crawler@localhost \
    CRAWL_TIMEOUT=30m \
    CRAWL_INTERVAL=300 \
    CRAWL_RUN_ONCE=false \
    CRAWL_DNS_SIGNING_KEY=/secrets/key.json \
    CRAWL_DNS_PUBLISH=false \
    CLOUDFLARE_API_TOKEN="" \
    CLOUDFLARE_ZONE_ID=""


COPY --from=geth /usr/local/bin/devp2p /usr/local/bin/
RUN apk update && apk add --no-cache git openssh

WORKDIR /crawler
ADD run.sh .
CMD ["./run.sh"]
