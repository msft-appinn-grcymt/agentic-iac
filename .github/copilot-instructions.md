# GSIS Agentic IaC – Copilot Agent Instructions

## Mission Overview
This repository provisions secure-by-default Azure landing zones from specification Excel files. All infrastructure must now be composed with **Azure Verified Modules (AVM)** sourced from the public Bicep registry. The Copilot agent is responsible for translating each request into:

1. A dedicated `main.bicep` authored with AVM references.
2. Validation evidence that the configuration is syntactically sound and ready for the deploy-infra workflow to validate module resolution (see validation steps below).

## Repository Layout & Naming
```
/
├── azure.deploy.bicep          # Subscription-scope entry point (wraps apps/*/main.bicep)
├── deployBicep.sh              # Deployment helper script (expects organization/project flags)
├── apps/
│   └── {organization}/
│       └── {project}/
│           └── main.bicep      # AVM-based workload template (author per request)
├── specs/
│   └── {organization}/
│       └── {project}/
│           └── *.xlsx          # Sheet 1: components, Sheet 2: network & request metadata
└── (no local module library)   # All components authored with Azure Verified Modules
```

### Canonical vocabulary
- **organization** identifies the top-level requestor folder under `apps/` and `specs/`.
- **project** identifies the workload folder nested beneath the organization.
- The Azure resource group is created during deployment and must be named `${organization}-${project}` (all uppercase preserved from specs).
- Everywhere we collect metadata, tag and label resources with at least:
  - `applicationNumber`: Excel request id (Sheet 2)
  - `organization`, `project`
  - `environment`: derive from spec (e.g., `Prod`, `Test`) when provided

## Non-negotiable Guardrails
1. **Azure Verified Modules only** – reference the versions in the table below; do not create or reuse local module files.
2. **Private-first networking** – every workload component must land inside the hub VNet, expose only private endpoints, and integrate with private DNS zones.
3. **No public ingress** – disable public access for Storage, SQL, App Services, etc. Use service endpoints or private endpoints as required by AVM parameters.
4. **Subnet hygiene** – allocate non-overlapping CIDR ranges and link each subnet to an NSG. Reserve dedicated subnets per workload type exactly as the spec defines.
5. **Reproducible builds** – author code that succeeds under `bicep build`, resolve all syntax issues locally, and document any assumptions for downstream validation.

## Resource discovery checklist
Before producing files, query Azure (using MCP tooling) for the subscription defined in the spec:
- Confirm whether a resource group named `${organization}-${project}` already exists and document any drift (location, tags); the deployment will create or update this group automatically.
- List existing VNet, subnets, private endpoints, and DNS zones. Note any naming or IP conflicts.
- Flag conflicts in the summary section of your response; do not overwrite existing assets unless the spec explicitly calls for updates.

## How to read the specification Excel
1. **Sheet 1 – Components:** lists resource types, SKUs, counts, and optional integrators (e.g., “App Service Plan P1v3 x2”). Group rows by compatible settings (runtime, SKU) when modeling modules.
2. **Sheet 2 – Networking:** provides the request number, region, VNet address space, subnet breakdown, DNS requirements, and any integration notes.
3. Cross-check both sheets for consistency (e.g., Storage account referenced in Sheet 1 must have a subnet in Sheet 2 tagged `Storage`). Raise discrepancies.

## Authoring `apps/{organization}/{project}/main.bicep`

### Scope & contract
- `targetScope = 'subscription'`
- Define only the parameters needed to describe the deployment (for example `resourceGroupName`, `location`, `tags`, `vnetAddressPrefixes`, `subnetDefinitions`). Do not declare separate `organization` or `project` parameters or variables.
- Embed request-specific values directly inside `main.bicep` (for example, by setting parameter default values or inline variables). Do not create a companion `deploy.bicepparam` file.
- Create the workload resource group inside `main.bicep` with `br/public:avm/res/resources/resource-group` and set its `name` from the chosen `resourceGroupName` value.
- Scope every subsequent AVM module with `scope: resourceGroup(workloadRg.outputs.name)` (or the equivalent pattern) and add `dependsOn: [ workloadRg ]` to sequence creation. Do not hardcode or recompute the resource group name—always reuse the module output.
- Outputs: at least `resourceGroupName`, `vnetName`, `nsgSubnets` (array of `{ subNetName, nsgName }`) to satisfy `deployBicep.sh` post-processing.

