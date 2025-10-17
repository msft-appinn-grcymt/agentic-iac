#!/bin/bash
set -e

# Variables derived from Excel specification
ORG="vzcorp"
PROJECT="agentsAssemble"
RESOURCE_GROUP="${ORG}-${PROJECT}"
LOCATION="westeurope"
APP_NUMBER="agentsAssemble"
ENV="Prod"

# Network configuration from specification
VNET_ADDRESS_PREFIX="192.168.0.0/24"
SUBNET_ADDRESS_PREFIX="192.168.0.0/24"

# Common tags
TAGS="applicationNumber=${APP_NUMBER} organization=${ORG} project=${PROJECT} environment=${ENV}"

echo "========================================"
echo "Deploying infrastructure for ${ORG}/${PROJECT}"
echo "========================================"

echo "Creating resource group..."
az group create \
  --name "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --tags ${TAGS} \
  --only-show-errors

echo "Creating network security group..."
az network nsg create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${RESOURCE_GROUP}-nsg" \
  --location "${LOCATION}" \
  --tags ${TAGS} \
  --only-show-errors

echo "Creating virtual network..."
az network vnet create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${RESOURCE_GROUP}-vnet" \
  --location "${LOCATION}" \
  --address-prefixes "${VNET_ADDRESS_PREFIX}" \
  --tags ${TAGS} \
  --only-show-errors

echo "Creating subnet for private endpoints..."
az network vnet subnet create \
  --resource-group "${RESOURCE_GROUP}" \
  --vnet-name "${RESOURCE_GROUP}-vnet" \
  --name "private-endpoints-subnet" \
  --address-prefixes "${SUBNET_ADDRESS_PREFIX}" \
  --network-security-group "${RESOURCE_GROUP}-nsg" \
  --only-show-errors

echo "Creating private DNS zone for Storage Account..."
az network private-dns zone create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "privatelink.blob.core.windows.net" \
  --tags ${TAGS} \
  --only-show-errors

echo "Linking DNS zone to VNet..."
VNET_ID=$(az network vnet show \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${RESOURCE_GROUP}-vnet" \
  --query id \
  --output tsv)

az network private-dns link vnet create \
  --resource-group "${RESOURCE_GROUP}" \
  --zone-name "privatelink.blob.core.windows.net" \
  --name "${RESOURCE_GROUP}-vnet-link" \
  --virtual-network "${VNET_ID}" \
  --registration-enabled false \
  --tags ${TAGS} \
  --only-show-errors

echo "Creating Storage Account..."
# Generate unique storage account name (lowercase alphanumeric, max 24 chars)
STORAGE_NAME=$(echo "${ORG}${PROJECT}sa" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g' | cut -c1-24)

az storage account create \
  --name "${STORAGE_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --sku Standard_ZRS \
  --kind StorageV2 \
  --access-tier Hot \
  --public-network-access Disabled \
  --tags ${TAGS} \
  --only-show-errors

echo "Creating private endpoint for Storage Account..."
SUBNET_ID=$(az network vnet subnet show \
  --resource-group "${RESOURCE_GROUP}" \
  --vnet-name "${RESOURCE_GROUP}-vnet" \
  --name "private-endpoints-subnet" \
  --query id \
  --output tsv)

STORAGE_ID=$(az storage account show \
  --name "${STORAGE_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --query id \
  --output tsv)

az network private-endpoint create \
  --name "${STORAGE_NAME}-pe" \
  --resource-group "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --subnet "${SUBNET_ID}" \
  --private-connection-resource-id "${STORAGE_ID}" \
  --group-id "blob" \
  --connection-name "${STORAGE_NAME}-connection" \
  --tags ${TAGS} \
  --only-show-errors

echo "Creating private DNS zone group for Storage private endpoint..."
az network private-endpoint dns-zone-group create \
  --resource-group "${RESOURCE_GROUP}" \
  --endpoint-name "${STORAGE_NAME}-pe" \
  --name "default" \
  --private-dns-zone "privatelink.blob.core.windows.net" \
  --zone-name "blob" \
  --only-show-errors

echo "========================================"
echo "Deployment complete!"
echo "========================================"
echo "Resource Group: ${RESOURCE_GROUP}"
echo "Location: ${LOCATION}"
echo "Storage Account: ${STORAGE_NAME}"
echo "VNet: ${RESOURCE_GROUP}-vnet (${VNET_ADDRESS_PREFIX})"
echo "Subnet: private-endpoints-subnet (${SUBNET_ADDRESS_PREFIX})"
echo "========================================"
