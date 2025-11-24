#! /bin/bash

export CLUSTER_NAME=$1
export RESOURCE_GROUP=$2
export ACR_NAME=$3
export SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Check if resource group exists
echo "Checking if resource group '$RESOURCE_GROUP' exists..."
if ! $(az group exists -n $RESOURCE_GROUP); then
    echo "Error: Resource group '$RESOURCE_GROUP' not found"
    exit 1
fi
echo "Resource group '$RESOURCE_GROUP' found."

# Check if ACR exists
echo "Checking if ACR '$ACR_NAME' exists..."
if ! az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP &>/dev/null; then
    echo "Error: ACR '$ACR_NAME' not found in resource group '$RESOURCE_GROUP'"
    exit 1
fi
echo "ACR '$ACR_NAME' found."

# Get the IoT Operations extension managed identity
extOid=$(az k8s-extension list --cluster-name $CLUSTER_NAME -g $RESOURCE_GROUP --cluster-type connectedClusters --query "[?extensionType=='microsoft.iotoperations'].identity.principalId" -o tsv)
# Get the application ID for the managed identity
sysId=$(az ad sp show --id $extOid --query "appId" -o tsv)
# Assign the AcrPull role to the managed identity
az role assignment create --role "AcrPull" --assignee $sysId --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerRegistry/registries/$ACR_NAME"
