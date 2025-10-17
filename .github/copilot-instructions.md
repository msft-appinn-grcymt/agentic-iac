# GSIS Agentic IaC – Copilot Agent Instructions# GSIS Agentic IaC – Copilot Agent Instructions



## Mission Overview## Mission Overview

This repository provisions secure-by-default Azure landing zones using specification Excel files. The Copilot agent is responsible for translating each request into a deployment script that creates Azure resources following security and networking best practices.This repository provisions secure-by-default Azure landing zones using specification Excel files. The Copilot agent is responsible for translating each request into a deployment script that creates Azure resources following security and networking best practices.



## Repository Layout & Naming## Repository Layout & Naming

``````

//

├── apps/├── apps/

│   └── {organization}/│   └── {organization}/

│       └── {project}/│       └── {project}/

│           └── deployment.sh   # Bash script with Azure CLI commands for workload deployment│           └── deployment.sh   # Bash script with Azure CLI commands for workload deployment

├── specs/├── specs/

│   └── {organization}/│   └── {organization}/

│       └── {project}/│       └── {project}/

│           └── *.xlsx          # Sheet 1: components, Sheet 2: network & request metadata│           └── *.xlsx          # Sheet 1: components, Sheet 2: network & request metadata

└── examples/                   # Reference examples for common resource patterns└── examples/                   # Reference examples for common resource patterns

``````



> ℹ️ **Canonical vocabulary**> ℹ️ **Canonical vocabulary**

> - **organization** identifies the top-level requestor folder under `apps/` and `specs/`.> - **organization** identifies the top-level requestor folder under `apps/` and `specs/`.

> - **project** identifies the workload folder nested beneath the organization.> - **project** identifies the workload folder nested beneath the organization.

> - The Azure resource group created for the workload must be named `${organization}-${project}` (uppercase preserved from specs).> - The Azure resource group created for the workload must be named `${organization}-${project}` (uppercase preserved from specs).

> - Tag every resource with at least `applicationNumber`, `organization`, `project`, and `environment` (derived from the spec).> - Tag every resource with at least `applicationNumber`, `organization`, `project`, and `environment` (derived from the spec).



## Non-negotiable Guardrails## Non-negotiable Guardrails

1. **Private-first networking** – all services must land in hub virtual networks, expose only private endpoints, and integrate with private DNS zones.1. **Private-first networking** – all services must land in hub virtual networks, expose only private endpoints, and integrate with private DNS zones.

2. **No public ingress** – disable public exposure for Storage, SQL, App Services, etc. by configuring private access patterns.2. **No public ingress** – disable public exposure for Storage, SQL, App Services, etc. by configuring private access patterns.

3. **Subnet hygiene** – allocate non-overlapping CIDR ranges, assign NSGs per subnet, and honour the workload-specific subnet mapping from the spec.3. **Subnet hygiene** – allocate non-overlapping CIDR ranges, assign NSGs per subnet, and honour the workload-specific subnet mapping from the spec.

4. **Dependency ordering** – resources must be created in the correct order respecting Azure dependencies (e.g., resource group → vnet → subnets → NSGs → private DNS zones → services → private endpoints).4. **Dependency ordering** – resources must be created in the correct order respecting Azure dependencies (e.g., resource group → vnet → subnets → NSGs → private DNS zones → services → private endpoints).

5. **Idempotency** – use Azure CLI commands that can be safely re-run without causing errors or duplicates where possible.5. **Idempotency** – use Azure CLI commands that can be safely re-run without causing errors or duplicates where possible.

6. **Minimal configuration** – only specify essential arguments based on Excel specs and resource standards; rely on Azure defaults for non-critical settings.6. **Minimal configuration** – only specify essential arguments based on Excel specs and resource standards; rely on Azure defaults for non-critical settings.



## Azure CLI documentation consultation## Azure CLI documentation consultation



### Command reference guidelines### Terraform Registry search tips

Before generating any Azure CLI command, you MUST consult the official Microsoft documentation to understand the requirements, options, and syntax:- Start from the AVM Terraform page for  resources: https://azure.github.io/Azure-Verified-Modules/indexes/terraform/tf-resource-modules/ Find the respective link to terraform registry based on the Display Name and the resource type you want to deploy

