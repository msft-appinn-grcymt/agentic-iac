---
name: Create AVM workload for project
about: Track the IaC artifacts needed for a new organization/project request.
title: <ORGANIZATION>-<PROJECT>
labels: ''
assignees: Copilot

---

Generate the AVM-based workload template and deployment parameters for organization `<ORGANIZATION>` and project `<PROJECT>` using the specification workbook stored under `specs/<ORGANIZATION>/<PROJECT>/`.

- author `apps/<ORGANIZATION>/<PROJECT>/main.bicep` targeting the resource group scope and invoking Azure Verified Modules only
- add the matching `apps/<ORGANIZATION>/<PROJECT>/deploy.bicepparam` with tags, subnets, and all required module parameters
- ensure `${{organization}}-${{project}}` resource group exists and private networking/IP allocations align with the workbook
- run `bicep build` for both files before completion and report any validation gaps

The provided VNet CIDR is <VNET_CIDR>
The subnet configuration is as below:
<SUBNET_CONFIGURATION>

GSIS Request Number is <REQUEST_NUMBER>
