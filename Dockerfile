FROM ethereum/client-go:alltools-v1.9.8 as geth

FROM alpine:3.10

ENV CRAWL_TIMEOUT=30m \
    CRAWL_DNS_SIGNING_KEY=/secrets/key.json \
    CRAWL_GIT_REPO=https://github.com/skylenet/discv4-crawl.git \
    CRAWL_GIT_BRANCH=master \
    CRAWL_GIT_PUSH=false \
    CRAWL_GIT_USER=crawler \
    CRAWL_GIT_EMAIL=crawler@localhost

COPY --from=geth /usr/local/bin/devp2p /usr/local/bin/
RUN apk update && apk add --no-cache git openssh

WORKDIR /crawler
ADD run.sh .
CMD ["./run.sh"]
