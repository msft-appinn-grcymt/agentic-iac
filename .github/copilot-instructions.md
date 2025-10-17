# GSIS Agentic IaC – Copilot Agent Instructions

## Mission Overview
This repository provisions secure-by-default Azure landing zones using specification Excel files. The Copilot agent is responsible for translating each request into a deployment script that creates Azure resources following security and networking best practices using Azure CLI commands only.

## Repository Layout & Naming
```
/
├── apps/
│   └── {organization}/
│       └── {project}/
│           └── deployment.sh   # Bash script with Azure CLI commands for workload deployment
├── specs/
│   └── {organization}/
│       └── {project}/
│           └── *.xlsx          # Sheet 1: components, Sheet 2: network & request metadata
└── examples/                   # Reference examples for common resource patterns
```

> ℹ️ **Canonical vocabulary**
> - **organization** identifies the top-level requestor folder under `apps/` and `specs/`.
> - **project** identifies the workload folder nested beneath the organization.
> - The Azure resource group created for the workload must be named `${organization}-${project}` (uppercase preserved from specs).
> - Tag every resource with at least `applicationNumber`, `organization`, `project`, and `environment` (derived from the spec).

## Non-negotiable Guardrails
1. **Private-first networking** – all services must land in hub virtual networks, expose only private endpoints, and integrate with private DNS zones.
2. **No public ingress** – disable public exposure for Storage, SQL, App Services, etc. by configuring private access patterns.
3. **Subnet hygiene** – allocate non-overlapping CIDR ranges, assign NSGs per subnet, and honour the workload-specific subnet mapping from the spec.
4. **Dependency ordering** – resources must be created in the correct order respecting Azure dependencies (e.g., resource group → vnet → subnets → NSGs → private DNS zones → services → private endpoints).
5. **Idempotency** – use Azure CLI commands that can be safely re-run without causing errors or duplicates where possible.
6. **Minimal configuration** – only specify essential arguments based on Excel specs and resource standards; rely on Azure defaults for non-critical settings.

## Azure CLI documentation consultation

### Command reference guidelines
Before generating any Azure CLI command, you MUST consult the official Microsoft documentation to understand the requirements, options, and syntax:

- **Root documentation**: https://learn.microsoft.com/en-us/cli/azure/
- **Service-specific pattern**: https://learn.microsoft.com/en-us/cli/azure/{service}
  - Example for AKS: https://learn.microsoft.com/en-us/cli/azure/aks
  - Example for storage: https://learn.microsoft.com/en-us/cli/azure/storage
  - Example for network: https://learn.microsoft.com/en-us/cli/azure/network
  - Example for keyvault: https://learn.microsoft.com/en-us/cli/azure/keyvault
  - Example for sql: https://learn.microsoft.com/en-us/cli/azure/sql

### Documentation lookup process
1. Identify the Azure service you need to create (e.g., Key Vault, Storage Account, SQL Database)
2. Navigate to the corresponding CLI documentation page using the pattern above
3. Review the available commands, required parameters, and optional flags
4. Understand the dependency requirements (e.g., resource group must exist before creating resources)
5. Apply private networking configurations where applicable

## Resource discovery checklist
Before authoring the deployment script, query Azure (using MCP tooling) for the subscription named in the spec:
- Confirm whether a resource group `${organization}-${project}` already exists; document drift in location or tags.
- Enumerate existing VNets, subnets, private endpoints, and DNS zones to avoid naming or CIDR collisions.
- Surface conflicts or prerequisites in your summary; never overwrite assets unless the spec explicitly permits changes.

## Reading the specification Excel
1. **Sheet 1 – Components** lists resource types, SKUs, instance counts, and optional integrators (e.g., "App Service Plan P1v3 x2"). Group rows by shared characteristics when mapping to CLI commands.
2. **Sheet 2 – Networking** provides request number, region, virtual network address space, per-subnet CIDR blocks, DNS requirements, and integration notes.
3. Cross-check both sheets for consistency (e.g., a Storage account on Sheet 1 must map to a subnet tagged `Storage` on Sheet 2). Raise discrepancies immediately.

## Authoring `apps/{organization}/{project}/deployment.sh`

### Script structure and principles
- Generate a bash script with Azure CLI commands ordered by resource dependencies
- Include error handling with `set -e` to stop on first error
- Use variables at the top of the script for common values (resource group name, location, tags)
- Add comments explaining each resource creation step
- Ensure idempotency where possible using `--only-show-errors` and checking for existing resources
- Only specify essential arguments based on Excel specs and resource standards

### Dependency ordering
Commands must follow this general sequence to respect Azure resource dependencies:

