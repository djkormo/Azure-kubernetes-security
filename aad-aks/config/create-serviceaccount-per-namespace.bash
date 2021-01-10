
#!/bin/bash


while getopts u:n:l: option
do
case "${option}"
in
u) USER=${OPTARG};;
n) NAMESPACE=${OPTARG};;
l) LEVEL=${OPTARG};;
esac
done

ME="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"

display_usage() { 
	echo "Example of usage:" 
	echo -e "bash $ME -u john -n default -l VIEW"
  echo -e "bash $ME -u john -n default -l ADMIN"

	} 

echo "user: $USER"
echo "namespace: $NAMESPACE"

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


if [[ -z "$LEVEL" ]]; then
  echo "Level name is misssing"
  display_usage
  exit 1
fi

if [[ "$LEVEL" != "ADMIN"  &&  "$LEVEL" != "VIEW" ]]; then
  echo "Level name is incorrect"
  "Only VIEW or ADMIN are implemented"
  display_usage
  exit 1
fi



set -u  # Treat unset variables as an error when substituting
set -e # Exit immediately if a command exits with a non-zero status.


# kubectl create sa ${USER}

cat <<EOF  | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${USER}
  namespace: ${NAMESPACE}
EOF

SECRET=$(kubectl get sa ${USER} -n ${NAMESPACE} -o json | jq -r .secrets[].name)

# echo $SECRET
kubectl get secret ${SECRET} -n ${NAMESPACE} -o json | jq -r '.data["ca.crt"]' | base64  > ca.crt

USER_TOKEN="$(kubectl get secret "${SECRET}" -n ${NAMESPACE} -o jsonpath='{.data.token}' | base64 -d)"
CONTEXT=$(kubectl config current-context)
CLUSTER_NAME=$(kubectl config get-contexts $CONTEXT | awk '{print $3}' | tail -n 1)
ENDPOINT=$(kubectl config view -o jsonpath="{.clusters[?(@.name == \"${CLUSTER_NAME}\")].cluster.server}")


ENDPOINT2=${ENDPOINT//./-}
ENDPOINT2=${ENDPOINT2//:/-}
ENDPOINT2=${ENDPOINT2//https:/}
ENDPOINT2=${ENDPOINT2//\/}
CONFIG_FILE=config-for-test-${ENDPOINT2}-${USER}-${NAMESPACE}-conf.yaml

echo "namespace: $NAMESPACE" 
echo "user: $USER" 
echo "context: $CONTEXT"
echo "cluster_name: $CLUSTER_NAME"
echo "endpoint: $ENDPOINT"
echo "endpoint2: $ENDPOINT2"
echo "secret: $SECRET"
#echo "user token: $USER_TOKEN" 
echo "config file: ${CONFIG_FILE}"

# add permissions on cluster level

if [[ "$LEVEL" == "ADMIN" ]]; then
echo "adding cluster role permission for ${USER}"
cat <<EOF  | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: view-${USER}-global
subjects:
- kind: ServiceAccount
  name: ${USER}
  namespace: ${NAMESPACE}
roleRef:
  kind: ClusterRole
  name: view
  apiGroup: rbac.authorization.k8s.io
EOF

fi # of admin

# add permissions on namespace level - ADMIN ONLY

if [[ "$LEVEL" == "ADMIN" ]]; then

echo "adding admin permission for ${USER}"

cat <<EOF  | kubectl apply -f -
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: default-${USER}-${NAMESPACE}-full-access
  namespace: ${NAMESPACE}
rules:
- apiGroups:
  - ""
  - extensions
  - apps
  - autoscaling
  - networking.k8s.io
  - metrics.k8s.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - batch
  resources:
  - jobs
  - cronjobs
  verbs:
  - '*'
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: rolebinding-${USER}-${NAMESPACE}-full-access
  namespace: ${NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: role-${USER}-${NAMESPACE}-full-access
subjects:
- kind: ServiceAccount
  name: ${USER}
  namespace: ${NAMESPACE}
EOF

fi # of admin

# add permissions on namespace level - VIEW ONLY

if [[ "$LEVEL" == "VIEW" ]]; then

echo "adding viewer permission for ${USER}"

cat <<EOF  | kubectl apply -f -
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: role-${USER}-${NAMESPACE}-view
  namespace: ${NAMESPACE}
rules:
- apiGroups:
  - ""
  - extensions
  - apps
  - autoscaling
  - networking.k8s.io
  - metrics.k8s.io
  resources:
  - '*'
  verbs: ['get','list','watch']
- apiGroups:
  - batch
  resources:
  - jobs
  - cronjobs
  verbs: ['get','list','watch']
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: rolebinding-${USER}-${NAMESPACE}-view
  namespace: ${NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: role-${USER}-${NAMESPACE}-view
subjects:
- kind: ServiceAccount
  name: ${USER}
  namespace: ${NAMESPACE}
EOF

fi # of viewer

echo "Permission for user ${USER} in namespace ${NAMESPACE}"

kubectl get role,rolebinding -n ${NAMESPACE} | grep ${USER}

echo "Permission for user ${USER} at cluster scope"

kubectl get clusterrole,clusterrolebinding -n ${NAMESPACE} | grep ${USER}

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

echo "done!"
echo "Test with: "
echo "kubectl  get pods"
echo "Testing permissions for user $USER "

kubectl "--token=${USER_TOKEN}" get nodes -o wide
kubectl "--token=${USER_TOKEN}" get all,ep -n ${NAMESPACE}

kubectl "--token=${USER_TOKEN}" auth can-i list pod --namespace ${NAMESPACE} 
kubectl "--token=${USER_TOKEN}" auth can-i create secret --namespace kube-system

rm -f ${CONFIG_FILE} || true













