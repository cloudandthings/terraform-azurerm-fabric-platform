locals {
  domain_ids = { for k, v in module.fabric_domain : k => v.id }
}