1. **Resource Group** – Foundation for all resources
2. **Network Security Groups** – Must exist before subnet association
3. **Virtual Network & Subnets** – Network foundation with NSG associations
4. **Private DNS Zones** – Required before private endpoints
5. **VNet Links for DNS Zones** – Connect DNS zones to virtual network
6. **Core Services** – Storage accounts, Key Vaults, SQL servers (create without private endpoints first)
7. **Private Endpoints** – Connect services to private DNS zones
8. **Application Services** – App Service Plans, Web Apps with VNet integration
9. **Monitoring** – Log Analytics, Application Insights

### Common resource patterns

#### Resource group creation
```bash
az group create \
  --name "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --tags applicationNumber="${APP_NUMBER}" organization="${ORG}" project="${PROJECT}" environment="${ENV}"
```

#### Network Security Group
```bash
az network nsg create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${NSG_NAME}" \
  --location "${LOCATION}" \
  --tags applicationNumber="${APP_NUMBER}"
```

#### Virtual Network with subnets
```bash
az network vnet create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${VNET_NAME}" \
  --location "${LOCATION}" \
  --address-prefixes "10.0.0.0/16" \
  --subnet-name "default-subnet" \
  --subnet-prefixes "10.0.1.0/24" \
  --tags applicationNumber="${APP_NUMBER}"
```

#### Private DNS Zone
```bash
az network private-dns zone create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "privatelink.vaultcore.azure.net" \
  --tags applicationNumber="${APP_NUMBER}"
```

#### Storage Account (private access)
```bash
az storage account create \
  --name "${STORAGE_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --sku Standard_ZRS \
  --kind StorageV2 \
  --public-network-access Disabled \
  --tags applicationNumber="${APP_NUMBER}"
```

#### Private Endpoint
```bash
az network private-endpoint create \
  --name "${PE_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --subnet "${SUBNET_ID}" \
  --private-connection-resource-id "${RESOURCE_ID}" \
  --group-id "vault" \
  --connection-name "${CONNECTION_NAME}" \
  --tags applicationNumber="${APP_NUMBER}"
```

### Required resource types and key arguments

| Resource Type | CLI Command Base | Essential Arguments | Private Networking Flags |
| --- | --- | --- | --- |
| Resource Group | `az group create` | `--name`, `--location`, `--tags` | N/A |
| Virtual Network | `az network vnet create` | `--resource-group`, `--name`, `--address-prefixes` | N/A |
| Subnet | `az network vnet subnet create` | `--resource-group`, `--vnet-name`, `--name`, `--address-prefixes` | `--network-security-group`, `--service-endpoints` |
| NSG | `az network nsg create` | `--resource-group`, `--name`, `--location` | N/A |
| NSG Rule | `az network nsg rule create` | `--resource-group`, `--nsg-name`, `--name`, `--priority`, `--direction`, `--access` | N/A |
| Private DNS Zone | `az network private-dns zone create` | `--resource-group`, `--name` | N/A |
| DNS VNet Link | `az network private-dns link vnet create` | `--resource-group`, `--zone-name`, `--name`, `--virtual-network` | N/A |
| Storage Account | `az storage account create` | `--name`, `--resource-group`, `--sku`, `--kind` | `--public-network-access Disabled` |
| Key Vault | `az keyvault create` | `--name`, `--resource-group`, `--location` | `--public-network-access Disabled` |
| SQL Server | `az sql server create` | `--name`, `--resource-group`, `--admin-user`, `--admin-password` | `--enable-public-network false` |
| SQL Database | `az sql db create` | `--resource-group`, `--server`, `--name`, `--service-objective` | N/A |
| App Service Plan | `az appservice plan create` | `--name`, `--resource-group`, `--sku` | N/A |
| Web App | `az webapp create` | `--name`, `--resource-group`, `--plan` | `--vnet-integration`, `--https-only` |
| Private Endpoint | `az network private-endpoint create` | `--name`, `--resource-group`, `--subnet`, `--private-connection-resource-id`, `--group-id` | Always used for private access |
| Log Analytics | `az monitor log-analytics workspace create` | `--resource-group`, `--workspace-name`, `--location` | N/A |
| App Insights | `az monitor app-insights component create` | `--app`, `--location`, `--resource-group`, `--workspace` | N/A |

> ⚠️ **Always consult the official Azure CLI documentation** at https://learn.microsoft.com/en-us/cli/azure/{service} for complete parameter schemas, optional flags, and latest syntax.