- Open the respective link to terraform registry based on the Display Name and the resource type you want to deploy.Use the `latest` tab (for example `https://registry.terraform.io/modules/Azure/avm-res-storage-storageaccount/azurerm/latest`)

- **Root documentation**: `https://learn.microsoft.com/en-us/cli/azure/`- Get the latest version number to use from the "Provision Instructions" section of the page.

- **Service-specific pattern**: `https://learn.microsoft.com/en-us/cli/azure/{service}`- View usage and examples

  - Example for AKS: `https://learn.microsoft.com/en-us/cli/azure/aks`- Always use the latest version for each module you reference.

  - Example for storage: `https://learn.microsoft.com/en-us/cli/azure/storage`

  - Example for network: `https://learn.microsoft.com/en-us/cli/azure/network`### Official AVM index catalogues

- **Terraform resources**: `https://azure.github.io/Azure-Verified-Modules/indexes/terraform/tf-resource-modules/`

### Documentation lookup process- **Terraform patterns**: `https://azure.github.io/Azure-Verified-Modules/indexes/terraform/tf-pattern-modules/`

1. Identify the Azure service you need to create (e.g., Key Vault, Storage Account, SQL Database)

2. Navigate to the corresponding CLI documentation page

3. Review the available commands, required parameters, and optional flags### Bootstrapping Terraform usage from examples

4. Understand the dependency requirements (e.g., resource group must exist before creating resources)1. Start with the example provided in the module documentation.

5. Apply private networking configurations where applicable2. Replace any relative `source = "../../"` style paths with the registry reference `source = "Azure/avm-res-{service}-{resource}/azurerm"` (or the appropriate pattern module path).

3. Add an explicit `version = "x.y.z"`, where `x.y.z` is the latest **available** release retrieved from `https://registry.terraform.io/v1/modules/Azure/<module>/azurerm/versions`. In the JSON response all the module versions are returned as an array ("versions"), you need to retrieve the version from the last item in the array as this depicts the latest version.

## Resource discovery checklist4. Set `enable_telemetry = true` so usage metrics continue to inform AVM improvements.

Before authoring the deployment script, query Azure (using MCP tooling) for the subscription named in the spec:

- Confirm whether a resource group `${organization}-${project}` already exists; document drift in location or tags.### Module source references

- Enumerate existing VNets, subnets, private endpoints, and DNS zones to avoid naming or CIDR collisions.- **Terraform Registry URL pattern**: `https://registry.terraform.io/modules/Azure/{module}/azurerm/latest`

- Surface conflicts or prerequisites in your summary; never overwrite assets unless the spec explicitly permits changes.- **GitHub repository URL pattern**: `https://github.com/Azure/terraform-azurerm-avm-{type}-{service}-{resource}`

  - Example resource module: `https://github.com/Azure/terraform-azurerm-avm-res-storage-storageaccount`

## Reading the specification Excel  - Example pattern module: `https://github.com/Azure/terraform-azurerm-avm-ptn-aks-enterprise`

1. **Sheet 1 – Components** lists resource types, SKUs, instance counts, and optional integrators (e.g., "App Service Plan P1v3 x2"). Group rows by shared characteristics when mapping to CLI commands.

2. **Sheet 2 – Networking** provides request number, region, virtual network address space, per-subnet CIDR blocks, DNS requirements, and integration notes.## Resource discovery checklist

3. Cross-check both sheets for consistency (e.g., a Storage account on Sheet 1 must map to a subnet tagged `Storage` on Sheet 2). Raise discrepancies immediately.Before authoring Terraform code, query Azure (using MCP tooling) for the subscription named in the spec:

- Confirm whether a resource group `${organization}-${project}` already exists; document drift in location or tags. The Terraform configuration must (re)create or align this group using the AVM resource-group module.

## Authoring `apps/{organization}/{project}/deployment.sh`- Enumerate existing VNets, subnets, private endpoints, and DNS zones to avoid naming or CIDR collisions.

- Surface conflicts or prerequisites in your summary; never overwrite assets unless the spec explicitly permits changes.

### Script structure and principles

