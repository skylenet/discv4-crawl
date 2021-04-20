#!/bin/bash

CRAWL_GIT_REPO="${CRAWL_GIT_REPO:-https://github.com/skylenet/discv4-dns-lists.git}"
CRAWL_GIT_BRANCH="${CRAWL_GIT_BRANCH:-master}"
CRAWL_GIT_PUSH="${CRAWL_GIT_PUSH:-false}"
CRAWL_GIT_USER="${CRAWL_GIT_USER:-crawler}"
CRAWL_GIT_EMAIL="${CRAWL_GIT_EMAIL:-crawler@localhost}"

CRAWL_DNS_DOMAIN="${CRAWL_DNS_DOMAIN:-nodes.example.local}"
CRAWL_TIMEOUT="${CRAWL_TIMEOUT:-30m}"
CRAWL_INTERVAL="${CRAWL_INTERVAL:-300}"
CRAWL_RUN_ONCE="${CRAWL_RUN_ONCE:-false}"
CRAWL_DNS_SIGNING_KEY="${CRAWL_DNS_SIGNING_KEY:-/secrets/key.json}"

CRAWL_DNS_PUBLISH_ROUTE53="${CRAWL_DNS_PUBLISH_ROUTE53-false}"
ROUTE53_ZONE_ID="${ROUTE53_ZONE_ID-}"
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID-}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY-}"

CRAWL_DNS_PUBLISH_CLOUDFLARE="${CRAWL_DNS_PUBLISH_CLOUDFLARE-false}"
CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN-}"
CLOUDFLARE_ZONE_ID="${CLOUDFLARE_ZONE_ID-}"

CRAWL_PUBLISH_METRICS="${CRAWL_PUBLISH_METRICS:-false}"
INFLUXDB_URL="${INFLUXDB_URL:-http://localhost:8086}"
INFLUXDB_DB="${INFLUXDB_DB:-metrics}"
INFLUXDB_USER="${INFLUXDB_USER:-user}"
INFLUXDB_PASSWORD="${INFLUXDB_PASSWORD:-password}"

set -xe

geth_src="$PWD/go-ethereum"

# Function definitions

git_update_repo() {
  upstream=$1
  repodir=$2
  branch=${3:-master}

  if [[ -d $repodir/.git ]]; then
    ( cd "$repodir"; git pull "$upstream"; git checkout "$branch" )
  else
    git clone --depth 1 --branch "$branch" "$upstream" "$repodir"
  fi
}

update_devp2p_tool() {
  git_update_repo https://github.com/ethereum/go-ethereum "$geth_src"
  ( cd "$geth_src" && go build ./cmd/devp2p )
}

filter_list() {
  network="$1"
  name="$2"
  shift 2

  mkdir -p "${name}.${network}.${CRAWL_DNS_DOMAIN}"
  devp2p nodeset filter all.json -eth-network "$network" $@ > "${name}.${network}.${CRAWL_DNS_DOMAIN}/nodes.json"
}

generate_list() {
  devp2p discv4 crawl -timeout "$CRAWL_TIMEOUT" all.json

  # Mainnet
  filter_list mainnet all   -limit 3000
  filter_list mainnet les   -limit 200  -les-server
  filter_list mainnet snap  -limit 500  -snap

  # Rinkeby
  filter_list rinkeby all   -limit 500
  filter_list rinkeby les   -limit 50   -les-server
  filter_list rinkeby snap  -limit 50   -snap

  # Goerli
  filter_list goerli all    -limit 500
  filter_list goerli les    -limit 50   -les-server
  filter_list goerli snap   -limit 50   -snap

  # Ropsten
  filter_list ropsten all   -limit 500
  filter_list ropsten les   -limit 50   -les-server
  filter_list ropsten snap  -limit 50   -snap
}

sign_lists() {
  for D in *."${CRAWL_DNS_DOMAIN}"; do
    if [ -d "${D}" ]; then
      echo "" | devp2p dns sign "${D}" "$CRAWL_DNS_SIGNING_KEY"
    fi
  done
}

publish_dns_cloudflare() {
  for D in *."${CRAWL_DNS_DOMAIN}"; do
    if [ -d "${D}" ]; then
      devp2p dns to-cloudflare -zoneid "$CLOUDFLARE_ZONE_ID" "${D}"
    fi
  done
}

publish_dns_route53() {
  for D in *."${CRAWL_DNS_DOMAIN}"; do
    if [ -d "${D}" ]; then
      devp2p dns to-route53 -zone-id "$ROUTE53_ZONE_ID" "${D}"
    fi
  done
}

git_push_crawler_output() {
  if [ -n "$(git status --porcelain)" ]; then
    git add all.json ./*."${CRAWL_DNS_DOMAIN}"/*.json
    git commit --message "automatic update: crawl time $CRAWL_TIMEOUT"
    git push origin "$CRAWL_GIT_BRANCH"
  fi
}

publish_metrics() {
  echo -n "" > metrics.txt
  for D in *."${CRAWL_DNS_DOMAIN}"; do
    if [ -d "${D}" ]; then
      LEN=$(jq length < "${D}/nodes.json")
      echo "devp2p_discv4.dns_node_count,domain=${D} value=${LEN}i" >> metrics.txt
    fi
  done
  cat metrics.txt
  set +x
  curl -i -u "${INFLUXDB_USER}:${INFLUXDB_PASSWORD}" \
       -XPOST "${INFLUXDB_URL}/write?db=${INFLUXDB_DB}" --data-binary @metrics.txt
  set -x
  rm metrics.txt
}

# Main execution

git config --global user.email "$CRAWL_GIT_EMAIL"
git config --global user.name "$CRAWL_GIT_USER"
git_update_repo "$CRAWL_GIT_REPO" output "$CRAWL_GIT_BRANCH"

PATH="$geth_src:$PATH"
cd output

while true
do
  # Pull changes from go-ethereum.
  update_devp2p_tool

  # Generate node lists
  generate_list

  # Sign lists
  if [ -f "$CRAWL_DNS_SIGNING_KEY" ]; then
    sign_lists
  fi

  # Push changes back to git repo
  if [ "$CRAWL_GIT_PUSH" = true ] ; then
    git_push_crawler_output
  fi

  # Publish DNS records
  if [ "$CRAWL_DNS_PUBLISH_CLOUDFLARE" = true ] ; then
    publish_dns_cloudflare
  fi
  if [ "$CRAWL_DNS_PUBLISH_ROUTE53" = true ] ; then
    publish_dns_route53
  fi

  # Publish metrics
  if [ "$CRAWL_PUBLISH_METRICS" = true ] ; then
    publish_metrics
  fi

  # Publish DNS records
  if [ "$CRAWL_RUN_ONCE" = true ] ; then
    echo "Ran once. Job is done. Exiting..."
    break
  fi

  # Wait for the next run
  echo "Waiting $CRAWL_INTERVAL seconds for the next run..."
  sleep "$CRAWL_INTERVAL"
done
