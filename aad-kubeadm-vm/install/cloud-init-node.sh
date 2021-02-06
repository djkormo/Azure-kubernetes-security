#!/bin/sh
# -------

set -u  # Treat unset variables as an error when substituting
set -e # Exit immediately if a command exits with a non-zero status.

# install docker & kubeadm - ubuntu
# ---------------------------------

# update and upgrade packages
apt-get update && apt-get upgrade -y

# install docker
apt-get install -y docker.io >> /var/log/install

# install kubeadm
apt-get install -y apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

apt-get update
#apt-get install -y kubelet kubeadm kubectl
apt-get install kubeadm=1.19.0-00 kubectl=1.19.0-00 kubelet=1.19.0-00 -y >> /var/log/install

systemctl enable docker.service

# kubeadm - agent nodes
# ---------------------
# initialize agent node
# Check proper IP of master node -> 10.240.0.4:6443
kubeadm join --discovery-token-unsafe-skip-ca-verification --token '8f07c4.2fa8f9e48b6d4036' 10.240.0.4:6443 >> /var/log/install

# --------------------------------------------
echo 'configuration complete' > /tmp/hello.txt