- Generate a bash script with Azure CLI commands ordered by resource dependencies## Reading the specification Excel

- Include error handling with `set -e` to stop on first error1. **Sheet 1 – Components** lists resource types, SKUs, instance counts, and optional integrators (e.g., “App Service Plan P1v3 x2”). Group rows by shared characteristics when mapping to module inputs.

- Use variables at the top of the script for common values (resource group name, location, tags)2. **Sheet 2 – Networking** provides request number, region, virtual network address space, per-subnet CIDR blocks, DNS requirements, and integration notes.

- Add comments explaining each resource creation step3. Cross-check both sheets for consistency (e.g., a Storage account on Sheet 1 must map to a subnet tagged `Storage` on Sheet 2). Raise discrepancies immediately.

- Ensure idempotency where possible using `--only-show-errors` and checking for existing resources

- Only specify essential arguments based on Excel specs and resource standards## Authoring `apps/{organization}/{project}/main.tf`



### Dependency ordering### Scope & composition

Commands must follow this general sequence to respect Azure resource dependencies:- Declare providers and backend settings in `providers.tf`; avoid redefining them inside module blocks.

- Configure the `azurerm` provider with the minimal, vanilla setup: include only the empty `features {}` block without any additional feature flags or customizations.

1. **Resource Group** – Foundation for all resources- Configure the Terraform backend for local state storage (e.g., the `local` backend); the GitHub Action that provisions environments should run end-to-end without requiring persistent state.

2. **Network Security Groups** – Must exist before subnet association- Accept only the parameters necessary to describe the deployment. Prefer local values and default variable assignments over exposing organization/project identifiers as input variables.

3. **Virtual Network & Subnets** – Network foundation with NSG associations- Create the workload resource group via the AVM resource-group module and reuse its outputs (e.g., `module.workload_rg.name`, `module.workload_rg.id`) when wiring downstream modules. Do not recompute or hardcode the name.

4. **Private DNS Zones** – Required before private endpoints- Instantiate all workload resources with AVM modules, passing the resource-group name/id through module inputs designed for scoping.

5. **VNet Links for DNS Zones** – Connect DNS zones to virtual network- Centralize tagging in local maps to ensure consistency across modules.

6. **Core Services** – Storage accounts, Key Vaults, SQL servers (without private endpoints first)- Keep the code clean and simple; avoid unnecessary complexity or indirection.

7. **Private Endpoints** – Connect services to private DNS zones

8. **Application Services** – App Service Plans, Web Apps with VNet integration### Required AVM Terraform modules

9. **Monitoring** – Log Analytics, Application InsightsUse the latest **stable** verified versions (semantic `aa.bb.cc`) listed in the Terraform AVM index. Always pin `version = "x.y.z"` in each module block. You must query the Terraform Registry endpoint (`https://registry.terraform.io/v1/modules/Azure/<module>/azurerm/versions`) immediately before coding and select the highest `version` value flagged as `"status": "available"`. If the published tag exposes only two segments (e.g., `0.12`), append `.0` unless the index states otherwise (→ `0.12.0`). Document in your summary which endpoint responses were used to justify the chosen versions.



### Common resource patterns| Purpose | Terraform registry source | Key inputs | Essential outputs consumed downstream |

| --- | --- | --- | --- |

#### Resource group creation| Resource group | `Azure/avm-res-resources-resource-group/azurerm` | `name`, `location`, `tags` | `name`, `id`, `location` |

```bash| Virtual network & subnets | `Azure/avm-res-network-virtual-network/azurerm` | `resource_group_name`, `name`, `address_space`, `subnets` (list of objects with `name`, `address_prefixes`, `nsg_id`, `service_endpoints`) | `id`, `name`, `subnet_ids` |

az group create \| Network security group | `Azure/avm-res-network-network-security-group/azurerm` | `resource_group_name`, `name`, `security_rules`, `tags` | `id`, `name` |

  --name "${RESOURCE_GROUP}" \| Private endpoint | `Azure/avm-res-network-private-endpoint/azurerm` | `resource_group_name`, `name`, `location`, `subnet_id`, `private_service_connection`, `private_dns_zone_group` | `id`, `custom_dns_configs` |

  --location "${LOCATION}" \| Private DNS zone | `Azure/avm-res-network-private-dns-zone/azurerm` | `name`, `resource_group_name`, `tags` | `id`, `name` |

  --tags applicationNumber="${APP_NUMBER}" organization="${ORG}" project="${PROJECT}" environment="${ENV}"| Private DNS VNet link | `Azure/avm-res-network-private-dns-zone-virtual-network-link/azurerm` | `resource_group_name`, `name`, `private_dns_zone_id`, `virtual_network_id`, `registration_enabled` | `id` |

```| Storage account | `Azure/avm-res-storage-storage-account/azurerm` | `resource_group_name`, `name`, `location`, `kind`, `sku_name`, `tags`, privacy toggles | `id`, `primary_endpoints` |

