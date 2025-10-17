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

## VNET Address Range Management

### Overview
The `network/networkRanges.csv` file tracks available and allocated IP address ranges (CIDRs) across all deployments. This file is critical for preventing IP address conflicts and ensuring proper network planning.

### File Structure
The CSV file contains two columns:
- **Full CIDR**: The complete available address space (currently one range, but more may be added in the future)
- **Used CIDRs**: Individual CIDR blocks already allocated to existing deployments (one per row)

### CIDR Allocation Process

#### 1. Calculate Required IP Addresses
Before selecting a CIDR range, calculate the total IP addresses needed based on:
- Number of resources requiring IP addresses (VMs, App Service integrations, private endpoints, etc.)
- Number of subnets required
- Reserved Azure addresses per subnet (5 IPs: network address, default gateway, Azure DNS, and broadcast)

#### 2. Apply 50% Buffer Rule
**ALWAYS add 50% more capacity** to accommodate future scaling and growth.

**Example calculation:**
- If you need 4 VMs → requires 4 IPs
- Add 50% buffer → 4 + (4 × 0.5) = 6 IPs minimum
- Account for Azure reserved IPs → 6 + 5 = 11 IPs total
- Required subnet size → /28 (16 IPs) or larger

#### 3. Subnet Delegation Requirements
When network delegation is required for specific Azure services (e.g., Azure Container Instances, App Service, Azure SQL Managed Instance):
- **Minimum subnet size is /28** (16 IP addresses)
- **ALWAYS consult the official Microsoft documentation** for the specific service to determine:
  - Minimum acceptable subnet size
  - Maximum subnet size
  - Additional subnet requirements or restrictions
  - Service-specific delegation configuration

**Documentation lookup pattern:**
- Search for: "Azure [service-name] subnet requirements"
- Example: https://learn.microsoft.com/en-us/azure/app-service/overview-vnet-integration#subnet-requirements

#### 4. Select Non-Overlapping CIDR
1. Read the `network/networkRanges.csv` file
2. Review the "Full CIDR" column to understand available address space
3. Review all entries in the "Used CIDRs" column to avoid conflicts
4. Select a CIDR block that:
   - Does NOT overlap with any used CIDR
   - Is large enough for your calculated requirements (including 50% buffer)
   - Allows for subnet segmentation if multiple subnets are needed

#### 5. Update networkRanges.csv
After selecting your CIDR range, you MUST update the file:
- Add a new row in the "Used CIDRs" column with the allocated CIDR
- Include this update as part of your deployment commit
- Document the CIDR allocation in your deployment summary

### Common Subnet Sizes Reference

| Subnet Mask | CIDR | Total IPs | Usable IPs (minus 5 Azure reserved) | Typical Use Case |
|-------------|------|-----------|-------------------------------------|------------------|
| /28 | x.x.x.x/28 | 16 | 11 | Small delegated subnet, few resources |
| /27 | x.x.x.x/27 | 32 | 27 | Medium subnet with delegation |
| /26 | x.x.x.x/26 | 64 | 59 | Larger workloads |
| /25 | x.x.x.x/25 | 128 | 123 | Multiple services or VMs |
| /24 | x.x.x.x/24 | 256 | 251 | Standard subnet for most workloads |
| /23 | x.x.x.x/23 | 512 | 507 | Large subnet for scaling |
| /22 | x.x.x.x/22 | 1024 | 1019 | Very large workloads |

### CIDR Allocation Example

**Scenario:** Deploying 3 web apps with VNet integration and 2 private endpoints

**Calculation:**
1. Web apps with VNet integration: 3 IPs
2. Private endpoints: 2 IPs
3. Total required: 5 IPs
4. Add 50% buffer: 5 + (5 × 0.5) = 7.5 → round up to 8 IPs
5. Azure reserved: 8 + 5 = 13 IPs
6. Minimum subnet: /28 (16 IPs)
7. Since App Service VNet integration requires delegation, verify minimum size in docs
8. Selected CIDR: 192.168.1.0/28 (assuming 192.168.0.0/24 is already used)

**Update to networkRanges.csv:**
```csv
Full CIDR,Used CIDRs
192.168.0.0/16,192.168.0.0/24
192.168.0.0/16,192.168.1.0/28
```

### Validation Checklist
- [ ] Calculated total IP requirements including all resources
- [ ] Applied 50% buffer for scaling
- [ ] Checked subnet delegation requirements in official Microsoft docs
- [ ] Verified no overlap with existing CIDRs in networkRanges.csv
- [ ] Selected appropriate subnet size (minimum /28 for delegated subnets)
- [ ] Updated networkRanges.csv with the new allocation
- [ ] Documented CIDR allocation in deployment summary

## Reading the specification Excel
1. **Sheet 1 – Components** lists resource types, SKUs, instance counts, and optional integrators (e.g., "App Service Plan P1v3 x2"). Group rows by shared characteristics when mapping to CLI commands.
2. **Metadata fields** – Extract the request number, organization, project name, region, and environment from the specification to populate script variables and resource tags.
3. **Network allocation** – All virtual network CIDR ranges and subnet allocations MUST be determined from the available ranges in `network/networkRanges.csv`, following the VNET Address Range Management process defined above. Never use arbitrary or hardcoded CIDR ranges.

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

## Translating specification to Azure CLI commands

| Specification element | CLI mapping |
| --- | --- |
| `Request Number` | Populate `APP_NUMBER` variable and include in `--tags`. |
| `Organization` / `Project` | Used to construct `RESOURCE_GROUP` variable and tags. |
| `Region` / `Location` | Map to `--location` parameter for all resource creation commands. |
| Component rows (Sheet 1) | Create corresponding `az` commands capturing SKU, tier, and distinguishing attributes. |
| Network requirements | Allocate CIDR ranges from `network/networkRanges.csv` following the VNET Address Range Management process; generate `az network vnet subnet create` commands with calculated CIDR ranges and NSG associations. |
| DNS requirements | Generate private DNS zone creation and virtual-network link commands. |
| SLA or redundancy requirements | Map to service-specific flags (`--sku`, `--zone-redundant`, `--replication-type`). |

Document any assumptions (e.g., defaulting to `ZRS` redundancy, selected CIDR allocation from networkRanges.csv) directly in your summary when spec data is missing.

## Service-specific instructions

### App Service (Web Apps)

#### Default runtime configuration
Unless explicitly specified in the GitHub Issue or specification, App Service instances MUST use the default Docker container runtime:
- **Container image**: `mcr.microsoft.com/appsvc/staticsite:latest`
- **Deployment method**: Docker container from Microsoft Container Registry

If a specific runtime is mentioned in the Issue (e.g., "Node.js 18", "Python 3.11", ".NET 8"), use the `--runtime` parameter instead of `--deployment-container-image-name`.

#### VNet integration
When configuring VNet integration for App Service, ALWAYS use the  **az webapp vnet-integration add** command.Provide the `--vnet` and `--subnet` parameters with the respective **names** of the vnet and subnet, not the full resource ids. Public access should be set to `Disabled`, no firewall rules to be allowed and ensure private endpoint creation for secure access.

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
