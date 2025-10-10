# GSIS Agentic IaC – Copilot Agent Instructions

## Mission Overview
This repository provisions secure-by-default Azure landing zones using specification Excel files. All infrastructure must now be authored with **Azure Verified Modules (AVM) for Terraform**. The Copilot agent is responsible for translating each request into:

1. A dedicated Terraform configuration (`main.tf` plus supporting files) that references AVM modules exclusively.
2. Validation evidence that the configuration has been formatted, linted, and successfully built (via `terraform validate` and a dry-run plan).

## Repository Layout & Naming
```
/
├── terraform.deploy.tfvars     # (Optional) shared deployment variables consumed by orchestration pipeline
├── deployTerraform.ps1         # Deployment helper script (expects organization/project flags)
├── apps/
│   └── {organization}/
│       └── {project}/
│           ├── main.tf         # Workload entry point invoking AVM modules
│           ├── providers.tf    # Provider and backend configuration scoped to the workload
│           └── variables.tf    # Optional variable declarations (minimize unless integration requires)
├── specs/
│   └── {organization}/
│       └── {project}/
│           └── *.xlsx          # Sheet 1: components, Sheet 2: network & request metadata
└── (no local module library)   # All components sourced from Azure Verified Modules for Terraform
```

> ℹ️ **Canonical vocabulary**
> - **organization** identifies the top-level requestor folder under `apps/` and `specs/`.
> - **project** identifies the workload folder nested beneath the organization.
> - The Azure resource group created for the workload must be named `${organization}-${project}` (uppercase preserved from specs).
> - Tag every resource (directly or via module inputs) with at least `applicationNumber`, `organization`, `project`, and `environment` (derived from the spec).

