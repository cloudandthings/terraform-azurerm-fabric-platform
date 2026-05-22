output "id" {
  description = "The ID of the Fabric workspace"
  value       = fabric_workspace.workspace.id
}

output "display_name" {
  description = "Display name of the Fabric workspace"
  value       = fabric_workspace.workspace.display_name
}
