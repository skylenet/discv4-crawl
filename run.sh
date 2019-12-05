#!/bin/sh

CRAWL_GIT_REPO="${CRAWL_GIT_REPO:-https://github.com/skylenet/discv4-crawl.git}"
CRAWL_GIT_BRANCH="${CRAWL_GIT_BRANCH:-master}"
CRAWL_GIT_PUSH="${CRAWL_GIT_PUSH:-false}"
CRAWL_GIT_USER="${CRAWL_GIT_USER:-crawler}"
CRAWL_GIT_EMAIL="${CRAWL_GIT_EMAIL:-crawler@localhost}"

CRAWL_TIMEOUT="${CRAWL_TIMEOUT:-30m}"
CRAWL_DNS_SIGNING_KEY="${CRAWL_DNS_SIGNING_KEY:-/secrets/key.json}"

set -xe

# Function definitions

git_setup() {
  git config --global user.email "$CRAWL_GIT_EMAIL"
  git config --global user.name "$CRAWL_GIT_USER"
  git clone "$CRAWL_GIT_REPO" discv4-crawl
  cd discv4-crawl
  git checkout "$CRAWL_GIT_BRANCH"
}

generate_list() {
  devp2p discv4 crawl -timeout "$CRAWL_TIMEOUT" all.json

  # Mainnet: All nodes
  mkdir -p all.mainnet.nodes.ethereum.org
  devp2p nodeset filter all.json -eth-network mainnet > all.mainnet.nodes.ethereum.org/nodes.json

  # Mainnet: LES nodes
  mkdir -p les.mainnet.nodes.ethereum.org
  devp2p nodeset filter all.json -eth-network mainnet -les-server > les.mainnet.nodes.ethereum.org/nodes.json

  rm all.json
}

sign_lists() {
  for D in *.nodes.ethereum.org; do
    if [ -d "${D}" ]; then
      echo "" | devp2p dns sign "${D}" "$CRAWL_DNS_SIGNING_KEY"
    fi
  done
}

git_push() {
  if [ -n "$(git status --porcelain)" ]; then
    git add ./*.nodes.ethereum.org/nodes.json
    git commit --message "automatic update: crawl time $CRAWL_TIMEOUT"
    git push origin "$CRAWL_GIT_BRANCH"
  fi
}

# Main execution

git_setup
generate_list

if [ "$CRAWL_GIT_PUSH" = true ] ; then
  git_push
fi

if [ -f "$CRAWL_DNS_SIGNING_KEY" ]; then
  sign_lists
fi
