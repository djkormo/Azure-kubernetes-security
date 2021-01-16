#!/bin/bash

# based on https://docs.microsoft.com/en-us/azure/container-instances/container-instances-using-azure-container-registry


# -o create ,delete ,status. shutdown
# -n aks-name
# -g aks-rg
# set your name and resource group

# aks-network-policy-calico-install.bash -n aks-security2020 -g rg-aks -l northeurope -o create

me="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"

display_usage() { 
	echo "Example of usage:" 
	echo -e "bash $me -n k8s-security2021 -g k8s-rg -l northeurope -o create" 
	echo -e "bash $me -n k8s-security2021 -g k8s-rg -l northeurope -o stop" 
	echo -e "bash $me -n k8s-security2021 -g k8s-rg -l northeurope -o start" 
	echo -e "bash $me -n k8s-security2021 -g k8s-rg -l northeurope -o status" 
	echo -e "bash $me -n k8s-security2021 -g k8s-rg -l northeurope -o delete" 
	} 

while getopts n:g:o:l: option
do
case "${option}"
in
n) K8S_NAME=${OPTARG};;
g) K8S_RG=${OPTARG};;
o) K8S_OPERATION=${OPTARG};;
l) K8S_LOCATION=${OPTARG};;
esac
done


if [ -z "$K8S_OPERATION" ]
then
      echo "\$K8S_OPERATION is empty"
	  display_usage
	  exit 1
else
      echo "\$K8S_OPERATION is NOT empty"
fi

if [ -z "$K8S_NAME" ]
then
      echo "\$K8S_NAME is empty"
	  display_usage
	  exit 1
else
      echo "\$AKS_NAME is NOT empty"
fi

if [ -z "$K8S_RG" ]
then
      echo "\$K8S_RG is empty"
	  display_usage
	  exit 1
else
      echo "\$K8S_RG is NOT empty"
fi

if [ -z "$K8S_LOCATION" ]
then
      echo "\$K8S_LOCATION is empty"
	  display_usage
	  exit 1
else
      echo "\$K8S_LOCATION is NOT empty"
fi

set -u  # Treat unset variables as an error when substituting
set -e # Exit immediately if a command exits with a non-zero status.


# global configuration 
K8S_NODES=3 # worker nodes and ONE master node
K8S_VM_SIZE=Standard_B2s
K8S_VM_IMAGE=UbuntuLTS
K8S_ADMINUSER=azureuser

if [ "$K8S_OPERATION" = "create" ] ;
then

  ssh-keygen -t rsa -b 4096 -f $HOME/.ssh/k8s_rsa -C "key for k8s on Azure"

    # Create a resource group
  az group create --name "${K8S_RG}" --location ${K8S_LOCATION}

    # Create a virtual network and subnet
  az network vnet create \
        --resource-group ${K8S_RG} \
        --name "vnet_${K8S_NAME}" \
        --address-prefixes 10.0.0.0/8 \
        --subnet-name "subnet_${K8S_NAME}" \
        --subnet-prefix 10.240.0.0/16 # master node should have 10.240.0.4 IP

K8S_SUBNETID=$(az network vnet subnet show --resource-group ${K8S_RG} \
  --name subnet_${K8S_NAME} --vnet-name vnet_${K8S_NAME} --query="id" -o tsv)

echo "K8S_SUBNETID: $K8S_SUBNETID"

  K8S_AVAILABILITYSET="${K8S_NAME}-AvailabilitySet"
  az vm availability-set create \
    --resource-group ${K8S_RG} \
    --name $K8S_AVAILABILITYSET \
    --platform-fault-domain-count 2 \
    --platform-update-domain-count 2

  # master node

  az vm create --name "${K8S_NAME}"-master1 --resource-group ${K8S_RG}  --location ${K8S_LOCATION} \
   --admin-username ${K8S_ADMINUSER} --size ${K8S_VM_SIZE} --image ${K8S_VM_IMAGE} \
   --subnet "subnet_${K8S_NAME}" --vnet-name "vnet_${K8S_NAME}" \
   --availability-set $K8S_AVAILABILITYSET \
   --public-ip-address "" --nsg "" --ssh-key-values ${HOME}/.ssh/k8s_rsa.pub \
   --custom-data ./cloud-init-master.sh #--no-wait

  # worker nodes
#for i in { 1..${K8S_NODES } 
for ((i = 1 ; i <= $K8S_NODES ; i++)); do
   az vm create --name "${K8S_NAME}"-worker"${i}"  --resource-group ${K8S_RG} --location ${K8S_LOCATION} \
     --admin-username ${K8S_ADMINUSER} --size ${K8S_VM_SIZE} --image ${K8S_VM_IMAGE} \
     --subnet "subnet_${K8S_NAME}" --vnet-name "vnet_${K8S_NAME}" \
     --availability-set $K8S_AVAILABILITYSET \
     --public-ip-address "" --nsg "" --ssh-key-values ${HOME}/.ssh/k8s_rsa.pub \
     --custom-data ./cloud-init-node.sh --no-wait
done


# of create
fi # of create



if [ "$K8S_OPERATION" = "start" ] ;
then
  echo "starting VMs...";
  # get the resource group for VMs
  
  echo "K8S_RG: $K8S_RG"
  
  az vm list -d -g $K8S_RG  | grep powerState 
  az vm start --ids $(az vm list -g $K8S_RG --query "[].id" -o tsv) --no-wait
fi # of start
 
if [ "$K8S_OPERATION" = "stop" ] ;
then
echo "stopping VMs...";
echo "K8S_RG: $K8S_RG"
  # get the resource group for VMs
  az vm list -d -g $K8S_RG  | grep powerState

  az vm deallocate --ids $(az vm list -g $K8S_RG --query "[].id" -o tsv) --no-wait
fi # of stop


if [ "$K8S_OPERATION" = "status" ] ;
then
  
  # get the resource group for VMs

  echo "K8S_RG: $K8S_RG"
  
  az vm list -d -g $K8S_RG  | grep powerState 
  
fi  # of status


if [ "$K8S_OPERATION" = "delete" ] ;
then
  echo "Deleting $K8S_RG: "
  az group delete --name $K8S_RG
fi  # of delete

