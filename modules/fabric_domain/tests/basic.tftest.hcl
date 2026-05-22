# Tests that the fabric_domain module correctly plans a Fabric domain resource and
# its admin role assignment. Covers two cases:
#   1. A top-level domain (parent_domain_id empty -> null on the resource)
#   2. A sub-domain (parent_domain_id set -> passed through to the resource)
mock_provider "fabric" {}

# An empty parent_domain_id string should be converted to null so the provider
# does not attempt to set a parent. Also verifies display_name, description, and
# that the role assignment uses the "Admins" role.
run "domain_without_parent" {
  command = plan

  variables {
    display_name     = "Analytics"
    description      = "Analytics domain"
    parent_domain_id = ""
    admin_principals = [
      { id = "00000000-0000-0000-0000-000000000001", type = "User" }
    ]
  }

  assert {
    condition     = fabric_domain.domain.display_name == "Analytics"
    error_message = "Domain display name should match input"
  }

  assert {
    condition     = fabric_domain.domain.description == "Analytics domain"
    error_message = "Domain description should match input"
  }

  assert {
    condition     = fabric_domain.domain.parent_domain_id == null
    error_message = "Empty parent_domain_id string should result in null"
  }

  assert {
    condition     = fabric_domain_role_assignments.admin_role_assignments.role == "Admins"
    error_message = "Role assignment role should be Admins"
  }
}

# A non-empty parent_domain_id should be passed through unchanged to fabric_domain.
run "domain_with_parent" {
  command = plan

  variables {
    display_name     = "Sub-Domain"
    description      = ""
    parent_domain_id = "00000000-0000-0000-0000-000000000099"
    admin_principals = [
      { id = "00000000-0000-0000-0000-000000000001", type = "Group" }
    ]
  }

  assert {
    condition     = fabric_domain.domain.parent_domain_id == "00000000-0000-0000-0000-000000000099"
    error_message = "Parent domain ID should be passed through when set"
  }
}
