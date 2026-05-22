resource "fabric_domain" "domain" {
  display_name     = var.display_name
  description      = var.description
  parent_domain_id = var.parent_domain_id != "" ? var.parent_domain_id : null
}

resource "fabric_domain_role_assignments" "admin_role_assignments" {
  domain_id  = fabric_domain.domain.id
  role       = "Admins"
  principals = var.admin_principals
}