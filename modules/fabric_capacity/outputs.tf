output "id" {
  description = "The ID of the Fabric capacity"
  value       = azurerm_fabric_capacity.this.id
}

output "automation_account_id" {
  description = "The ID of the Azure Automation Account managing this capacity. Null when both scheduler and usage_autostop are disabled."
  value       = (var.scheduler != null || var.usage_autostop != null) ? azurerm_automation_account.this[0].id : null
}

output "monitor_principal_id" {
  description = "The principal ID of the Automation Account's managed identity used for workspace monitoring. Null when usage_autostop is disabled."
  value       = var.usage_autostop != null ? azurerm_automation_account.this[0].identity[0].principal_id : null
}

output "has_monitor" {
  description = "True when usage_autostop is enabled and workspace Member role assignments should be created. Always known at plan time."
  value       = var.usage_autostop != null
}
