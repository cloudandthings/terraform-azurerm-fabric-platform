variable "display_name" {
  description = "The name of the Fabric workspace"
  type        = string
}

variable "description" {
  description = "Description of the Fabric workspace"
  type        = string
  default     = ""
}

variable "capacity_id" {
  description = "The ID of the Fabric capacity to associate with the workspace"
  type        = string
}

variable "fabric_domain_id" {
  description = "The ID of the Fabric domain to associate with the workspace"
  type        = string
  default     = null
  nullable    = true
}

variable "assign_to_domain" {
  description = "Whether to assign the workspace to a Fabric domain. Must be known at plan time."
  type        = bool
  default     = false
}

variable "monitor_principal_id" {
  description = "Optional principal ID of the capacity monitor's managed identity to add as a Member of this workspace. Set to null to skip."
  type        = string
  default     = null
  nullable    = true
}

variable "enable_monitor_role_assignment" {
  description = "Whether to create a workspace Member role assignment for the monitor managed identity. Must be known at plan time; pass through from module.fabric_capacity.has_monitor."
  type        = bool
  default     = false
}
