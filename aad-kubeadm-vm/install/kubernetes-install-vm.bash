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
      echo "\$K8S_OPERATION :$K8S_OPERATION"
fi

if [ -z "$K8S_NAME" ]
then
      echo "\$K8S_NAME is empty"
	  display_usage
	  exit 1
else
      echo "\$AKS_NAME: $K8S_NAME"
fi

if [ -z "$K8S_RG" ]
then
      echo "\$K8S_RG is empty"
	  display_usage
	  exit 1
else
      echo "\$K8S_RG: $K8S_RG"
fi

if [ -z "$K8S_LOCATION" ]
then
      echo "\$K8S_LOCATION is empty"
	  display_usage
	  exit 1
else
      echo "\$K8S_LOCATION: $K8S_LOCATION"
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

   # Security Group  

   az network nsg create --resource-group ${K8S_RG} --name ${K8S_NAME}

   # Create a firewall rule that allows external SSH, and HTTPS:

    az network nsg rule create \
      --resource-group ${K8S_RG} \
      --nsg-name ${K8S_NAME}\
      --name K8s \
      --access Allow \
      --protocol Tcp \
      --direction Inbound \
      --priority 100 \
      --source-address-prefix "*" \
      --source-port-range "*" \
      --destination-port-ranges 22 6443

    az network nsg rule show --resource-group ${K8S_RG} --name K8s --nsg-name ${K8S_NAME}
  
    az network public-ip create \
      --name ${K8S_NAME}-public-ip \
      --resource-group ${K8S_RG} \
      --allocation-method Static

    az network public-ip show --resource-group ${K8S_RG} --name ${K8S_NAME}-public-ip

    # Provision a Network Load Balancer

    az network lb create \
      --name ${K8S_NAME}-lb \
      --resource-group  ${K8S_RG} \
      --backend-pool-name ${K8S_NAME}-lb-pool \
      --public-ip-address ${K8S_NAME}-public-ip

    az network lb probe create \
      --lb-name ${K8S_NAME}-lb \
      --resource-group  ${K8S_RG} \
      --name ${K8S_NAME}-lb-probe \
      --port 6443 \
      --protocol tcp

    az network lb rule create \
      --resource-group  ${K8S_RG} \
      --lb-name ${K8S_NAME}-lb \
      --name ${K8S_NAME}-lb-rule \
      --protocol tcp \
      --frontend-port 6443 \
      --backend-port 6443 \
      --backend-pool-name ${K8S_NAME}-lb-pool \
      --probe-name ${K8S_NAME}-lb-probe  

    az network lb inbound-nat-rule create \
      -g ${K8S_RG} --lb-name ${K8S_NAME}-lb -n ${K8S_NAME}-lb-nat-rule-ssh \
      --protocol Tcp --frontend-port 30 --backend-port 22

  # master node

    # public IP
    az network public-ip create \
    --name master-1-ip \
    --resource-group ${K8S_RG} \
    --allocation-method Static

    # nic 
    az network nic create \
      --resource-group ${K8S_RG} \
      --name master-1-nic \
      --vnet-name "vnet_${K8S_NAME}" \
      --subnet "subnet_${K8S_NAME}" \
      --network-security-group ${K8S_NAME} \
      --public-ip-address master-1-ip \
      --private-ip-address 10.240.0.4 \
      --lb-name ${K8S_NAME}-lb \
      --lb-address-pools ${K8S_NAME}-lb-pool\
      --ip-forwarding true

    # VM
  az vm create --name "${K8S_NAME}"-master1 --resource-group ${K8S_RG}  --location ${K8S_LOCATION} \
   --admin-username ${K8S_ADMINUSER} --size ${K8S_VM_SIZE} --image ${K8S_VM_IMAGE} \
   --availability-set $K8S_AVAILABILITYSET \
   --nics master-1-nic \
   --ssh-key-values ${HOME}/.ssh/k8s_rsa.pub \
   --custom-data ./cloud-init-master.sh #--no-wait

  # worker nodes

# public IPs
  for ((i = 1 ; i <= $K8S_NODES ; i++)); do
      az network public-ip create \
      --name worker-${i}-ip \
      --resource-group ${K8S_RG} \
      --allocation-method Static
    done

  # nics
  for ((i = 1 ; i <= $K8S_NODES ; i++)); do
    az network nic create \
      --resource-group ${K8S_RG} \
      --name worker-${i}-nic \
      --vnet-name "vnet_${K8S_NAME}" \
      --subnet "subnet_${K8S_NAME}" \
      --public-ip-address worker-${i}-ip \
      --private-ip-address 10.240.0.1${i} \
      --lb-name ${K8S_NAME}-lb \
      --lb-address-pools ${K8S_NAME}-lb-pool\
      --ip-forwarding true
  done

  # VMs

  for ((i = 1 ; i <= $K8S_NODES ; i++)); do
    az vm create --name "${K8S_NAME}"-worker"${i}"  --resource-group ${K8S_RG} --location ${K8S_LOCATION} \
      --admin-username ${K8S_ADMINUSER} --size ${K8S_VM_SIZE} --image ${K8S_VM_IMAGE} \
      --availability-set $K8S_AVAILABILITYSET \
      --nics worker-${i}-nic \
      --ssh-key-values ${HOME}/.ssh/k8s_rsa.pub \
      --custom-data ./cloud-init-node.sh \
      --data-disk-sizes-gb 20 --no-wait
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
  az vm list -g $K8S_RG --query "[].id" -o tsv
  az vm deallocate --ids "$(az vm list -g $K8S_RG --query "[].id" -o tsv)" --no-wait
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

