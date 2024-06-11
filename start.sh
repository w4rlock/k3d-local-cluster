#!/usr/bin/env bash
set -o pipefail
set -o nounset
set -o errexit

# ############################################################
# Bash context and import environment
readonly THIS_DIR=$(dirname "$0")
source ${THIS_DIR}/.env

# ############################################################
# Utils bash functions for logging
readonly BOLD=$(tput bold)
readonly C_RESET=$(tput sgr0)

red() {      printf "${BOLD}$(tput setaf 1)${@}${C_RESET}" ; }
blue() {     printf "${BOLD}$(tput setaf 4)${@}${C_RESET}" ; }
green() {    printf "$(tput setaf 2)${@}${C_RESET}" ; }
green_b() {  printf "${BOLD}$(tput setaf 2)${@}${C_RESET}" ; }
readonly LOG_PREFFIX="$(blue '[')$(green '*')$(blue ']')"
log_info() { printf "${LOG_PREFFIX} $(green ${@})\n" ; }


# ############################################################
# Check or install k3d cli
log_info "Checking k3d cli ..."
k3d --version \
    || curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Check or create cluster
log_info "Checking k3d cluster ..."
k3d cluster list | grep $CLUSTER_NAME \
    || k3d cluster create $CLUSTER_NAME #--verbose


# Configurar kubectl para usar el nuevo clúster
export KUBECONFIG=$(k3d kubeconfig write $CLUSTER_NAME)

# ############################################################
# Build docker image and import
log_info "Building dockerfile ..."
docker build ${THIS_DIR}/../ -t ${DOCKER_IMAGE_NAME}:latest > /dev/null
log_info "Importing '${DOCKER_IMAGE_NAME}:latest' docker image to k3d  ..."
k3d image import -c $CLUSTER_NAME ${DOCKER_IMAGE_NAME}:latest #--verbose

# ############################################################
# Kubernetes resources creation
log_info "Processing k3d yml resources ..."
cp -rv ${THIS_DIR}/../k8s/* ${THIS_DIR}/resources

# primero creamos el namespace
envsubst < ${THIS_DIR}/ns.yml | kubectl apply -f -

for k8s_resource in ${THIS_DIR}/resources/*; do
    log_info "Processing and apply ${k8s_resource} ..."
    # debemos remover la seccion de "hardware" sino da error k3d
    yq eval 'del(.spec.jobTemplate.spec.template.spec.containers[].resources)' -i ${k8s_resource} || true
    envsubst < ${k8s_resource} | kubectl apply -f -
done


# ############################################################
# kubectl connect to k3d
log_info "Connecting kubectl to k3d cluster ..."
kubectl config use-context k3d-$KUBE_NAMESPACE
kubectl config set-context $(kubectl config current-context) --namespace=$KUBE_NAMESPACE

# ############################################################
log_info "Showing resources ..."
kubectl get po,ep,svc #--all-namespaces

log_info "Cluster '${CLUSTER_NAME}' is up and resources has been created."