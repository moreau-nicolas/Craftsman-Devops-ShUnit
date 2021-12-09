#!/usr/bin/env bash
# Bash3 Boilerplate. Copyright (c) 2014, kvz.io

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
__root="$(cd "$(dirname "${__dir}")" && pwd)" # <-- change this as it depends on your app

project="formation-ci-${USER}"
cluster_name="formation-ci"
region="europe-west1"
trainees=("laurent")

create_cluster() {
  gcloud config unset project

  printf "## Create project ${project}\n"
  orga=$(gcloud organizations list --filter="DISPLAY_NAME=zenika.com" --format="value(ID)")
  gcloud projects create "${project}" --organization=${orga}

  # gcloud alpha billing accounts list
  printf "## Associate project ${project} and billing account\n"
  billing_id=$(gcloud alpha billing accounts list --filter="NAME:Facturation Zenika" --format="value(ACCOUNT_ID)")
  gcloud alpha billing projects link ${project} --billing-account "${billing_id}"

  printf "## Enable container.googleapis.com API\n"
  gcloud services enable container.googleapis.com --project "${project}"

  printf "## Create cluster ${cluster_name}\n"
  gcloud container clusters create "${cluster_name}" \
    --region "${region}" --project "${project}" \
    --preemptible --machine-type e2-standard-8 \
    --num-nodes 1 --min-nodes 0 --max-nodes 3 \
    --enable-autorepair --enable-autoscaling
}

get_cluster_credentials() {
  printf "## Get credentials ${USER}\n"
  gcloud container clusters get-credentials "${cluster_name}" \
    --region "${region}" --project "${project}"

}

create_reverse_proxy() {
  printf "## Create reverse proxy\n"
  kubectl apply -f reverse-proxy.yml
}

add_helm_charts_repo() {
  printf "## Add and update helm repos\n"
  helm repo add oteemocharts https://oteemo.github.io/charts
  helm repo add jenkins https://charts.jenkins.io
  helm repo add codecentric https://codecentric.github.io/helm-charts

  helm dependency update environnement-stagiaire
}

create_trainee_namespace () {
  printf "## Create trainee namespaces\n"
  for trainee in ${trainees[@]} ; do
    helm install ${trainee} environnement-stagiaire \
      --namespace ${trainee} --create-namespace
  done
}

delete_cluster() {
  printf "## Delete cluster ${cluster_name}\n"
  gcloud container clusters delete "${cluster_name}" \
    --region "${region}" --project "${project}"

}


delete_project() {
  printf "## Delete project ${project}\n"
  gcloud projects delete "${project}"

  gcloud config unset project
}

delete_reverse_proxy() {
  printf "## Delete reverse proxy\n"
  kubectl delete -f reverse-proxy.yml
}

delete_trainee_namespace() {
  printf "## Delete trainee namespaces\n"
  for trainee in ${trainees[@]} ; do
    helm uninstall $trainee environnement-stagiaire --namespace ${trainee}
  done
}

info() {
  ip=$(kubectl get service reverse-proxy -o jsonpath="{.status.loadBalancer.ingress[*].ip}")

  printf "# URLs des ressources\n\n"
  for trainee in "${trainees[@]}" ; do
    printf "## ${trainee} \n"
    printf " - Jenkins: http://jenkins.${trainee}.${ip}.nip.io/\n"
    printf " - Nexus: http://nexus.${trainee}.${ip}.nip.io/\n"
    printf " - Sonar: http://sonar.${trainee}.${ip}.nip.io/\n"
    printf " - Mailhog: http://mailhog.${trainee}.${ip}.nip.io/ - SMTP: mailhog:1025\n"
    printf "\n"
  done
}

usage() {
    printf "Usage:\n"
    printf " ${__base} [Option]\n\n"
    printf " Options: \n"
    printf " - create: create cluster, reverse proxy, trainees namespaces,\n"
    printf "           add helm charts, and display trainees infos \n"
    printf " - create_rp: create reverse proxy \n"
    printf " - add_helm: add helm charts to cluster \n"
    printf " - create_ns: create trainees namespaces in cluster\n"
    printf " - delete_ns: delete trainees namespaces in cluster\n"
    printf " - delete_rp: delete reverse proxy \n"
    printf " - delete_cl: delete cluster \n"
    printf " - delete_pj: delete project \n"
    printf " - delete: delete reverse proxy and delete clsuter (in this order) \n"
    printf " - get_cred: init kubectl \n"
    printf " - info: display trainees infos \n"
    printf " - -h, --help: display this help message \n"
    printf "\n"

}

arg1="${1:-}"

case ${arg1} in
  "create")
    create_cluster
    get_cluster_credentials
    create_reverse_proxy
    add_helm_charts_repo
    create_trainee_namespace
    info
    ;;
  "create_rp")
    create_reverse_proxy
    ;;
  "add_helm")
    add_helm_charts_repo
    ;;
  "create_ns")
    create_trainee_namespace
    ;;
  "delete_ns")
    delete_trainee_namespace
    ;;
  "delete_rp")
    delete_reverse_proxy
    ;;
  "delete_cl")
    delete_cluster
    ;;
  "delete_pj")
    delete_project
    ;;
  "delete")
    #delete_trainee_namespace
    delete_reverse_proxy
    delete_cluster
    delete_project
    ;;
  "info")
    info
    ;;
  "get_cred")
    get_cluster_credentials
    ;;
  "-h"|"--help")
    usage
    ;;
  "--source-only")
    return 0
    ;;
  *)
    usage
    exit 1
    ;;
esac