| Key Vault | `Azure/avm-res-key-vault-vault/azurerm` | `resource_group_name`, `name`, `location`, `tenant_id`, `sku_name`, `soft_delete_retention_days`, `purge_protection_enabled`, `network_acls`, `tags` | `id`, `uri` |

#### Network Security Group| SQL server | `Azure/avm-res-sql-server/azurerm` | `resource_group_name`, `name`, `location`, `administrator_login`, `administrator_login_password`, `minimal_tls_version`, `tags`, `public_network_access_enabled=false` | `id`, `fully_qualified_domain_name` |

```bash| SQL database | `Azure/avm-res-sql-server-database/azurerm` | `server_id`, `name`, `edition`, `max_size_gb`, `zone_redundant`, `tags` | `id`, `name` |

az network nsg create \| App Service plan | `Azure/avm-res-web-serverfarm/azurerm` | `resource_group_name`, `name`, `location`, `sku`, `kind`, `worker_count`, `tags` | `id`, `name` |

  --resource-group "${RESOURCE_GROUP}" \| App Service (web app) | `Azure/avm-res-web-site/azurerm` | `resource_group_name`, `name`, `location`, `service_plan_id`, `site_config`, `app_settings`, `tags`, `virtual_network_subnet_id`, `https_only=true` | `id`, `default_hostname` |

  --name "${NSG_NAME}" \| Log Analytics workspace | `Azure/avm-res-operational-insights-workspace/azurerm` | `resource_group_name`, `name`, `location`, `sku`, `retention_in_days`, `daily_quota_gb`, `tags` | `id`, `workspace_id`, `primary_shared_key` |

  --location "${LOCATION}" \| Application Insights | `Azure/avm-res-insights-component/azurerm` | `resource_group_name`, `name`, `location`, `application_type`, `workspace_id`, `tags` | `id`, `instrumentation_key`, `connection_string` |

  --tags applicationNumber="${APP_NUMBER}"

```> ⚠️ **Always consult the module documentation** on the Terraform registry or GitHub repo (`Azure/terraform-azurerm-avm-res-*`) for complete input schemas, nested object structures, and optional defaults.



#### Virtual Network with subnets### Example Terraform skeleton (trim to fit workload)

```bash```hcl

