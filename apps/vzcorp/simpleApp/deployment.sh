#!/bin/bash
set -e

# Variables derived from Excel specification
ORG="vzcorp"
PROJECT="simpleApp"
RESOURCE_GROUP="${ORG}-${PROJECT}"
LOCATION="westeurope"
APP_NUMBER="simpleApp"
ENV="Prod"

# Network configuration from specification
VNET_ADDRESS_PREFIX="192.168.2.0/24"
APP_SERVICE_SUBNET_PREFIX="192.168.2.0/27"
PRIVATE_ENDPOINTS_SUBNET_PREFIX="192.168.2.32/27"

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

echo "Creating subnet for App Service VNet integration with delegation..."
az network vnet subnet create \
  --resource-group "${RESOURCE_GROUP}" \
  --vnet-name "${RESOURCE_GROUP}-vnet" \
  --name "app-service-subnet" \
  --address-prefixes "${APP_SERVICE_SUBNET_PREFIX}" \
  --network-security-group "${RESOURCE_GROUP}-nsg" \
  --delegations "Microsoft.Web/serverFarms" \
  --only-show-errors

echo "Creating subnet for private endpoints..."
az network vnet subnet create \
  --resource-group "${RESOURCE_GROUP}" \
  --vnet-name "${RESOURCE_GROUP}-vnet" \
  --name "private-endpoints-subnet" \
  --address-prefixes "${PRIVATE_ENDPOINTS_SUBNET_PREFIX}" \
  --network-security-group "${RESOURCE_GROUP}-nsg" \
  --only-show-errors

echo "Creating private DNS zone for Storage Account..."
az network private-dns zone create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "privatelink.blob.core.windows.net" \
  --tags ${TAGS} \
  --only-show-errors

echo "Creating private DNS zone for Web Apps..."
az network private-dns zone create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "privatelink.azurewebsites.net" \
  --tags ${TAGS} \
  --only-show-errors

echo "Linking Storage DNS zone to VNet..."
VNET_ID=$(az network vnet show \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${RESOURCE_GROUP}-vnet" \
  --query id \
  --output tsv)

az network private-dns link vnet create \
  --resource-group "${RESOURCE_GROUP}" \
  --zone-name "privatelink.blob.core.windows.net" \
  --name "${RESOURCE_GROUP}-storage-vnet-link" \
  --virtual-network "${VNET_ID}" \
  --registration-enabled false \
  --tags ${TAGS} \
  --only-show-errors

echo "Linking Web App DNS zone to VNet..."
az network private-dns link vnet create \
  --resource-group "${RESOURCE_GROUP}" \
  --zone-name "privatelink.azurewebsites.net" \
  --name "${RESOURCE_GROUP}-webapp-vnet-link" \
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
PRIVATE_ENDPOINTS_SUBNET_ID=$(az network vnet subnet show \
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
  --subnet "${PRIVATE_ENDPOINTS_SUBNET_ID}" \
  --private-connection-resource-id "${STORAGE_ID}" \
  --group-id "blob" \
  --connection-name "${STORAGE_NAME}-connection" \
  --tags ${TAGS} \
  --only-show-errors

echo "Creating private DNS zone group for Storage private endpoint..."
STORAGE_PRIVATE_DNS_ZONE_ID=$(az network private-dns zone show \
  --resource-group "${RESOURCE_GROUP}" \
  --name "privatelink.blob.core.windows.net" \
  --query id \
  --output tsv)

az network private-endpoint dns-zone-group create \
  --resource-group "${RESOURCE_GROUP}" \
  --endpoint-name "${STORAGE_NAME}-pe" \
  --private-dns-zone "${STORAGE_PRIVATE_DNS_ZONE_ID}" \
  --zone-name "blob" \
  --name "default" \
  --only-show-errors

echo "Creating App Service Plan..."
APP_SERVICE_PLAN_NAME="${RESOURCE_GROUP}-plan"

az appservice plan create \
  --name "${APP_SERVICE_PLAN_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --sku P0V3 \
  --is-linux \
  --tags ${TAGS} \
  --only-show-errors

echo "Creating Web App..."
WEB_APP_NAME="${RESOURCE_GROUP}-app"

az webapp create \
  --name "${WEB_APP_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --plan "${APP_SERVICE_PLAN_NAME}" \
  --deployment-container-image-name "mcr.microsoft.com/appsvc/staticsite:latest" \
  --tags ${TAGS} \
  --only-show-errors

echo "Configuring Web App to disable public access..."
az webapp config access-restriction add \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${WEB_APP_NAME}" \
  --rule-name "DenyAll" \
  --action Deny \
  --priority 100 \
  --only-show-errors

echo "Integrating Web App with VNet..."
az webapp vnet-integration add \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${WEB_APP_NAME}" \
  --vnet "${RESOURCE_GROUP}-vnet" \
  --subnet "app-service-subnet" \
  --only-show-errors

echo "========================================"
echo "Deployment complete!"
echo "========================================"
echo "Resource Group: ${RESOURCE_GROUP}"
echo "Location: ${LOCATION}"
echo "Storage Account: ${STORAGE_NAME}"
echo "App Service Plan: ${APP_SERVICE_PLAN_NAME} (Premium V3, P0V3)"
echo "Web App: ${WEB_APP_NAME}"
echo "VNet: ${RESOURCE_GROUP}-vnet (${VNET_ADDRESS_PREFIX})"
echo "  - App Service subnet: app-service-subnet (${APP_SERVICE_SUBNET_PREFIX})"
echo "  - Private endpoints subnet: private-endpoints-subnet (${PRIVATE_ENDPOINTS_SUBNET_PREFIX})"
echo "========================================"
