# Tests that the fabric_workspace module correctly plans a Fabric workspace and its
# optional domain assignment and monitor role assignment. The fabric_capacity data
# source is mocked with state "Active" to satisfy the postcondition that guards
# against inactive capacities.
#
# Cases covered:
#   1. With a domain ID -> domain assignment resource is created
#   2. Without a domain ID (null) -> domain assignment is skipped entirely
#   3. With a monitor_principal_id -> workspace Member role assignment is created
#   4. Without a monitor_principal_id -> workspace role assignment is skipped
mock_provider "fabric" {
  mock_data "fabric_capacity" {
    defaults = {
      id    = "00000000-0000-0000-0000-000000000001"
      state = "Active"
    }
  }
}

# Verifies that the workspace is planned with the correct display name and description,
# and that a domain assignment is created referencing the provided domain ID.
run "workspace_planned_with_domain" {
  command = plan

  variables {
    display_name     = "Dev Workspace"
    description      = "Development workspace"
    capacity_id      = "/subscriptions/sub/resourceGroups/rg/providers/Microsoft.Fabric/capacities/test-capacity"
    fabric_domain_id = "00000000-0000-0000-0000-000000000002"
    assign_to_domain = true
  }

  assert {
    condition     = fabric_workspace.workspace.display_name == "Dev Workspace"
    error_message = "Workspace display name should match input"
  }

  assert {
    condition     = fabric_workspace.workspace.description == "Development workspace"
    error_message = "Workspace description should match input"
  }

  assert {
    condition     = fabric_domain_workspace_assignments.domain_assignment[0].domain_id == "00000000-0000-0000-0000-000000000002"
    error_message = "Domain assignment should reference the provided domain ID"
  }
}

# Verifies that no domain assignment resource is planned when fabric_domain_id is
# null, confirming the count = 0 conditional in main.tf works correctly.
run "workspace_planned_without_domain" {
  command = plan

  variables {
    display_name     = "Dev Workspace"
    description      = ""
    capacity_id      = "/subscriptions/sub/resourceGroups/rg/providers/Microsoft.Fabric/capacities/test-capacity"
    fabric_domain_id = null
    assign_to_domain = false
    # monitor_principal_id omitted (default null), enable_monitor_role_assignment defaults to false
  }

  assert {
    condition     = fabric_workspace.workspace.display_name == "Dev Workspace"
    error_message = "Workspace display name should match input"
  }

  assert {
    condition     = length(fabric_domain_workspace_assignments.domain_assignment) == 0
    error_message = "No domain assignment should be created when fabric_domain_id is null"
  }

  assert {
    condition     = length(fabric_workspace_role_assignment.monitor) == 0
    error_message = "No monitor role assignment should be created when enable_monitor_role_assignment is false"
  }
}

# Verifies that when monitor_principal_id is provided, a workspace Member role
# assignment is planned for that ServicePrincipal.
run "workspace_planned_with_monitor_principal" {
  command = plan

  variables {
    display_name                   = "Dev Workspace"
    description                    = ""
    capacity_id                    = "/subscriptions/sub/resourceGroups/rg/providers/Microsoft.Fabric/capacities/test-capacity"
    fabric_domain_id               = null
    assign_to_domain               = false
    monitor_principal_id           = "00000000-0000-0000-0000-000000000099"
    enable_monitor_role_assignment = true
  }

  assert {
    condition     = length(fabric_workspace_role_assignment.monitor) == 1
    error_message = "Monitor role assignment should be created when monitor_principal_id is set"
  }

  assert {
    condition     = fabric_workspace_role_assignment.monitor[0].role == "Member"
    error_message = "Monitor role assignment should grant the Member role"
  }

  assert {
    condition     = fabric_workspace_role_assignment.monitor[0].principal.id == "00000000-0000-0000-0000-000000000099"
    error_message = "Monitor role assignment principal ID should match input"
  }

  assert {
    condition     = fabric_workspace_role_assignment.monitor[0].principal.type == "ServicePrincipal"
    error_message = "Monitor role assignment principal type should be ServicePrincipal"
  }
}
