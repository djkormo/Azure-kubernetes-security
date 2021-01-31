#!/bin/sh
# -------

set -u  # Treat unset variables as an error when substituting
set -e # Exit immediately if a command exits with a non-zero status.


git clone https://github.com/djkormo/Azure-kubernetes-security.git

PIP = $1
LIP=10.240.0.4

sudo mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/

export KUBECONFIG='/etc/kubernetes/admin.conf'
export KUBECONFIG=$HOME/.kube/config

kubectl config view --minify --raw --output 'jsonpath={..cluster.certificate-authority-data}' |base64 -d  > ca.crt
kubectl config view --minify --raw --output 'jsonpath={..user.client-certificate-data}' |base64 -d  > ./admin.pem
kubectl config view --minify --raw --output 'jsonpath={..user.client-key-data}' |base64 -d  > admin-key.pem

# backup our configuration
kubectl -n kube-system get configmap kubeadm-config -o jsonpath='{.data.ClusterConfiguration}' > ${HOME}/kubeadm.yaml

# remove current certs
rm /etc/kubernetes/pki/apiserver.*

# add --apiserver-cert-extra-sans with LOCAL and PUBLIC IP

kubeadm init phase certs all --apiserver-advertise-address=0.0.0.0 --apiserver-cert-extra-sans=${LIP},${PIP}

# remove api-server
docker rm -f `docker ps -q -f 'name=k8s_kube-apiserver*'`

# restart kubelet
systemctl restart kubelet

#kubectl config set-cluster k8s-security2021 \
#  --certificate-authority=./ca.crt \
#  --embed-certs=true \
#  --server=https://${PIP}:6443

#kubectl config set-credentials admin \
#  --client-certificate=./admin.pem \
#  --client-key=./admin-key.pem

#kubectl config set-context k8s-security2021 \
#  --cluster=k8s-security2021 \
#  --user=admin

#kubectl config use-context k8s-security2021
# test
#kubectl get nodes 





