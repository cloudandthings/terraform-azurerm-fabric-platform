<#
.SYNOPSIS
    Monitors a Fabric Capacity for idle state and suspends it when idle long enough.

.DESCRIPTION
    Runs inside an Azure Automation Account (runbook: fabric-capacity-autostop) using
    a System-Assigned Managed Identity.
    The identity requires Contributor on the Fabric Capacity resource (ARM) and must
    be added as a Fabric workspace member for each workspace that should be monitored
    (Fabric RBAC is managed separately via the Fabric Admin Portal).

    On each run the script:
      1. Skips execution if the capacity is already Paused.
      2. Queries the Fabric REST API for all accessible workspaces and checks each
         for InProgress or NotStarted job instances.
      3. Reads an Automation Variable ('idle-check-counter-<CapacityName>') that
         persists the consecutive-idle-run count across invocations.
      4. Increments the counter when no active jobs are found; resets it to 0 otherwise.
      5. Suspends the capacity and resets the counter when the counter reaches
         IdleThresholdChecks.

    DETECTED (will prevent suspension while running):
      Data Factory:
        - Data pipeline runs
        - Dataflow Gen2 refreshes
        - Copy Job runs
      Data Engineering:
        - Notebook runs (scheduled or triggered via API/pipeline)
        - Spark Job Definition runs
        - Lakehouse table maintenance (OPTIMIZE / VACUUM)
      Data Science:
        - ML Experiment runs and ML Model training jobs (when triggered as jobs)
      Data Warehouse / Real-Time Intelligence:
        - Semantic model (dataset) refreshes
        - KQL Database commands triggered as job instances
        - Mirrored Database initial snapshots (where exposed as jobs)

    NOT DETECTED (capacity may be suspended while these are in active use):
      Data Warehouse / SQL endpoints:
        - Interactive SQL queries against Fabric Warehouses
        - Interactive SQL queries against the Lakehouse SQL analytics endpoint
      Real-Time Intelligence:
        - Interactive KQL queries against Eventhouses / KQL Databases / KQL Querysets
        - Eventstream continuous ingestion (runs continuously, not as discrete jobs)
        - Activator (Reflex) rule evaluation
        - Real-Time Dashboards
      Data Engineering:
        - Interactive notebook sessions (a user running cells in the UI)
        - Spark interactive sessions / Livy endpoint usage
      Power BI / Data Science:
        - Power BI report rendering and DirectQuery / Direct Lake reads
        - Paginated report execution
        - Interactive ML Experiment exploration in notebooks
      Mirrored Database:
        - Continuous change-data replication (runs continuously, not as discrete jobs)
      Other:
        - Any item type that has not been published or registered with the Fabric
          Jobs API will not appear in /v1/workspaces/{id}/jobs/instances

    For workloads dominated by interactive SQL, KQL, Power BI, or streaming usage,
    the scheduler-based approach (var.scheduler) is safer as it pauses at predictable
    off-hours rather than relying on incomplete activity detection.

    NOTE: Any error during workspace or job-instance queries is treated conservatively
    (i.e., assumed active) to prevent accidental suspension during transient API failures.
    A workspace whose job query consistently fails (e.g. due to a transient Fabric API
    issue) will suppress auto-pause for the entire capacity for that run. The remaining
    workspaces are still checked; all per-workspace errors are logged.

.PARAMETER SubscriptionId
    The Azure subscription containing the Fabric Capacity.

.PARAMETER ResourceGroupName
    The resource group containing the Fabric Capacity.

.PARAMETER CapacityName
    The name of the Fabric Capacity resource.

.PARAMETER IdleThresholdChecks
    Number of consecutive idle checks required before suspending the capacity.
    Effective idle window = IdleThresholdChecks × check_interval_hours.
#>

