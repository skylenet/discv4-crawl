#!/bin/sh

CRAWL_GIT_REPO="${CRAWL_GIT_REPO:-https://github.com/skylenet/discv4-crawl.git}"
CRAWL_GIT_BRANCH="${CRAWL_GIT_BRANCH:-master}"
CRAWL_GIT_PUSH="${CRAWL_GIT_PUSH:-false}"
CRAWL_GIT_USER="${CRAWL_GIT_USER:-crawler}"
CRAWL_GIT_EMAIL="${CRAWL_GIT_EMAIL:-crawler@localhost}"

CRAWL_TIMEOUT="${CRAWL_TIMEOUT:-30m}"
CRAWL_INTERVAL="${CRAWL_INTERVAL:-300}"
CRAWL_RUN_ONCE="${CRAWL_RUN_ONCE:-false}"
CRAWL_DNS_SIGNING_KEY="${CRAWL_DNS_SIGNING_KEY:-/secrets/key.json}"
CRAWL_DNS_PUBLISH="${CRAWL_DNS_PUBLISH-false}"
CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN-}"
CLOUDFLARE_ZONE_ID="${CLOUDFLARE_ZONE_ID-}"

set -xe

networks="mainnet rinkeby goerli ropsten"

# Function definitions

git_setup() {
  git config --global user.email "$CRAWL_GIT_EMAIL"
  git config --global user.name "$CRAWL_GIT_USER"
  git clone "$CRAWL_GIT_REPO" discv4-crawl
  cd discv4-crawl
  git checkout "$CRAWL_GIT_BRANCH"
}

git_pull() {
  git pull
}

generate_list() {
  devp2p discv4 crawl -timeout "$CRAWL_TIMEOUT" all.json

  for N in $networks
  do
    # All nodes
    mkdir -p "all.${N}.nodes.ethflare.xyz"
    devp2p nodeset filter all.json -eth-network "${N}" > "all.${N}.nodes.ethflare.xyz/nodes.json"

    # LES nodes
    mkdir -p "les.${N}.nodes.ethflare.xyz"
    devp2p nodeset filter all.json -eth-network "${N}" -les-server > "les.${N}.nodes.ethflare.xyz/nodes.json"
  done
}

sign_lists() {
  for D in *.nodes.ethflare.xyz; do
    if [ -d "${D}" ]; then
      echo "" | devp2p dns sign "${D}" "$CRAWL_DNS_SIGNING_KEY"
    fi
  done
}

publish_dns() {
  for D in *.nodes.ethflare.xyz; do
    if [ -d "${D}" ]; then
      devp2p dns to-cloudflare -zoneid "$CLOUDFLARE_ZONE_ID" "${D}"
    fi
  done
}

git_push() {
  if [ -n "$(git status --porcelain)" ]; then
    git add all.json ./*.nodes.ethflare.xyz/*.json
    git commit --message "automatic update: crawl time $CRAWL_TIMEOUT"
    git push origin "$CRAWL_GIT_BRANCH"
  fi
}

# Main execution

git_setup

while true
do
  # Pull changes from git repo
  git_pull

  # Generate node lists
  generate_list

  # Sign lists
  if [ -f "$CRAWL_DNS_SIGNING_KEY" ]; then
    sign_lists
  fi

  # Push changes back to git repo
  if [ "$CRAWL_GIT_PUSH" = true ] ; then
    git_push
  fi

  # Publish DNS records
  if [ "$CRAWL_DNS_PUBLISH" = true ] ; then
    publish_dns
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
