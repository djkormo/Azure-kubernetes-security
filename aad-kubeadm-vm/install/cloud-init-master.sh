#!/bin/sh
# -------

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


cat <<EOF | tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

mkdir -p /etc/systemd/system/docker.service.d
systemctl daemon-reload
systemctl restart docker
systemctl enable docker

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sysctl --system
apt-get update && apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

cat <<EOF | tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF


# kubeadm - master node
# ---------------------
# initialize master
kubeadm init --pod-network-cidr=192.168.0.0/16  --token '8f07c4.2fa8f9e48b6d4036' >> /var/log/install

# confirm output and copy "kubeadm join" command.

# copy /etc/kubernetes/admin.conf so we can use kubectl
sudo cp -i /etc/kubernetes/admin.conf /home/kubeconfig
sudo chown $(id -u):$(id -g) /home/kubeconfig

export KUBECONFIG='/etc/kubernetes/admin.conf'

# install pod network
#kubectl apply -f https://docs.projectcalico.org/v2.6/getting-started/kubernetes/installation/hosted/kubeadm/1.6/calico.yaml
kubectl apply -f https://docs.projectcalico.org/v3.11/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml >> /var/log/install

# --------------------------------------------
echo 'configuration complete' >> /var/log/install
echo 'configuration complete' > /tmp/hello.txt
