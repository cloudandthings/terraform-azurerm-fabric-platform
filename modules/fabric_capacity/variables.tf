variable "location" {
  type        = string
  description = "Location of the resource group and modules"
  default     = "North Europe"
}

variable "basename" {
  type        = string
  description = "Base name for module resources"
  default     = "test"
}

variable "sku" {
  type        = string
  description = "F SKU"
  default     = "F2"
}

variable "admin_emails" {
  type        = list(string)
  description = "List of admin email addresses"
  default     = []
}

variable "scheduler" {
  description = "Optional schedule for automated pause/resume of the Fabric Capacity. Set to null to disable."
  default     = null
  type = object({
    pause_time  = string # "HH:MM" UTC
    resume_time = string # "HH:MM" UTC
    pause_days  = optional(list(string), ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"])
    resume_days = optional(list(string), ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"])
  })

  validation {
    condition = var.scheduler == null || can(regex(
      "^([01][0-9]|2[0-3]):[0-5][0-9]$",
      var.scheduler.pause_time
    ))
    error_message = "scheduler.pause_time must be in HH:MM (24h UTC) format, e.g. \"20:00\"."
  }

  validation {
    condition = var.scheduler == null || can(regex(
      "^([01][0-9]|2[0-3]):[0-5][0-9]$",
      var.scheduler.resume_time
    ))
    error_message = "scheduler.resume_time must be in HH:MM (24h UTC) format, e.g. \"07:00\"."
  }

  validation {
    condition = var.scheduler == null || try(
      length(var.scheduler.pause_days) > 0 && alltrue([
        for d in var.scheduler.pause_days : contains(
          ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], d
        )
      ]),
      false
    )
    error_message = "scheduler.pause_days must be a non-empty list of valid weekday names: Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday."
  }

  validation {
    condition = var.scheduler == null || try(
      length(var.scheduler.resume_days) > 0 && alltrue([
        for d in var.scheduler.resume_days : contains(
          ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], d
        )
      ]),
      false
    )
    error_message = "scheduler.resume_days must be a non-empty list of valid weekday names: Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday."
  }
}

variable "usage_autostop" {
  description = "Optional usage-based auto-pause configuration. Polls accessible Fabric workspaces for active job instances on a recurring schedule and suspends the capacity when it has been idle for a sustained period. Set to null to disable. NOTE: only scheduled/triggered Fabric job instances are detected (pipeline runs, dataflow Gen2 refreshes, copy jobs, notebook runs, Spark Job Definition runs, lakehouse table maintenance, semantic model refreshes). The following activity is NOT detected and will not prevent suspension: interactive SQL queries against Warehouses or Lakehouse SQL endpoints; interactive KQL queries against Eventhouses, KQL Databases, or KQL Querysets; Eventstream continuous ingestion; Activator (Reflex) rule evaluation; Real-Time Dashboards; interactive notebook sessions or Spark Livy sessions; Power BI report rendering / DirectQuery / Direct Lake reads; paginated reports; Mirrored Database continuous replication."
  default     = null
  type = object({
    check_interval_hours  = optional(number, 1) # How often to poll: 1–24 hours
    idle_threshold_checks = optional(number, 2) # Consecutive idle polls before suspending
  })

  validation {
    condition = var.usage_autostop == null || (
      var.usage_autostop.check_interval_hours >= 1 &&
      var.usage_autostop.check_interval_hours <= 24 &&
      floor(var.usage_autostop.check_interval_hours) == var.usage_autostop.check_interval_hours
    )
    error_message = "usage_autostop.check_interval_hours must be a whole number between 1 and 24."
  }

  validation {
    condition = var.usage_autostop == null || (
      var.usage_autostop.idle_threshold_checks >= 1 &&
      floor(var.usage_autostop.idle_threshold_checks) == var.usage_autostop.idle_threshold_checks
    )
    error_message = "usage_autostop.idle_threshold_checks must be a whole number of 1 or more."
  }
}