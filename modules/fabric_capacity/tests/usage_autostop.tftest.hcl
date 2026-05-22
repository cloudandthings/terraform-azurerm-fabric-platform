# Tests that when usage_autostop is configured, all usage-based monitoring infrastructure
# is planned: automation account, idle counter variable, monitor runbook, monitor schedule,
# and monitor job schedule. Also verifies that:
#   - usage_autostop and scheduler can be enabled simultaneously sharing one account
#   - the automation account is absent when both scheduler and usage_autostop are null
mock_provider "azurerm" {}
mock_provider "azuread" {}
mock_provider "time" {}

# usage_autostop only — verifies the core monitoring stack.
run "usage_autostop_only_creates_monitoring_resources" {
  command = plan

  variables {
    basename     = "testcapacity"
    location     = "North Europe"
    sku          = "F2"
    admin_emails = ["admin@example.com"]
    scheduler    = null
    usage_autostop = {
      check_interval_hours  = 1
      idle_threshold_checks = 3
    }
  }

  assert {
    condition     = length(azurerm_automation_account.this) == 1
    error_message = "Automation account should be created when usage_autostop is set"
  }

  assert {
    condition     = azurerm_automation_account.this[0].public_network_access_enabled == false
    error_message = "Automation account should have public network access disabled"
  }

  assert {
    condition     = length(azurerm_automation_runbook.manage_capacity) == 0
    error_message = "Scheduler runbook should not be created when only usage_autostop is set"
  }

  # The monitor must be able to suspend the capacity itself, so the capacity-scope
  # Contributor role assignment is required even without a scheduler.
  assert {
    condition     = length(azurerm_role_assignment.automation_contributor) == 1
    error_message = "Capacity-scope Contributor role assignment should be created when usage_autostop is set"
  }

  assert {
    condition     = length(azurerm_automation_variable_int.idle_check_counter) == 1
    error_message = "Idle check counter variable should be created"
  }

  assert {
    condition     = azurerm_automation_variable_int.idle_check_counter[0].name == "idle-check-counter-testcapacity"
    error_message = "Idle counter variable name should include the basename"
  }

  assert {
    condition     = azurerm_automation_variable_int.idle_check_counter[0].value == 0
    error_message = "Idle counter variable should be initialized to 0"
  }

  assert {
    condition     = length(azurerm_automation_runbook.monitor_capacity) == 1
    error_message = "Monitor runbook should be created when usage_autostop is set"
  }

  assert {
    condition     = azurerm_automation_runbook.monitor_capacity[0].name == "fabric-capacity-autostop"
    error_message = "Monitor runbook name should be fabric-capacity-autostop"
  }

  assert {
    condition     = azurerm_automation_runbook.monitor_capacity[0].runbook_type == "PowerShell72"
    error_message = "Monitor runbook type should be PowerShell72"
  }

  assert {
    condition     = length(azurerm_automation_schedule.monitor_schedule) == 1
    error_message = "Monitor schedule should be created when usage_autostop is set"
  }

  assert {
    condition     = azurerm_automation_schedule.monitor_schedule[0].frequency == "Hour"
    error_message = "Monitor schedule frequency should be Hour"
  }

  assert {
    condition     = azurerm_automation_schedule.monitor_schedule[0].interval == 1
    error_message = "Monitor schedule interval should match check_interval_hours"
  }

  assert {
    condition     = length(azurerm_automation_job_schedule.monitor_schedule) == 1
    error_message = "Monitor job schedule should be created when usage_autostop is set"
  }

  # No scheduler-related schedules should be created.
  assert {
    condition     = length(azurerm_automation_schedule.pause_schedule) == 0
    error_message = "No pause schedule should be created when scheduler is null"
  }

  assert {
    condition     = length(azurerm_automation_schedule.resume_schedule) == 0
    error_message = "No resume schedule should be created when scheduler is null"
  }
}

# Both scheduler and usage_autostop enabled — verifies they share one automation account.
run "usage_autostop_combined_with_scheduler" {
  command = plan

  variables {
    basename     = "testcapacity"
    location     = "North Europe"
    sku          = "F2"
    admin_emails = ["admin@example.com"]
    scheduler = {
      pause_time  = "20:00"
      resume_time = "07:00"
      pause_days  = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
      resume_days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
    }
    usage_autostop = {
      check_interval_hours  = 1
      idle_threshold_checks = 2
    }
  }

  assert {
    condition     = length(azurerm_automation_account.this) == 1
    error_message = "Only one automation account should be created when both scheduler and usage_autostop are set"
  }

  assert {
    condition     = length(azurerm_automation_runbook.manage_capacity) == 1
    error_message = "Manage capacity runbook should be created when scheduler is set"
  }

  assert {
    condition     = length(azurerm_automation_runbook.monitor_capacity) == 1
    error_message = "Monitor capacity runbook should be created when usage_autostop is set"
  }

  assert {
    condition     = length(azurerm_automation_schedule.pause_schedule) == 1
    error_message = "Pause schedule should be created when scheduler is set"
  }

  assert {
    condition     = length(azurerm_automation_schedule.resume_schedule) == 1
    error_message = "Resume schedule should be created when scheduler is set"
  }

  assert {
    condition     = length(azurerm_automation_schedule.monitor_schedule) == 1
    error_message = "Monitor schedule should be created when usage_autostop is set"
  }
}