### Required module invocations
Use the following AVM modules (latest verified versions as of 2024-04-01). Reference format: `br/public:{modulePath}:{version}`.

> ℹ️ **Module version format**: AVM releases use a three-part semantic version (`aa.bb.cc`). Cross-check each module against the **Status & Versions** column on the [AVM Bicep index](https://azure.github.io/Azure-Verified-Modules/indexes/bicep/bicep-resource-modules/). If the published tag only exposes two segments (for example `0.12`), confirm no newer tag exists on the index and pad the value to `0.12.0` when referencing it from `br/public`. No extra `bicepconfig.json` alias is required—the public registry is already reachable via the built-in `br/public` prefix.

| Purpose | Module path | Version |
| --- | --- | --- |
| Resource group metadata (used at subscription scope in `azure.deploy.bicep`) | `avm/res/resources/resource-group` | 0.4 |
| Virtual network + subnets | `avm/res/network/virtual-network` | 0.7 |
| Network security groups | `avm/res/network/network-security-group` | 0.5 |
| Private endpoint | `avm/res/network/private-endpoint` | 0.11 |
| Private DNS zone | `avm/res/network/private-dns-zone` | 0.8 |
| Private DNS zone VNet link | `avm/res/network/private-dns-zone/virtual-network-link` | 0.8 |
| Storage account | `avm/res/storage/storage-account` | 0.27 |
| Key Vault | `avm/res/key-vault/vault` | 0.13 |
| SQL server | `avm/res/sql/server` | 0.20 |
| SQL database | `avm/res/sql/server/database` | 0.1 |
| App Service plan | `avm/res/web/serverfarm` | 0.5 |
| App Service (web app) | `avm/res/web/site` | 0.19 |
| Log Analytics workspace | `avm/res/operational-insights/workspace` | 0.12 |
| Application Insights | `avm/res/insights/component` | 0.6 |

Add further AVM modules (e.g., AKS, Bastion, VPN) when a spec calls for them. Always cite the version in comments for traceability.

### Networking blueprint
- Deploy a single VNet using the spec’s address space.
- For each subnet row, create:
  1. An NSG (`network-security-group` module) with rules derived from the spec.
  2. A subnet entry in the VNet module referencing the NSG resource id.
- When a workload supports private endpoints (Storage, SQL, Web Apps, etc.), instantiate:
  - A `private-endpoint` module targeting the service.
  - A matching `private-dns-zone` module (one per service type) and a `virtual-network-link` back to the VNet.
- Ensure web apps are integrated with the VNet (`siteConfig.vnetRouteAllEnabled = true`, `virtualNetworkSubnetId` pointing to the correct subnet).
- Disable public network access via the relevant AVM parameters (`publicNetworkAccess`, `allowBlobPublicAccess`, `httpsOnly`, etc.).

### Observability & security
- Always provision Log Analytics and Application Insights when any compute workload exists.
- Key Vaults must have soft delete and purge protection enabled and use private endpoints.
- SQL servers must restrict public network access and enable Auditing and Threat Detection if the module exposes the switches.

### Example skeleton (trim as needed)
```bicep
targetScope = 'subscription'

param resourceGroupName string = '<resource group name from spec>'
param location string = '<azure region from spec>'
param tags object = {
  applicationNumber: '<request number>'
  environment: '<environment name>'
  // include any additional metadata required by the request (e.g., organization/project) without declaring separate parameters
}
param vnetAddressPrefixes array = [
  '<address space from spec>'
]
param subnetDefinitions array = [
  {
    name: '<subnet name>'
    usage: '<workload usage label>'
    addressPrefix: '<subnet cidr>'
  }
]

module workloadRg 'br/public:avm/res/resources/resource-group:0.4' = {
  name: 'rg-${resourceGroupName}'
  params: {
    name: resourceGroupName
    location: location
    tags: tags
  }
}

var workloadRgName = workloadRg.outputs.name

module nsgs 'br/public:avm/res/network/network-security-group:0.5' = [
  for subnet in subnetDefinitions: {
    name: 'nsg-${workloadRgName}-${subnet.usage}'
    scope: resourceGroup(workloadRgName)
    dependsOn: [
      workloadRg
    ]
    params: {
      name: '${workloadRgName}-${subnet.usage}-nsg'
      location: location
      securityRules: [] // populate from spec
      tags: tags
    }
  }
]

module vnet 'br/public:avm/res/network/virtual-network:0.7' = {
  name: 'vnet-${workloadRgName}'
  scope: resourceGroup(workloadRgName)
  dependsOn: [
    workloadRg
    nsgs
  ]
  params: {
    name: '${workloadRgName}-vnet'
    location: location
    addressPrefixes: vnetAddressPrefixes
    subnets: [
      for subnet in subnetDefinitions: {
        name: subnet.name
        addressPrefix: subnet.addressPrefix
        networkSecurityGroupId: resourceId('Microsoft.Network/networkSecurityGroups', '${workloadRgName}-${subnet.usage}-nsg')
      }
    ]
    tags: tags
  }
}

// Instantiate storage, SQL, web apps, private endpoints, DNS links, and monitoring modules with the same scope pattern.

output resourceGroupName string = workloadRg.outputs.name
output vnetName string = vnet.outputs.name
output nsgSubnets array = [
  for subnet in subnetDefinitions: {
    subNetName: subnet.name
    nsgName: '${workloadRgName}-${subnet.usage}-nsg'
  }
]
```

## Translating Excel ➜ AVM parameters

| Excel cue | Bicep representation |
| --- | --- |
| Sheet 1 row `App Service Plan` | Append to `appServicePlans` array with SKU, worker count, OS. Pair each plan with at least one `webSites` entry. |
| Sheet 1 row `SQL Database` | Create an entry in `sqlServers` (one per unique server) and `sqlDatabases` for each DB. Use the plan’s edition and max size. |
| Sheet 1 row `Storage Account` | Add to `storageAccounts` array with `kind`, `skuName`, and boolean switches for blob/file/table/queue private endpoints. |
| Networking sheet subnets | Populate `subnetDefinitions`; ensure naming aligns with NSG + workload use. |
| Request number | Populate `requestNumber` variable and propagate to tags. |

Document assumptions directly in the PR summary when data is missing (e.g., defaulting to `ZRS` storage redundancy).

## Deployment workflow (manual & CI)
- Parameter discovery and file authoring always happen in `apps/{organization}/{project}`.
- Run the helper script from repo root once it supports the new arguments: `./deployBicep.sh -o MIN800 -p RG805`. Until the rename lands, keep backward compatibility with `-m/-r` but surface the discrepancy in your summary.
- GitHub workflow (`deploy.yaml`) should be triggered with `organization` & `project` inputs; update documentation if new inputs are introduced.

## Validation steps before completion
1. Review the generated files for syntax correctness (matching braces, parameter types, module names/versions) and cross-check against AVM documentation.
2. Run local linting (`bicep lint` or equivalent analyzers) and resolve all warnings that impact deployment safety.
3. Build every updated Bicep file locally (`bicep build`) to ensure module references resolve and produce valid ARM templates.
4. Ensure required parameters and tags are present, private networking flags are set, and module outputs align with downstream scripts.
5. Submit the changes and monitor the deploy-infra GitHub Action for runtime validation against the registry.
6. Capture any Action failures, document remediation steps, and iterate until the workflow succeeds.

## Reporting gaps or limitations
- If AVM modules currently miss a required feature, state it explicitly and suggest the closest achievable configuration.
- Highlight any tenant policy that blocks private endpoints or zone creations.
- Provide remediation or post-deployment tasks when automation cannot fulfil a requirement (e.g., certificate upload to App Service).

Keep the guidance current; revisit AVM versions quarterly and update this document with changelog entries.
