resource "azurerm_resource_group" "this" {
  name     = var.basename
  location = var.location
}

resource "azurerm_fabric_capacity" "this" {
  name                = var.basename
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location

  administration_members = var.admin_emails

  sku {
    name = var.sku
    tier = "Fabric"
  }

  tags = {
    environment = "test"
  }
}

# ---------------------------------------------------------------------------
# Scheduler: Azure Automation Account (opt-in via var.scheduler)
# ---------------------------------------------------------------------------

data "azurerm_client_config" "current" {}

resource "azurerm_automation_account" "this" {
  count                         = (var.scheduler != null || var.usage_autostop != null) ? 1 : 0
  name                          = "${var.basename}-automation"
  location                      = var.location
  resource_group_name           = azurerm_resource_group.this.name
  sku_name                      = "Basic"
  public_network_access_enabled = false

  identity {
    type = "SystemAssigned"
  }

  tags = {
    environment = "test"
  }
}

resource "azurerm_role_assignment" "automation_contributor" {
  count                = (var.scheduler != null || var.usage_autostop != null) ? 1 : 0
  scope                = azurerm_fabric_capacity.this.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_automation_account.this[0].identity[0].principal_id
}

resource "azurerm_automation_runbook" "manage_capacity" {
  count                   = var.scheduler != null ? 1 : 0
  name                    = "fabric-capacity-scheduler"
  location                = var.location
  resource_group_name     = azurerm_resource_group.this.name
  automation_account_name = azurerm_automation_account.this[0].name
  log_verbose             = false
  log_progress            = true
  runbook_type            = "PowerShell72"
  content                 = file("${path.module}/scripts/capacity_scheduler.ps1")
  description             = "Pauses or resumes the Fabric Capacity on a schedule."
}

# Stable timestamps used to produce a deterministic start_time for each schedule.
# Replacing triggers (when pause_time/pause_days or resume_time/resume_days change)
# destroys and recreates time_static, which in turn recreates the schedule with the
# updated settings. This avoids the need for ignore_changes = [start_time].
resource "time_static" "pause_schedule" {
  count = var.scheduler != null ? 1 : 0
  triggers = {
    basename   = var.basename
    pause_time = var.scheduler.pause_time
    pause_days = join(",", sort(var.scheduler.pause_days))
  }
}

resource "time_static" "resume_schedule" {
  count = var.scheduler != null ? 1 : 0
  triggers = {
    basename    = var.basename
    resume_time = var.scheduler.resume_time
    resume_days = join(",", sort(var.scheduler.resume_days))
  }
}

resource "azurerm_automation_schedule" "pause_schedule" {
  count                   = var.scheduler != null ? 1 : 0
  name                    = "${var.basename}-scheduled-pause"
  resource_group_name     = azurerm_resource_group.this.name
  automation_account_name = azurerm_automation_account.this[0].name
  frequency               = "Week"
  interval                = 1
  week_days               = var.scheduler.pause_days
  description             = "Pauses the capacity at ${var.scheduler.pause_time} UTC."
  start_time              = "${formatdate("YYYY-MM-DD", timeadd(time_static.pause_schedule[0].rfc3339, "24h"))}T${var.scheduler.pause_time}:00+00:00"
}

resource "azurerm_automation_job_schedule" "pause_schedule" {
  count                   = var.scheduler != null ? 1 : 0
  resource_group_name     = azurerm_resource_group.this.name
  automation_account_name = azurerm_automation_account.this[0].name
  schedule_name           = azurerm_automation_schedule.pause_schedule[0].name
  runbook_name            = azurerm_automation_runbook.manage_capacity[0].name

  parameters = {
    subscriptionid    = data.azurerm_client_config.current.subscription_id
    resourcegroupname = azurerm_resource_group.this.name
    capacityname      = var.basename
    mode              = "Pause"
  }
}

