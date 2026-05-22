<#
.SYNOPSIS
    Pauses or resumes an Azure Fabric Capacity on a schedule.

.DESCRIPTION
    Runs inside an Azure Automation Account (runbook: fabric-capacity-scheduler) using
    a System-Assigned Managed Identity.
    The identity requires Contributor on the Fabric Capacity resource.

.PARAMETER SubscriptionId
    The Azure subscription containing the Fabric Capacity.

.PARAMETER ResourceGroupName
    The resource group containing the Fabric Capacity.

.PARAMETER CapacityName
    The name of the Fabric Capacity resource.

.PARAMETER Mode
    Pause  — Suspend the capacity (no-op if already paused).
    Resume — Resume the capacity  (no-op if already active).
#>

param (
    [Parameter(Mandatory = $true)]  [string] $SubscriptionId,
    [Parameter(Mandatory = $true)]  [string] $ResourceGroupName,
    [Parameter(Mandatory = $true)]  [string] $CapacityName,
    [Parameter(Mandatory = $true)]  [ValidateSet("Pause", "Resume")] [string] $Mode
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Output "Authenticating with Managed Identity..."
Connect-AzAccount -Identity | Out-Null

$token   = (Get-AzAccessToken -ResourceUrl "https://management.azure.com/" -AsSecureString:$false).Token
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }

$baseUrl    = "https://management.azure.com"
$apiVersion = "2023-11-01"
$resourceId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Fabric/capacities/$CapacityName"

# Get current state
$capacity = Invoke-RestMethod -Method Get -Uri "$baseUrl$resourceId`?api-version=$apiVersion" -Headers $headers
$state    = $capacity.properties.state
Write-Output "Current state: $state"

switch ($Mode) {
    "Pause" {
        if ($state -eq "Active") {
            Write-Output "Suspending capacity '$CapacityName'..."
            Invoke-RestMethod -Method Post -Uri "$baseUrl$resourceId/suspend?api-version=$apiVersion" -Headers $headers | Out-Null
            Write-Output "Suspend request accepted."
        } else {
            Write-Output "Capacity is already in state '$state'. No action taken."
        }
    }
    "Resume" {
        if ($state -eq "Paused") {
            Write-Output "Resuming capacity '$CapacityName'..."
            Invoke-RestMethod -Method Post -Uri "$baseUrl$resourceId/resume?api-version=$apiVersion" -Headers $headers | Out-Null
            Write-Output "Resume request accepted."
        } else {
            Write-Output "Capacity is already in state '$state'. No action taken."
        }
    }
}

Write-Output "Done."