### Example deployment.sh skeleton
```bash
#!/bin/bash
set -e

# Variables derived from Excel specification
ORG="<organization>"
PROJECT="<project>"
RESOURCE_GROUP="${ORG}-${PROJECT}"
LOCATION="westeurope"
APP_NUMBER="<request number>"
ENV="Prod"

# Common tags
TAGS="applicationNumber=${APP_NUMBER} organization=${ORG} project=${PROJECT} environment=${ENV}"

echo "Creating resource group..."
az group create \
  --name "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --tags ${TAGS}

echo "Creating network security group..."
az network nsg create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${RESOURCE_GROUP}-nsg" \
  --location "${LOCATION}" \
  --tags ${TAGS}

echo "Creating virtual network..."
az network vnet create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${RESOURCE_GROUP}-vnet" \
  --location "${LOCATION}" \
  --address-prefixes "10.10.0.0/16" \
  --subnet-name "default-subnet" \
  --subnet-prefixes "10.10.1.0/24" \
  --tags ${TAGS}

echo "Creating private DNS zone..."
az network private-dns zone create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "privatelink.vaultcore.azure.net" \
  --tags ${TAGS}

echo "Linking DNS zone to VNet..."
VNET_ID=$(az network vnet show --resource-group "${RESOURCE_GROUP}" --name "${RESOURCE_GROUP}-vnet" --query id -o tsv)
az network private-dns link vnet create \
  --resource-group "${RESOURCE_GROUP}" \
  --zone-name "privatelink.vaultcore.azure.net" \
  --name "${RESOURCE_GROUP}-vnet-link" \
  --virtual-network "${VNET_ID}" \
  --registration-enabled false \
  --tags ${TAGS}

echo "Creating Key Vault..."
az keyvault create \
  --name "${RESOURCE_GROUP}-kv" \
  --resource-group "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --public-network-access Disabled \
  --tags ${TAGS}

echo "Creating private endpoint for Key Vault..."
SUBNET_ID=$(az network vnet subnet show --resource-group "${RESOURCE_GROUP}" --vnet-name "${RESOURCE_GROUP}-vnet" --name "default-subnet" --query id -o tsv)
KV_ID=$(az keyvault show --name "${RESOURCE_GROUP}-kv" --query id -o tsv)
az network private-endpoint create \
  --name "${RESOURCE_GROUP}-kv-pe" \
  --resource-group "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --subnet "${SUBNET_ID}" \
  --private-connection-resource-id "${KV_ID}" \
  --group-id "vault" \
  --connection-name "${RESOURCE_GROUP}-kv-connection" \
  --tags ${TAGS}

# Add additional resources following the same pattern...

echo "Deployment complete!"
```

## Translating Excel to Azure CLI commands

| Excel cue | CLI mapping |
| --- | --- |
| `Request Number` (Sheet 2) | Populate `APP_NUMBER` variable and include in `--tags`. |
| `Organization` / `Project` | Used to construct `RESOURCE_GROUP` variable and tags. |
| Subnet table (Sheet 2) | Generate `az network vnet subnet create` commands with appropriate CIDR ranges and NSG associations. |
| Component rows (Sheet 1) | Create corresponding `az` commands capturing SKU, tier, and distinguishing attributes. |
| DNS requirements | Generate private DNS zone creation and virtual-network link commands. |
| SLA or redundancy requirements | Map to service-specific flags (`--sku`, `--zone-redundant`, `--replication-type`). |

Document any assumptions (e.g., defaulting to `ZRS` redundancy) directly in your summary when spec data is missing.

## Deployment workflow
- Author deployment scripts under `apps/{organization}/{project}/deployment.sh`
- Scripts should be executable and contain all necessary Azure CLI commands in dependency order
- Configure CI workflows to execute the deployment script with appropriate Azure authentication
- Ensure scripts are idempotent where possible to support re-runs

## Validation steps before completion
1. Review the generated `deployment.sh` for correct dependency ordering
2. Verify that all resource commands include proper tagging with `applicationNumber`, `organization`, `project`, and `environment`
3. Confirm that private networking flags are set correctly (e.g., `--public-network-access Disabled`)
4. Check that private endpoints are created for all services requiring private connectivity
5. Ensure DNS zones and VNet links are configured for private endpoint resolution
6. Validate that the script includes proper error handling (`set -e`)
7. Document any manual steps required post-deployment (such as certificate uploads or secret configuration)

## Reporting gaps or limitations
- If the Azure CLI lacks a required feature, state the limitation and recommend manual configuration or alternative approaches
- Flag tenant policies (e.g., restricted private endpoint creation) that could block deployment and propose remediation
- Note any manual steps required post-deployment when automation cannot cover them

Keep these instructions current. Review Azure CLI documentation quarterly for new features and capabilities, and document notable changes in this guide.
