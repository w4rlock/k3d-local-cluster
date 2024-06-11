#!/usr/bin/env bash
set -o pipefail
set -o nounset
set -o errexit

readonly THIS_DIR=$(dirname "$0")
source ${THIS_DIR}/.env

k3d cluster stop $CLUSTER_NAME #--verbose
k3d cluster delete $CLUSTER_NAME #--verbose