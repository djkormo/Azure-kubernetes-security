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
	echo -e "bash $me -n aks-security2020 -g aks-rg -l northeurope -o create" 
	echo -e "bash $me -n aks-security2020 -g aks-rg -l northeurope -o stop" 
	echo -e "bash $me -n aks-security2020 -g aks-rg -l northeurope -o start" 
	echo -e "bash $me -n aks-security2020 -g aks-rg -l northeurope -o status" 
	echo -e "bash $me -n aks-security2020 -g aks-rg -l northeurope -o delete" 
	} 

while getopts n:g:o:l: option
do
case "${option}"
in
n) AKS_NAME=${OPTARG};;
g) AKS_RG=${OPTARG};;
o) AKS_OPERATION=${OPTARG};;
l) AKS_LOCATION=${OPTARG};;
esac
done


if [ -z "$AKS_OPERATION" ]
then
      echo "\$AKS_OPERATION is empty"
	  display_usage
	  exit 1
else
      echo "\$AKS_OPERATION is NOT empty"
fi

if [ -z "$AKS_NAME" ]
then
      echo "\$AKS_NAME is empty"
	  display_usage
	  exit 1
else
      echo "\$AKS_NAME is NOT empty"
fi

if [ -z "$AKS_RG" ]
then
      echo "\$AKS_RG is empty"
	  display_usage
	  exit 1
else
      echo "\$AKS_RG is NOT empty"
fi

if [ -z "$AKS_LOCATION" ]
then
      echo "\$AKS_LOCATION is empty"
	  display_usage
	  exit 1
else
      echo "\$AKS_LOCATION is NOT empty"
fi

set -u  # Treat unset variables as an error when substituting
set -e # Exit immediately if a command exits with a non-zero status.


az aks get-versions -l ${AKS_LOCATION}  # --query 'orchestrators[-1].orchestratorVersion' -o tsv

AKS_VERSION=$(az aks get-versions -l ${AKS_LOCATION} --query 'orchestrators[-1].orchestratorVersion' -o tsv)

AKS_NODES=2
AKS_VM_SIZE=Standard_B2s

echo "AKS_RG: $AKS_RG"
echo "AKS_NAME: $AKS_NAME"
echo "AKS_LOCATION: $AKS_LOCATION"
echo "AKS_NODES: $AKS_NODES"
echo "AKS_VERSION: $AKS_VERSION"
echo "AKS_VM_SIZE: $AKS_VM_SIZE"

ACR_NAME="acr${RANDOM}"

