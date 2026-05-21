module "fabric_capacity" {
  for_each       = local.capacities
  source         = "./modules/fabric_capacity"
  location       = each.value.location
  basename       = each.value.basename
  sku            = each.value.sku
  admin_emails   = each.value.admin_emails
  scheduler      = each.value.scheduler
  usage_autostop = each.value.usage_autostop

  providers = {
    azurerm = azurerm
    azuread = azuread
  }
}

module "fabric_domain" {
  for_each         = { for d in var.domains : d.display_name => d }
  source           = "./modules/fabric_domain"
  display_name     = each.value.display_name
  description      = each.value.description
  admin_principals = each.value.admin_principals
  parent_domain_id = each.value.parent_domain_id
}

module "fabric_workspace" {
  for_each                       = { for ws in local.workspaces : ws.display_name => ws }
  source                         = "./modules/fabric_workspace"
  display_name                   = each.value.display_name
  description                    = each.value.description
  capacity_id                    = module.fabric_capacity[each.value.capacity_basename].id
  fabric_domain_id               = try(local.domain_ids[each.value.domain_name], null)
  assign_to_domain               = try(each.value.domain_name, "") != ""
  monitor_principal_id           = module.fabric_capacity[each.value.capacity_basename].monitor_principal_id
  enable_monitor_role_assignment = module.fabric_capacity[each.value.capacity_basename].has_monitor
  depends_on                     = [module.fabric_capacity]
}
