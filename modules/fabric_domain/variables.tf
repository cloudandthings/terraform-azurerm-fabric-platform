variable "display_name" {
  description = "The display name of the Fabric domain."
  type        = string
}

variable "description" {
  description = "The description of the Fabric domain."
  type        = string
  default     = ""
}

variable "parent_domain_id" {
  description = "The ID of the parent Fabric domain."
  type        = string
  default     = ""
}

variable "admin_principals" {
  description = "List of principals (users or groups) for administrators of the Fabric domain and associated workspaces."
  type = list(object({
    id   = string
    type = string
  }))
}