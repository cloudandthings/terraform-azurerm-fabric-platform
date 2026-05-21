locals {
  capacities = { for c in var.fabric_capacities : c.basename => c }
  workspaces = var.workspaces
}

# Create a map of domain display_name to module id for lookup
locals {
  domain_ids = { for k, v in module.fabric_domain : k => v.id }
}
