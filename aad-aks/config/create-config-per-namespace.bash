#!/bin/bash

# https://jeremievallee.com/2018/05/28/kubernetes-rbac-namespace-user.html

# https://www.cncf.io/wp-content/uploads/2020/04/2020_04_Introduction-to-Kubernetes-RBAC.pdf


while getopts u:n: option
do
case "${option}"
in
u) USER=${OPTARG};;
n) NAMESPACE=${OPTARG};;
esac
done

me="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"

display_usage() { 
	echo "Example of usage:" 
	echo -e "bash $me -u john -ns default " 
	} 


if [[ -z "$USER" ]]; then
  echo "User name is misssing"
  display_usage
  exit 1
fi

if [[ -z "$NAMESPACE" ]]; then
  echo "Namespace name is misssing"
  display_usage
  exit 1
fi

set -u  # Treat unset variables as an error when substituting
set -e # Exit immediately if a command exits with a non-zero status.



CONFIG_FILE=config-${USER}-${NAMESPACE}-conf.yaml

SECRET=$(kubectl get sa ${USER} -n ${NAMESPACE} -o json | jq -r .secrets[].name )

RAW_TOKEN=$(kubectl get secret ${SECRET} -n ${NAMESPACE} -o json | jq -r '.data["token"]')

USER_TOKEN="$(kubectl get secret "${SECRET}" -n ${NAMESPACE} -o jsonpath='{.data.token}' | base64 -d)"

CONTEXT=$(kubectl config current-context)
CLUSTER_NAME=$(kubectl config get-contexts ${CONTEXT} | awk '{print $3}' | tail -n 1)
ENDPOINT=$(kubectl config view -o jsonpath="{.clusters[?(@.name == \"${CLUSTER_NAME}\")].cluster.server}")
kubectl config view --minify --raw --output 'jsonpath={..cluster.certificate-authority-data}' |base64 -d  > ca.crt
CA=$(kubectl config view --minify --raw --output 'jsonpath={..cluster.certificate-authority-data}' |base64 -d)

# adding more information to config file name

ENDPOINT2=${ENDPOINT//./-}
ENDPOINT2=${ENDPOINT2//:/-}
ENDPOINT2=${ENDPOINT2//https:/}
ENDPOINT2=${ENDPOINT2//\/}
CONFIG_FILE=config-${ENDPOINT2}-${USER}-${NAMESPACE}-conf.yaml

echo "Global variables:"
echo "namespace: $NAMESPACE" 
echo "user: $USER" 
echo "context: $CONTEXT"
echo "cluster_name: $CLUSTER_NAME"
echo "endpoint: $ENDPOINT"
echo "secret: $SECRET"
#echo "user token: $USER_TOKEN" 
echo "config file: ${CONFIG_FILE}"
#echo "ca: $CA" 

# Set up the config
KUBECONFIG=$CONFIG_FILE kubectl config set-cluster ${CLUSTER_NAME} \
  --embed-certs=true \
  --server=${ENDPOINT} \
  --certificate-authority=./ca.crt

KUBECONFIG=$CONFIG_FILE kubectl config set-credentials ${USER}-${CLUSTER_NAME#cluster-} --token=${USER_TOKEN}
KUBECONFIG=$CONFIG_FILE kubectl config set-context ${USER}-${CLUSTER_NAME#cluster-} \
  --cluster=${CLUSTER_NAME} \
  --user=${USER}-${CLUSTER_NAME#cluster-} \
  --namespace=${NAMESPACE}
KUBECONFIG=$CONFIG_FILE kubectl config use-context ${USER}-${CLUSTER_NAME#cluster-}  

rm ./ca.crt || true

echo "Testing permissions for user $USER "

kubectl "--token=${USER_TOKEN}" get nodes -o wide
kubectl "--kubeconfig=$CONFIG_FILE" get all -n ${NAMESPACE} 
kubectl "--kubeconfig=$CONFIG_FILE" get nodes -o wide
kubectl "--kubeconfig=$CONFIG_FILE" cluster-info
kubectl "--kubeconfig=$CONFIG_FILE" top pods
kubectl "--kubeconfig=$CONFIG_FILE" get services
kubectl "--kubeconfig=$CONFIG_FILE" describe ingress


rm ./${CONFIG_FILE}|| true