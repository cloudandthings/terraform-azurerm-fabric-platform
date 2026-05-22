# Tests that when scheduler is null, only the core Fabric Capacity resources are planned:
# azurerm_resource_group and azurerm_fabric_capacity. All automation resources
# (automation account, runbook, schedules, job schedules, role assignment) must be absent.
mock_provider "azurerm" {}
mock_provider "azuread" {}
mock_provider "time" {}

# Verifies the minimal resource set: one resource group and one Fabric Capacity,
# with the correct name and SKU, and no automation infrastructure.
run "no_scheduler_creates_only_core_resources" {
  command = plan

  variables {
    basename     = "testcapacity"
    location     = "North Europe"
    sku          = "F2"
    admin_emails = ["admin@example.com"]
    scheduler    = null
  }

  assert {
    condition     = azurerm_resource_group.this.name == "testcapacity"
    error_message = "Resource group name should match basename"
  }

  assert {
    condition     = azurerm_fabric_capacity.this.name == "testcapacity"
    error_message = "Fabric capacity name should match basename"
  }

  assert {
    condition     = azurerm_fabric_capacity.this.sku[0].name == "F2"
    error_message = "Fabric capacity SKU should be F2"
  }

  assert {
    condition     = length(azurerm_automation_account.this) == 0
    error_message = "No automation account should be created when scheduler is null"
  }

  assert {
    condition     = length(azurerm_automation_runbook.manage_capacity) == 0
    error_message = "No runbook should be created when scheduler is null"
  }

  assert {
    condition     = length(azurerm_automation_schedule.pause_schedule) == 0
    error_message = "No pause schedule should be created when scheduler is null"
  }

  assert {
    condition     = length(azurerm_automation_schedule.resume_schedule) == 0
    error_message = "No resume schedule should be created when scheduler is null"
  }

  # Usage-based autostop resources must also be absent when both inputs are null.
  assert {
    condition     = length(azurerm_automation_runbook.monitor_capacity) == 0
    error_message = "No monitor runbook should be created when both scheduler and usage_autostop are null"
  }

  assert {
    condition     = length(azurerm_automation_variable_int.idle_check_counter) == 0
    error_message = "No idle counter variable should be created when both scheduler and usage_autostop are null"
  }

  assert {
    condition     = length(azurerm_automation_schedule.monitor_schedule) == 0
    error_message = "No monitor schedule should be created when both scheduler and usage_autostop are null"
  }

  assert {
    condition     = length(azurerm_role_assignment.automation_contributor) == 0
    error_message = "No capacity-scope role assignment should be created when both inputs are null"
  }

  assert {
    condition     = output.monitor_principal_id == null
    error_message = "monitor_principal_id output should be null when usage_autostop is disabled"
  }

  assert {
    condition     = output.automation_account_id == null
    error_message = "automation_account_id output should be null when both inputs are null"
  }
}