if [ "$AKS_OPERATION" = "create" ] ;
then

    echo "Creating AKS cluster...";

    # https://www.skylinesacademy.com/blog/2020/6/11/new-and-improved-method-of-integrating-azure-ad-in-azure-kubernetes-service-aks-preview

    az extension add --name aks-preview
    az feature register --name AAD-V2 --namespace Microsoft.ContainerService 

    sleep 15

    az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/AAD-V2')].{Name:name,State:properties.state}"

    az provider register --namespace Microsoft.ContainerService 


    # Create a resource group
    az group create --name "${AKS_RG}" --location ${AKS_LOCATION}

    # Create a virtual network and subnet
    az network vnet create \
        --resource-group ${AKS_RG} \
        --name "vnet_${AKS_NAME}" \
        --address-prefixes 10.0.0.0/8 \
        --subnet-name "subnet_${AKS_NAME}" \
        --subnet-prefix 10.240.0.0/16

   az network vnet list --resource-group ${AKS_RG} -o table

    # Create a service principal and read in the application ID
    SP=$(az ad sp create-for-rbac --output json)
    SP_ID=$(echo $SP | jq -r .appId)
    SP_PASSWORD=$(echo $SP | jq -r .password)

    # Wait 15 seconds to make sure that service principal has propagated
    echo "Waiting for service principal to propagate..."
    sleep 15

    # https://docs.microsoft.com/en-us/azure/aks/managed-aad

     az ad group create --display-name "${AKS_NAME}AdminGroup" --mail-nickname "${AKS_NAME}AdminGroup"

     az ad group list --filter "displayname eq '${AKS_NAME}AdminGroup'" -o table

     # get group id to  $GROUP_ID variable

     GROUP_ID=$(az ad group list --display-name "${AKS_NAME}AdminGroup" -o json | grep -i objectid | awk '{print $2}'| tr "," " " | tr "\"" " " )
     
     TENANT_ID=$(az account show --query tenantId --output tsv) 
    
     # Get the virtual network resource ID
     VNET_ID=$(az network vnet show --resource-group $AKS_RG --name "vnet_$AKS_NAME" --query id -o tsv)

    # Assign the service principal Contributor permissions to the virtual network resource
    az role assignment create --assignee $SP_ID --scope $VNET_ID --role Contributor

    # Get the virtual network subnet resource ID
    SUBNET_ID=$(az network vnet subnet show --resource-group $AKS_RG --vnet-name "vnet_$AKS_NAME" --name "subnet_${AKS_NAME}" --query id -o tsv)

    # Create the AKS cluster and specify the virtual network and service principal information
    # Enable network policy by using the `--network-policy` parameter
    az aks create \
        --resource-group $AKS_RG \
        --name $AKS_NAME \
        --vm-set-type AvailabilitySet \
        --enable-addons monitoring \
        --kubernetes-version $AKS_VERSION \
        --node-vm-size $AKS_VM_SIZE \
        --node-count $AKS_NODES \
        --generate-ssh-keys \
        --network-plugin azure \
        --max-pods 110 \
        --service-cidr 10.0.0.0/16 \
        --dns-service-ip 10.0.0.10 \
        --docker-bridge-address 172.17.0.1/16 \
        --vnet-subnet-id $SUBNET_ID \
        --service-principal $SP_ID \
        --client-secret $SP_PASSWORD \
        --network-policy calico \
        --enable-aad --aad-admin-group-object-ids $GROUP_ID --aad-tenant-id $TENANT_ID

    # turn on psp
    #az aks update \
    #    --resource-group $AKS_RG \
    #    --name $AKS_NAME \
    #    --enable-pod-security-policy
    # turn off psp
    #az aks update \
    #    --resource-group $AKS_RG \
    #    --name $AKS_NAME \
    #    --disable-pod-security-policy


   echo "ACR_NAME: $ACR_NAME"
   # create Azure Container Registry 
   az acr create  --name $ACR_NAME --sku Basic --resource-group $AKS_RG

   # turn on admin account
   az acr update -n  $ACR_NAME --admin-enabled true


     # 1. Grant the AKS-generated service principal pull access to our ACR, the AKS cluster will be able to pull images of our ACR

    CLIENT_ID=$(az aks show -g $AKS_RG -n $AKS_NAME --query "servicePrincipalProfile.clientId" -o tsv)
    ACR_ID=$(az acr show -n $ACR_NAME -g $AKS_RG --query "id" -o tsv)
    az role assignment create --assignee $CLIENT_ID --role acrpull --scope $ACR_ID

		
     # 2. Grant for Azure Devops to push to ACR 	
    registryPassword=$(az ad sp create-for-rbac -n $ACR_NAME-push --scopes $ACR_ID --role acrpush --query password -o tsv)
    registryName=$(az acr show -n $ACR_NAME -g $AKS_RG --query name)
    registryLogin=$(az ad sp show --id http://$ACR_NAME-push --query appId -o tsv)

    # 3. Add public static IP for ingress controller     
    RG_VM_POOL=$(az aks show -g $AKS_RG -n $AKS_NAME --query nodeResourceGroup -o tsv)
    echo $RG_VM_POOL
    az network public-ip create --resource-group $RG_VM_POOL --name myIngressPublicIP \
      --dns-name myingress --sku Standard --allocation-method static --query publicIp.ipAddress -o tsv

    az network public-ip list --resource-group $RG_VM_POOL --query "[?name=='myIngressPublicIP'].[dnsSettings.fqdn]" -o tsv


     # optionally add myself to admin group 

     USER_ID=$(az ad user show --id kormo_gos.pl#EXT#@ITSpec340.onmicrosoft.com --query objectId --output tsv)  

     az ad group member add --group "${AKS_NAME}AdminGroup" --member-id $USER_ID

fi # of create



if [ "$AKS_OPERATION" = "start" ] ;
then
echo "starting VMs...";
  # get the resource group for VMs
  
  RG_VM_POOL=$(az aks show -g $AKS_RG -n $AKS_NAME --query nodeResourceGroup -o tsv)
  echo "RG_VM_POOL: $RG_VM_POOL"
  
  az vm list -d -g $RG_VM_POOL  | grep powerState 
  az vm start --ids $(az vm list -g $RG_VM_POOL --query "[].id" -o tsv) --no-wait
fi
 
if [ "$AKS_OPERATION" = "stop" ] ;
then
echo "stopping VMs...";
  # get the resource group for VMs
  RG_VM_POOL=$(az aks show -g $AKS_RG -n $AKS_NAME --query nodeResourceGroup -o tsv)

  echo "RG_VM_POOL: $RG_VM_POOL"

  az vm list -d -g $RG_VM_POOL  | grep powerState

  az vm deallocate --ids $(az vm list -g $RG_VM_POOL --query "[].id" -o tsv) --no-wait
fi


if [ "$AKS_OPERATION" = "status" ] ;
then
  echo "AKS cluster status"
  az aks show --name $AKS_NAME --resource-group $AKS_RG
  
  # get the resource group for VMs
  RG_VM_POOL=$(az aks show -g $AKS_RG -n $AKS_NAME --query nodeResourceGroup -o tsv)
  echo "RG_VM_POOL: $RG_VM_POOL"
  
  az vm list -d -g $RG_VM_POOL  | grep powerState 
  
fi 


if [ "$AKS_OPERATION" = "delete" ] ;
then
  echo "AKS cluster deleting ";
  az aks delete --name $AKS_NAME --resource-group $AKS_RG
  az acr delete --name $ACR_NAME --resource-group $AKS_RG
fi 