## Non-negotiable Guardrails
1. **AVM-only compositions** – reference modules published under [`Azure/terraform-azurerm-avm-res-*`](https://azure.github.io/Azure-Verified-Modules/indexes/terraform/tf-resource-modules/) with pinned versions; do not author bespoke Terraform resources unless the AVM library lacks required coverage.
2. **Private-first networking** – all services must land in hub virtual networks, expose only private endpoints, and integrate with private DNS zones.
3. **No public ingress** – disable public exposure for Storage, SQL, App Services, etc. by aligning module inputs with private access patterns.
4. **Subnet hygiene** – allocate non-overlapping CIDR ranges, assign NSGs per subnet, and honour the workload-specific subnet mapping from the spec.
5. **Reproducible builds** – run `terraform fmt`, `terraform init`, `terraform validate`, and `terraform plan` locally (with non-destructive arguments) to ensure syntactic and semantic correctness before handing off.
6. **Tooling alignment** – rely exclusively on the Terraform version provisioned by `.github/workflows/copilot-setup-steps.yml`; do not install or pin alternate Terraform builds in ad-hoc scripts or workflows.

## Resource discovery checklist
Before authoring Terraform code, query Azure (using MCP tooling) for the subscription named in the spec:
- Confirm whether a resource group `${organization}-${project}` already exists; document drift in location or tags. The Terraform configuration must (re)create or align this group using the AVM resource-group module.
- Enumerate existing VNets, subnets, private endpoints, and DNS zones to avoid naming or CIDR collisions.
- Surface conflicts or prerequisites in your summary; never overwrite assets unless the spec explicitly permits changes.

## Reading the specification Excel
1. **Sheet 1 – Components** lists resource types, SKUs, instance counts, and optional integrators (e.g., “App Service Plan P1v3 x2”). Group rows by shared characteristics when mapping to module inputs.
2. **Sheet 2 – Networking** provides request number, region, virtual network address space, per-subnet CIDR blocks, DNS requirements, and integration notes.
3. Cross-check both sheets for consistency (e.g., a Storage account on Sheet 1 must map to a subnet tagged `Storage` on Sheet 2). Raise discrepancies immediately.

## Authoring `apps/{organization}/{project}/main.tf`

### Scope & composition
- Declare providers and backend settings in `providers.tf`; avoid redefining them inside module blocks.
- Accept only the parameters necessary to describe the deployment. Prefer local values and default variable assignments over exposing organization/project identifiers as input variables.
- Create the workload resource group via the AVM resource-group module and reuse its outputs (e.g., `module.workload_rg.name`, `module.workload_rg.id`) when wiring downstream modules. Do not recompute or hardcode the name.
- Instantiate all workload resources with AVM modules, passing the resource-group name/id through module inputs designed for scoping.
- Centralize tagging in local maps to ensure consistency across modules.

### Required AVM Terraform modules
Use the latest **stable** verified versions (semantic `aa.bb.cc`) listed in the Terraform AVM index. Always pin `version = "x.y.z"` in each module block, confirming you select the newest stable release from the “Status & Versions” column on the [official index](https://azure.github.io/Azure-Verified-Modules/indexes/terraform/tf-resource-modules/). If the published tag exposes only two segments (e.g., `0.12`), append `.0` unless the index states otherwise (→ `0.12.0`).

| Purpose | Terraform registry source | Key inputs | Essential outputs consumed downstream |
| --- | --- | --- | --- |
| Resource group | `Azure/avm-res-resources-resource-group/azurerm` | `name`, `location`, `tags` | `name`, `id`, `location` |
| Virtual network & subnets | `Azure/avm-res-network-virtual-network/azurerm` | `resource_group_name`, `name`, `address_space`, `subnets` (list of objects with `name`, `address_prefixes`, `nsg_id`, `service_endpoints`) | `id`, `name`, `subnet_ids` |
| Network security group | `Azure/avm-res-network-network-security-group/azurerm` | `resource_group_name`, `name`, `security_rules`, `tags` | `id`, `name` |
| Private endpoint | `Azure/avm-res-network-private-endpoint/azurerm` | `resource_group_name`, `name`, `location`, `subnet_id`, `private_service_connection`, `private_dns_zone_group` | `id`, `custom_dns_configs` |
| Private DNS zone | `Azure/avm-res-network-private-dns-zone/azurerm` | `name`, `resource_group_name`, `tags` | `id`, `name` |
| Private DNS VNet link | `Azure/avm-res-network-private-dns-zone-virtual-network-link/azurerm` | `resource_group_name`, `name`, `private_dns_zone_id`, `virtual_network_id`, `registration_enabled` | `id` |
| Storage account | `Azure/avm-res-storage-storage-account/azurerm` | `resource_group_name`, `name`, `location`, `kind`, `sku_name`, `tags`, privacy toggles | `id`, `primary_endpoints` |
| Key Vault | `Azure/avm-res-key-vault-vault/azurerm` | `resource_group_name`, `name`, `location`, `tenant_id`, `sku_name`, `soft_delete_retention_days`, `purge_protection_enabled`, `network_acls`, `tags` | `id`, `uri` |
| SQL server | `Azure/avm-res-sql-server/azurerm` | `resource_group_name`, `name`, `location`, `administrator_login`, `administrator_login_password`, `minimal_tls_version`, `tags`, `public_network_access_enabled=false` | `id`, `fully_qualified_domain_name` |
| SQL database | `Azure/avm-res-sql-server-database/azurerm` | `server_id`, `name`, `edition`, `max_size_gb`, `zone_redundant`, `tags` | `id`, `name` |
| App Service plan | `Azure/avm-res-web-serverfarm/azurerm` | `resource_group_name`, `name`, `location`, `sku`, `kind`, `worker_count`, `tags` | `id`, `name` |
| App Service (web app) | `Azure/avm-res-web-site/azurerm` | `resource_group_name`, `name`, `location`, `service_plan_id`, `site_config`, `app_settings`, `tags`, `virtual_network_subnet_id`, `https_only=true` | `id`, `default_hostname` |
| Log Analytics workspace | `Azure/avm-res-operational-insights-workspace/azurerm` | `resource_group_name`, `name`, `location`, `sku`, `retention_in_days`, `daily_quota_gb`, `tags` | `id`, `workspace_id`, `primary_shared_key` |
| Application Insights | `Azure/avm-res-insights-component/azurerm` | `resource_group_name`, `name`, `location`, `application_type`, `workspace_id`, `tags` | `id`, `instrumentation_key`, `connection_string` |

> ⚠️ **Always consult the module documentation** on the Terraform registry or GitHub repo (`Azure/terraform-azurerm-avm-res-*`) for complete input schemas, nested object structures, and optional defaults.

### Example Terraform skeleton (trim to fit workload)
```hcl
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.111.0"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  resource_group_name = "${upper("<organization>")}-${upper("<project>")}"
  location            = "westeurope"
  application_number  = "<request number>"
  environment         = "Prod"
  common_tags = {
    applicationNumber = local.application_number
    organization      = "<organization>"
    project           = "<project>"
    environment       = local.environment
  }
  subnets = [
    {
      name               = "snet-apps"
      usage              = "AppService"
      address_prefixes    = ["10.10.0.0/24"]
      network_security_group = {
        name   = "snet-apps-nsg"
        rules = [
          {
            name                       = "AllowWebOutbound"
            priority                   = 100
            direction                  = "Outbound"
            access                     = "Allow"
            protocol                   = "Tcp"
            source_port_range          = "*"
            destination_port_ranges    = ["443"]
            source_address_prefix      = "*"
            destination_address_prefix = "*"
          }
        ]
      }
    }
  ]
}

module "workload_rg" {
  source  = "Azure/avm-res-resources-resource-group/azurerm"
  version = "0.4.0"

  name     = local.resource_group_name
  location = local.location
  tags     = local.common_tags
}

module "apps_nsg" {
  for_each = { for subnet in local.subnets : subnet.name => subnet if can(subnet.network_security_group) }

  source  = "Azure/avm-res-network-network-security-group/azurerm"
  version = "0.5.0"

  resource_group_name = module.workload_rg.name
  name                = "${module.workload_rg.name}-${each.key}-nsg"
  location            = module.workload_rg.location
  security_rules      = each.value.network_security_group.rules
  tags                = local.common_tags
}

module "vnet" {
  source  = "Azure/avm-res-network-virtual-network/azurerm"
  version = "0.7.0"

  resource_group_name = module.workload_rg.name
  location            = module.workload_rg.location
  name                = "${module.workload_rg.name}-vnet"
  address_space       = ["10.10.0.0/16"]
  subnets = [
    for subnet in local.subnets : {
      name               = subnet.name
      address_prefixes    = subnet.address_prefixes
      network_security_group_id = lookup(module.apps_nsg, subnet.name, null) != null ? module.apps_nsg[subnet.name].id : null
    }
  ]
  tags = local.common_tags
}

# Instantiate storage, SQL, private endpoints, DNS zones, monitoring, and web workloads
# using the modules listed above, wiring `module.workload_rg.name` and `module.vnet.subnet_ids` as needed.

output "resource_group_name" {
  value = module.workload_rg.name
}

output "vnet_name" {
  value = module.vnet.name
}

output "nsg_subnets" {
  value = [
    for k, nsg in module.apps_nsg : {
      subnet_name = k
      nsg_name    = nsg.name
    }
  ]
}
```

## Translating Excel ➜ Terraform module inputs

| Excel cue | Terraform mapping |
| --- | --- |
| `Request Number` (Sheet 2) | Populate `local.application_number` and propagate to `tags`. |
| `Organization` / `Project` | Used only to construct `local.resource_group_name` and tags; do not expose as variables. |
| Subnet table (Sheet 2) | Build `local.subnets` with `name`, `usage`, `address_prefixes`, and security rule requirements. |
| Component rows (Sheet 1) | Create matching objects/locals for module inputs (e.g., `local.web_apps`, `local.sql_databases`) capturing SKU, tier, and distinguishing attributes. |
| DNS requirements | Instantiate private DNS zone modules and virtual-network links referencing `module.vnet.id`. |
| SLA or redundancy requirements | Map to module-specific toggles (`zone_redundant`, `replication_type`, `sku_name`). |

Document any assumptions (e.g., defaulting to `ZRS` redundancy) directly in your summary when spec data is missing.

## Deployment workflow (manual & CI)
- Author Terraform under `apps/{organization}/{project}` using a single state per workload.
- Run deployment helper scripts (e.g., `deployTerraform.ps1 -Organization MIN800 -Project RG805`) once updated to Terraform. Maintain backwards-compatible flags until orchestration is refactored.
- Configure CI workflows (`deploy.yaml`) to execute Terraform init/plan/apply with explicit `organization` and `project` inputs.

## Validation steps before completion
1. Execute `terraform fmt -recursive` inside the workload directory to enforce canonical formatting.
2. Run `terraform init -upgrade -backend=false` to download AVM modules without touching remote state.
3. Run `terraform validate` and resolve **all** errors and warnings.
4. Produce a dry-run plan (`terraform plan -input=false -lock=false -out=tfplan`) using placeholder credentials or mocked values; ensure the plan completes without errors.
5. Verify that tagging, private networking flags, and module outputs align with orchestration expectations.
6. Submit the changes and monitor the deploy-infra pipeline for final registry validation.
7. Capture any pipeline failures, document remediation steps, and iterate until the workflow reports success.

## Reporting gaps or limitations
- If an AVM Terraform module lacks a required feature, state the limitation and recommend the closest achievable configuration or a follow-up item for the AVM maintainers.
- Flag tenant policies (e.g., restricted private endpoint creation) that could block deployment and propose remediation.
- Note any manual steps required post-deployment (such as certificate uploads to App Service) when automation cannot cover them.

Keep these instructions current. Review the AVM Terraform index quarterly, update module versions, and document notable changes in this guide.
