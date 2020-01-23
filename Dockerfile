FROM ethereum/client-go:alltools-v1.9.10 as geth

FROM alpine:3.11

ENV CRAWL_GIT_REPO=https://github.com/skylenet/discv4-dns-lists.git \
    CRAWL_GIT_BRANCH=master \
    CRAWL_GIT_PUSH=false \
    CRAWL_GIT_USER=crawler \
    CRAWL_GIT_EMAIL=crawler@localhost \
    CRAWL_TIMEOUT=30m \
    CRAWL_INTERVAL=300 \
    CRAWL_RUN_ONCE=false \
    CRAWL_DNS_SIGNING_KEY=/secrets/key.json \
    CRAWL_DNS_PUBLISH_ROUTE53=false \
    ROUTE53_ZONE_ID="" \
    AWS_ACCESS_KEY_ID="" \
    AWS_SECRET_ACCESS_KEY="" \
    CRAWL_DNS_PUBLISH_CLOUDFLARE=false \
    CLOUDFLARE_API_TOKEN="" \
    CLOUDFLARE_ZONE_ID="" \
    CRAWL_PUBLISH_METRICS=false \
    INFLUXDB_URL=http://localhost:8086 \
    INFLUXDB_DB=metrics \
    INFLUXDB_USER=user \
    INFLUXDB_PASSWORD=password

COPY --from=geth /usr/local/bin/devp2p /usr/local/bin/
RUN apk update && apk add --no-cache git openssh curl jq

WORKDIR /crawler
ADD run.sh .
CMD ["./run.sh"]
