#!/bin/bash

RED='\033[0;31m'
NC='\033[0m' # No Color
BRANCH=$(git symbolic-ref --short -q HEAD)

if [ "$BRANCH" != "master" ]; then
    printf "%sError:%s wrong branch: production deploy must happen from master only. Current branch: ${BRANCH}.\n" "$RED" "$NC"
    exit 1
fi

git pull &&

(git diff --quiet HEAD || (echo "There are uncommitted changes in the branch" && exit 1))

yarn ci &&
sh cli-process-env.sh "mainnet" &&
yarn generate --fail-on-error &&
firebase deploy -P zksync-vue-mainnet --only hosting:mainnet &&
echo "New version #$(git tag -l|tail -n1)) Mainnet deployed successfully!"
