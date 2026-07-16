variable "fabric_capacities" {
  description = "Map of Fabric capacities to create, keyed by capacity base name. Each entry provisions an Azure Resource Group, a Fabric Capacity, and optionally an Automation Account with scheduler and/or usage-based auto-pause runbooks."
  type = map(object({
    location     = string
    sku          = string
    admin_emails = list(string)
    scheduler = optional(object({
      pause_time  = string
      resume_time = optional(string)
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
  description = "Map of Fabric domains to create, keyed by domain name. Each entry provisions a Fabric domain and assigns the specified admin principals."
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
  description = "Map of Fabric workspaces to create, keyed by workspace name. Each entry provisions a Fabric workspace and binds it to a capacity and optionally a domain."
  type = map(object({
    description       = optional(string, "")
    capacity_basename = string
    domain_name       = optional(string, "")
  }))
}