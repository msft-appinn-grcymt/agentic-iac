output "resource_group_name" {
  description = "The name of the resource group"
  value       = module.workload_rg.name
}

output "resource_group_id" {
  description = "The ID of the resource group"
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

output "storage_account_name" {
  description = "The name of the storage account"
  value       = module.storage_account.name
}

output "storage_account_id" {
  description = "The ID of the storage account"
  value       = module.storage_account.resource_id
}

output "private_endpoint_id" {
  description = "The ID of the storage account blob private endpoint"
  value       = module.storage_account.private_endpoints["blob_pe"].id
}