resource "azurerm_automation_schedule" "resume_schedule" {
  count                   = var.scheduler != null ? 1 : 0
  name                    = "${var.basename}-scheduled-resume"
  resource_group_name     = azurerm_resource_group.this.name
  automation_account_name = azurerm_automation_account.this[0].name
  frequency               = "Week"
  interval                = 1
  week_days               = var.scheduler.resume_days
  description             = "Resumes the capacity at ${var.scheduler.resume_time} UTC."
  start_time              = "${formatdate("YYYY-MM-DD", timeadd(time_static.resume_schedule[0].rfc3339, "24h"))}T${var.scheduler.resume_time}:00+00:00"
}

resource "azurerm_automation_job_schedule" "resume_schedule" {
  count                   = var.scheduler != null ? 1 : 0
  resource_group_name     = azurerm_resource_group.this.name
  automation_account_name = azurerm_automation_account.this[0].name
  schedule_name           = azurerm_automation_schedule.resume_schedule[0].name
  runbook_name            = azurerm_automation_runbook.manage_capacity[0].name

  parameters = {
    subscriptionid    = data.azurerm_client_config.current.subscription_id
    resourcegroupname = azurerm_resource_group.this.name
    capacityname      = var.basename
    mode              = "Resume"
  }
}

# ---------------------------------------------------------------------------
# Usage-based auto-pause (opt-in via var.usage_autostop)
# ---------------------------------------------------------------------------

# Persists the consecutive-idle-run count across runbook invocations.
# lifecycle.ignore_changes prevents Terraform from resetting the runtime value
# back to 0 on every apply.
resource "azurerm_automation_variable_int" "idle_check_counter" {
  count                   = var.usage_autostop != null ? 1 : 0
  name                    = "idle-check-counter-${var.basename}"
  resource_group_name     = azurerm_resource_group.this.name
  automation_account_name = azurerm_automation_account.this[0].name
  value                   = 0
  encrypted               = true
  description             = "Tracks consecutive idle checks for usage-based auto-pause of ${var.basename}. Managed at runtime by the fabric-capacity-autostop runbook."

  lifecycle {
    ignore_changes = [value]
  }
}

resource "azurerm_automation_runbook" "monitor_capacity" {
  count                   = var.usage_autostop != null ? 1 : 0
  name                    = "fabric-capacity-autostop"
  location                = var.location
  resource_group_name     = azurerm_resource_group.this.name
  automation_account_name = azurerm_automation_account.this[0].name
  log_verbose             = false
  log_progress            = true
  runbook_type            = "PowerShell72"
  content                 = file("${path.module}/scripts/capacity_autostop.ps1")
  description             = "Polls Fabric workspaces for active jobs and suspends the capacity when idle for a sustained period."
}

# Stable timestamp used to produce a deterministic start_time for the monitor schedule.
# Recreated (and the schedule along with it) when check_interval_hours changes.
resource "time_static" "monitor_schedule" {
  count = var.usage_autostop != null ? 1 : 0
  triggers = {
    basename             = var.basename
    check_interval_hours = var.usage_autostop.check_interval_hours
  }
}

resource "azurerm_automation_schedule" "monitor_schedule" {
  count                   = var.usage_autostop != null ? 1 : 0
  name                    = "${var.basename}-usage-monitor"
  resource_group_name     = azurerm_resource_group.this.name
  automation_account_name = azurerm_automation_account.this[0].name
  frequency               = "Hour"
  interval                = var.usage_autostop.check_interval_hours
  description             = "Polls Fabric workloads for idle state every ${var.usage_autostop.check_interval_hours} hour(s)."
  start_time              = "${formatdate("YYYY-MM-DD", timeadd(time_static.monitor_schedule[0].rfc3339, "24h"))}T00:00:00+00:00"
}

resource "azurerm_automation_job_schedule" "monitor_schedule" {
  count                   = var.usage_autostop != null ? 1 : 0
  resource_group_name     = azurerm_resource_group.this.name
  automation_account_name = azurerm_automation_account.this[0].name
  schedule_name           = azurerm_automation_schedule.monitor_schedule[0].name
  runbook_name            = azurerm_automation_runbook.monitor_capacity[0].name

  parameters = {
    subscriptionid      = data.azurerm_client_config.current.subscription_id
    resourcegroupname   = azurerm_resource_group.this.name
    capacityname        = var.basename
    idlethresholdchecks = tostring(var.usage_autostop.idle_threshold_checks)
  }
}
