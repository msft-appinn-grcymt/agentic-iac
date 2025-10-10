output "resource_group_name" {
  description = "The name of the created resource group"
  value       = module.workload_rg.name
}

output "resource_group_id" {
  description = "The ID of the created resource group"
  value       = module.workload_rg.resource_id
}

output "vnet_name" {
  description = "The name of the virtual network"
  value       = module.vnet.name
}

output "vnet_id" {
  description = "The ID of the virtual network"
  value       = module.vnet.resource_id
}

output "nsg_subnets" {
  description = "List of subnets with their associated NSGs"
  value = [
    for k, nsg in module.subnet_nsg : {
      subNetName = k
      nsgName    = nsg.name
    }
  ]
}

output "storage_account_name" {
  description = "The name of the storage account"
  value       = module.storage_account.name
}

output "storage_account_id" {
  description = "The ID of the storage account"
  value       = module.storage_account.resource_id
}

output "private_endpoint_id" {
  description = "The ID of the storage blob private endpoint"
  value       = module.storage_private_endpoint.resource_id
}
