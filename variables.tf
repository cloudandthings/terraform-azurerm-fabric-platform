variable "fabric_capacities" {
  type = map(object({
    location     = string
    sku          = string
    admin_emails = list(string)
    scheduler = optional(object({
      pause_time  = string
      resume_time = string
      pause_days  = optional(list(string), ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"])
      resume_days = optional(list(string), ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"])
    }), null)
    usage_autostop = optional(object({
      check_interval_hours  = optional(number, 1)
      idle_threshold_checks = optional(number, 2)
    }), null)
  }))
}

variable "domains" {
  type = map(object({
    description      = optional(string, "")
    parent_domain_id = optional(string, "")
    admin_principals = list(object({
      id   = string
      type = string
    }))
  }))
}

variable "workspaces" {
  type = map(object({
    description       = optional(string, "")
    capacity_basename = string
    domain_name       = optional(string, "")
  }))
}