param (
    [Parameter(Mandatory = $true)]  [string] $SubscriptionId,
    [Parameter(Mandatory = $true)]  [string] $ResourceGroupName,
    [Parameter(Mandatory = $true)]  [string] $CapacityName,
    [Parameter(Mandatory = $true)]  [int]    $IdleThresholdChecks
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Output "Authenticating with Managed Identity..."
Connect-AzAccount -Identity | Out-Null

# ARM API token — capacity state check and suspend call
$armToken   = (Get-AzAccessToken -ResourceUrl "https://management.azure.com/" -AsSecureString:$false).Token
$armHeaders = @{ Authorization = "Bearer $armToken"; "Content-Type" = "application/json" }

# Fabric REST API token — workspace and job instance queries
$fabricToken   = (Get-AzAccessToken -ResourceUrl "https://api.fabric.microsoft.com/" -AsSecureString:$false).Token
$fabricHeaders = @{ Authorization = "Bearer $fabricToken"; "Content-Type" = "application/json" }

$armBaseUrl    = "https://management.azure.com"
$fabricBaseUrl = "https://api.fabric.microsoft.com/v1"
$apiVersion    = "2023-11-01"
$resourceId    = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Fabric/capacities/$CapacityName"

# ---------------------------------------------------------------------------
# Step 1: Check current capacity state — skip if not Active
# ---------------------------------------------------------------------------
Write-Output "Checking current capacity state..."
$capacity = Invoke-RestMethod -Method Get -Uri "$armBaseUrl$resourceId`?api-version=$apiVersion" -Headers $armHeaders
$state    = $capacity.properties.state
Write-Output "Current state: $state"

if ($state -ne "Active") {
    Write-Output "Capacity is not Active (state='$state'). Nothing to do."
    exit 0
}

# ---------------------------------------------------------------------------
# Step 2: Enumerate accessible Fabric workspaces (with pagination)
# ---------------------------------------------------------------------------
Write-Output "Enumerating accessible Fabric workspaces..."
$workspaces      = [System.Collections.Generic.List[object]]::new()
$workspacesUri   = "$fabricBaseUrl/workspaces"

do {
    $response      = Invoke-RestMethod -Method Get -Uri $workspacesUri -Headers $fabricHeaders
    $workspacesUri = $response.PSObject.Properties['continuationUri']?.Value

    foreach ($ws in $response.value) {
        $workspaces.Add($ws)
    }
} while ($workspacesUri)

Write-Output "Found $($workspaces.Count) accessible workspace(s)."

# ---------------------------------------------------------------------------
# Step 3: Check each workspace for active job instances
# ---------------------------------------------------------------------------
$hasActiveJobs = $false
$queryError    = $false  # set when a workspace job query fails; suppresses suspension for this run

foreach ($workspace in $workspaces) {
    $wsId   = $workspace.id
    $wsName = $workspace.displayName

    Write-Output "Checking jobs in workspace '$wsName' ($wsId)..."

    try {
        $jobsUri   = "$fabricBaseUrl/workspaces/$wsId/jobs/instances"
        $pageCount = 0
        $maxPages  = 10  # bound execution time as job history grows (≈1 000–2 000 instances)

        do {
            $jobsResponse = Invoke-RestMethod -Method Get -Uri $jobsUri -Headers $fabricHeaders
            $jobsUri      = $jobsResponse.PSObject.Properties['continuationUri']?.Value
            $pageCount++

            $activeJobs = @($jobsResponse.value | Where-Object {
                $_.status -in @("InProgress", "NotStarted")
            })

            if ($activeJobs.Count -gt 0) {
                Write-Output "  Found $($activeJobs.Count) active job(s) — capacity is not idle."
                $hasActiveJobs = $true
                break
            }

            if ($pageCount -ge $maxPages -and $jobsUri) {
                # Page cap reached with more pages remaining — cannot confirm workspace is idle.
                # Treat as uncertain to avoid suspending while unseen jobs may exist.
                Write-Warning "  Page limit ($maxPages) reached for workspace '$wsName' — treating as uncertain."
                $queryError = $true
                break
            }
        } while ($jobsUri -and -not $hasActiveJobs)

        if (-not $hasActiveJobs -and -not $queryError) {
            Write-Output "  No active jobs."
        }
    }
    catch {
        if ($_.ErrorDetails.Message -match '"errorCode"\s*:\s*"EntityNotFound"') {
            # Fabric returns 404 EntityNotFound when a workspace has no job history. Treat as idle.
            Write-Output "  No job history in workspace '$wsName' — treating as idle."
        } else {
            # Log the error and continue checking remaining workspaces. Suspension will be
            # suppressed at the end of the run even if all other workspaces are idle.
            Write-Warning "  Could not query jobs for workspace '$wsName': $_"
            $queryError = $true
        }
    }

    if ($hasActiveJobs) { break }
}

# ---------------------------------------------------------------------------
# Step 4: Read and update the idle check counter Automation Variable
# ---------------------------------------------------------------------------
# Use the native runbook-context cmdlets (Get-AutomationVariable /
# Set-AutomationVariable) instead of the Az module equivalents. These cmdlets
# operate within the current Automation Account context, require no explicit
# account/RG parameters, and — crucially — can read encrypted variables.
# Set-AutomationVariable updates the value without touching the encryption
# attribute, so no Terraform drift occurs.
$counterVarName = "idle-check-counter-$CapacityName"

try {
    $currentCounter = [int](Get-AutomationVariable -Name $counterVarName)
}
catch {
    # Variable should always exist (Terraform creates it), but default to 0 for safety.
    Write-Warning "Automation Variable '$counterVarName' not found. Defaulting to 0."
    $currentCounter = 0
}

Write-Output "Current idle counter: $currentCounter (threshold: $IdleThresholdChecks)"

if ($hasActiveJobs) {
    $newCounter = 0
    Write-Output "Active jobs detected — resetting idle counter to 0."
}
elseif ($queryError) {
    $newCounter = 0
    Write-Warning "One or more workspace job queries failed — suppressing suspension this run. Idle counter reset to 0."
}
else {
    $newCounter = [int]$currentCounter + 1
    Write-Output "No active jobs — idle counter incremented to $newCounter."
}

Set-AutomationVariable -Name $counterVarName -Value $newCounter

# ---------------------------------------------------------------------------
# Step 5: Suspend the capacity if the idle threshold has been reached
# ---------------------------------------------------------------------------
if ($newCounter -ge $IdleThresholdChecks) {
    Write-Output "Idle threshold reached ($newCounter/$IdleThresholdChecks). Suspending capacity '$CapacityName'..."
    Invoke-RestMethod -Method Post -Uri "$armBaseUrl$resourceId/suspend?api-version=$apiVersion" -Headers $armHeaders | Out-Null
    Write-Output "Suspend request accepted."

    # Reset the counter so the next active window starts fresh.
    Set-AutomationVariable -Name $counterVarName -Value 0
    Write-Output "Idle counter reset to 0."
}
else {
    Write-Output "Idle threshold not yet reached ($newCounter/$IdleThresholdChecks). No action taken."
}

Write-Output "Done."