az network vnet create \terraform {

  --resource-group "${RESOURCE_GROUP}" \  required_version = ">= 1.9.5"

  --name "${VNET_NAME}" \  required_providers {

  --location "${LOCATION}" \    azurerm = {

  --address-prefixes "10.0.0.0/16" \      source  = "hashicorp/azurerm"

  --subnet-name "default-subnet" \      version = ">= 3.111.0"

  --subnet-prefixes "10.0.1.0/24" \    }

  --tags applicationNumber="${APP_NUMBER}"  }

```}



#### Private DNS Zoneprovider "azurerm" {

```bash  features {}

az network private-dns zone create \}

  --resource-group "${RESOURCE_GROUP}" \

  --name "privatelink.vaultcore.azure.net" \locals {

  --tags applicationNumber="${APP_NUMBER}"  resource_group_name = "${upper("<organization>")}-${upper("<project>")}"

```  location            = "westeurope"

  application_number  = "<request number>"

#### Storage Account (private access)  environment         = "Prod"

```bash  common_tags = {

az storage account create \    applicationNumber = local.application_number

  --name "${STORAGE_NAME}" \    organization      = "<organization>"

  --resource-group "${RESOURCE_GROUP}" \    project           = "<project>"

  --location "${LOCATION}" \    environment       = local.environment

  --sku Standard_ZRS \  }

  --kind StorageV2 \  subnets = [

  --public-network-access Disabled \    {

  --tags applicationNumber="${APP_NUMBER}"      name               = "snet-apps"

```      usage              = "AppService"

      address_prefixes    = ["10.10.0.0/24"]

#### Private Endpoint      network_security_group = {

```bash        name   = "snet-apps-nsg"

az network private-endpoint create \        rules = [

  --name "${PE_NAME}" \          {

  --resource-group "${RESOURCE_GROUP}" \            name                       = "AllowWebOutbound"

  --location "${LOCATION}" \            priority                   = 100

  --subnet "${SUBNET_ID}" \            direction                  = "Outbound"

  --private-connection-resource-id "${RESOURCE_ID}" \            access                     = "Allow"

  --group-id "vault" \            protocol                   = "Tcp"

  --connection-name "${CONNECTION_NAME}" \            source_port_range          = "*"

  --tags applicationNumber="${APP_NUMBER}"            destination_port_ranges    = ["443"]

```            source_address_prefix      = "*"

            destination_address_prefix = "*"

### Required resource types and key arguments          }

        ]

| Resource Type | CLI Command Base | Essential Arguments | Private Networking Flags |      }

| --- | --- | --- | --- |    }

| Resource Group | `az group create` | `--name`, `--location`, `--tags` | N/A |  ]

| Virtual Network | `az network vnet create` | `--resource-group`, `--name`, `--address-prefixes` | N/A |}

| Subnet | `az network vnet subnet create` | `--resource-group`, `--vnet-name`, `--name`, `--address-prefixes` | `--network-security-group`, `--service-endpoints` |

| NSG | `az network nsg create` | `--resource-group`, `--name`, `--location` | N/A |module "workload_rg" {

| NSG Rule | `az network nsg rule create` | `--resource-group`, `--nsg-name`, `--name`, `--priority`, `--direction`, `--access` | N/A |  source  = "Azure/avm-res-resources-resource-group/azurerm"

| Private DNS Zone | `az network private-dns zone create` | `--resource-group`, `--name` | N/A |  version = "0.4.0"

| DNS VNet Link | `az network private-dns link vnet create` | `--resource-group`, `--zone-name`, `--name`, `--virtual-network` | N/A |

| Storage Account | `az storage account create` | `--name`, `--resource-group`, `--sku`, `--kind` | `--public-network-access Disabled` |  name     = local.resource_group_name

| Key Vault | `az keyvault create` | `--name`, `--resource-group`, `--location` | `--public-network-access Disabled` |  location = local.location

| SQL Server | `az sql server create` | `--name`, `--resource-group`, `--admin-user`, `--admin-password` | `--enable-public-network false` |  tags     = local.common_tags

| SQL Database | `az sql db create` | `--resource-group`, `--server`, `--name`, `--service-objective` | N/A |}

| App Service Plan | `az appservice plan create` | `--name`, `--resource-group`, `--sku` | N/A |

| Web App | `az webapp create` | `--name`, `--resource-group`, `--plan` | `--vnet-integration`, `--https-only` |module "apps_nsg" {

| Private Endpoint | `az network private-endpoint create` | `--name`, `--resource-group`, `--subnet`, `--private-connection-resource-id`, `--group-id` | Always used for private access |  for_each = { for subnet in local.subnets : subnet.name => subnet if can(subnet.network_security_group) }

| Log Analytics | `az monitor log-analytics workspace create` | `--resource-group`, `--workspace-name`, `--location` | N/A |

| App Insights | `az monitor app-insights component create` | `--app`, `--location`, `--resource-group`, `--workspace` | N/A |  source  = "Azure/avm-res-network-network-security-group/azurerm"

  version = "0.5.0"

> ⚠️ **Always consult the official Azure CLI documentation** at `https://learn.microsoft.com/en-us/cli/azure/{service}` for complete parameter schemas, optional flags, and latest syntax.

  resource_group_name = module.workload_rg.name

### Example deployment.sh skeleton (trim to fit workload)  name                = "${module.workload_rg.name}-${each.key}-nsg"

```bash  location            = module.workload_rg.location

#!/bin/bash  security_rules      = each.value.network_security_group.rules

set -e  tags                = local.common_tags

}

# Variables derived from Excel specification

ORG="<organization>"module "vnet" {

PROJECT="<project>"  source  = "Azure/avm-res-network-virtual-network/azurerm"

RESOURCE_GROUP="${ORG}-${PROJECT}"  version = "0.7.0"

LOCATION="westeurope"

APP_NUMBER="<request number>"  resource_group_name = module.workload_rg.name

ENV="Prod"  location            = module.workload_rg.location

  name                = "${module.workload_rg.name}-vnet"

# Common tags  address_space       = ["10.10.0.0/16"]

TAGS="applicationNumber=${APP_NUMBER} organization=${ORG} project=${PROJECT} environment=${ENV}"  subnets = [

    for subnet in local.subnets : {

echo "Creating resource group..."      name               = subnet.name

az group create \      address_prefixes    = subnet.address_prefixes

  --name "${RESOURCE_GROUP}" \      network_security_group_id = lookup(module.apps_nsg, subnet.name, null) != null ? module.apps_nsg[subnet.name].id : null

  --location "${LOCATION}" \    }

  --tags ${TAGS}  ]

  tags = local.common_tags

echo "Creating network security group..."}

az network nsg create \

  --resource-group "${RESOURCE_GROUP}" \# Instantiate storage, SQL, private endpoints, DNS zones, monitoring, and web workloads

  --name "${RESOURCE_GROUP}-nsg" \# using the modules listed above, wiring `module.workload_rg.name` and `module.vnet.subnet_ids` as needed.

  --location "${LOCATION}" \

  --tags ${TAGS}output "resource_group_name" {

  value = module.workload_rg.name

echo "Creating virtual network..."}

az network vnet create \

  --resource-group "${RESOURCE_GROUP}" \output "vnet_name" {

  --name "${RESOURCE_GROUP}-vnet" \  value = module.vnet.name

  --location "${LOCATION}" \}

  --address-prefixes "10.10.0.0/16" \

  --subnet-name "default-subnet" \output "nsg_subnets" {

  --subnet-prefixes "10.10.1.0/24" \  value = [

  --tags ${TAGS}    for k, nsg in module.apps_nsg : {

      subnet_name = k

echo "Creating private DNS zone..."      nsg_name    = nsg.name

az network private-dns zone create \    }

  --resource-group "${RESOURCE_GROUP}" \  ]

  --name "privatelink.vaultcore.azure.net" \}

  --tags ${TAGS}```



echo "Linking DNS zone to VNet..."## Translating Excel ➜ Terraform module inputs

VNET_ID=$(az network vnet show --resource-group "${RESOURCE_GROUP}" --name "${RESOURCE_GROUP}-vnet" --query id -o tsv)

az network private-dns link vnet create \| Excel cue | Terraform mapping |

  --resource-group "${RESOURCE_GROUP}" \| --- | --- |

  --zone-name "privatelink.vaultcore.azure.net" \| `Request Number` (Sheet 2) | Populate `local.application_number` and propagate to `tags`. |

  --name "${RESOURCE_GROUP}-vnet-link" \| `Organization` / `Project` | Used only to construct `local.resource_group_name` and tags; do not expose as variables. |

  --virtual-network "${VNET_ID}" \| Subnet table (Sheet 2) | Build `local.subnets` with `name`, `usage`, `address_prefixes`, and security rule requirements. |

  --registration-enabled false \| Component rows (Sheet 1) | Create matching objects/locals for module inputs (e.g., `local.web_apps`, `local.sql_databases`) capturing SKU, tier, and distinguishing attributes. |

  --tags ${TAGS}| DNS requirements | Instantiate private DNS zone modules and virtual-network links referencing `module.vnet.id`. |

| SLA or redundancy requirements | Map to module-specific toggles (`zone_redundant`, `replication_type`, `sku_name`). |

echo "Creating Key Vault..."

az keyvault create \Document any assumptions (e.g., defaulting to `ZRS` redundancy) directly in your summary when spec data is missing.

  --name "${RESOURCE_GROUP}-kv" \

  --resource-group "${RESOURCE_GROUP}" \## Deployment workflow (manual & CI)

  --location "${LOCATION}" \- Environments created via the GitHub Action do not require persistent Terraform state; keep state files local during authoring and validation runs, and avoid configuring remote backends unless a future process explicitly demands it.

  --public-network-access Disabled \- Author Terraform under `apps/{organization}/{project}` using a single state per workload.

  --tags ${TAGS}- Run deployment helper scripts (e.g., `deployTerraform.ps1 -Organization MIN800 -Project RG805`) once updated to Terraform. Maintain backwards-compatible flags until orchestration is refactored.

- Configure CI workflows (`deploy.yaml`) to execute Terraform init/plan/apply with explicit `organization` and `project` inputs.

echo "Creating private endpoint for Key Vault..."

SUBNET_ID=$(az network vnet subnet show --resource-group "${RESOURCE_GROUP}" --vnet-name "${RESOURCE_GROUP}-vnet" --name "default-subnet" --query id -o tsv)## Validation steps before completion

KV_ID=$(az keyvault show --name "${RESOURCE_GROUP}-kv" --query id -o tsv)1. Execute `terraform fmt -recursive` inside the workload directory to enforce canonical formatting.

az network private-endpoint create \2. Re-query `https://registry.terraform.io/v1/modules/Azure/<module>/azurerm/versions` for every module you pinned and confirm the committed versions still match the latest available entries. If a newer version exists, update the code before proceeding.

  --name "${RESOURCE_GROUP}-kv-pe" \3. Run `terraform init -upgrade -backend=false` to download AVM modules without touching remote state.

  --resource-group "${RESOURCE_GROUP}" \4. Run `terraform validate` and resolve **all** errors and warnings.

  --location "${LOCATION}" \5. Produce a dry-run plan (`terraform plan -input=false -lock=false -out=tfplan`) using placeholder credentials or mocked values; ensure the plan completes without errors.

  --subnet "${SUBNET_ID}" \6. Verify that tagging, private networking flags, and module outputs align with orchestration expectations.

  --private-connection-resource-id "${KV_ID}" \7. Submit the changes and monitor the deploy-infra pipeline for final registry validation.

  --group-id "vault" \8. Capture any pipeline failures, document remediation steps, and iterate until the workflow reports success.

  --connection-name "${RESOURCE_GROUP}-kv-connection" \

  --tags ${TAGS}## Reporting gaps or limitations

- If an AVM Terraform module lacks a required feature, state the limitation and recommend the closest achievable configuration or a follow-up item for the AVM maintainers.

# Add additional resources following the same pattern...- Flag tenant policies (e.g., restricted private endpoint creation) that could block deployment and propose remediation.

- Note any manual steps required post-deployment (such as certificate uploads to App Service) when automation cannot cover them.

echo "Deployment complete!"

```Keep these instructions current. Review the AVM Terraform index quarterly, update module versions, and document notable changes in this guide.


## Translating Excel ➜ Azure CLI commands

| Excel cue | CLI mapping |
| --- | --- |
| `Request Number` (Sheet 2) | Populate `APP_NUMBER` variable and include in `--tags`. |
| `Organization` / `Project` | Used to construct `RESOURCE_GROUP` variable and tags. |
| Subnet table (Sheet 2) | Generate `az network vnet subnet create` commands with appropriate CIDR ranges and NSG associations. |
| Component rows (Sheet 1) | Create corresponding `az` commands capturing SKU, tier, and distinguishing attributes. |
| DNS requirements | Generate private DNS zone creation and virtual-network link commands. |
| SLA or redundancy requirements | Map to service-specific flags (`--sku`, `--zone-redundant`, `--replication-type`). |

Document any assumptions (e.g., defaulting to `ZRS` redundancy) directly in your summary when spec data is missing.

## Deployment workflow (manual & CI)
- Author deployment scripts under `apps/{organization}/{project}/deployment.sh`
- Scripts should be executable and contain all necessary Azure CLI commands in dependency order
- Configure CI workflows (`deploy.yaml`) to execute the deployment script with appropriate Azure authentication
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
