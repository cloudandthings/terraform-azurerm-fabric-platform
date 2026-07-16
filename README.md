# Terraform Azure Fabric Platform

**A composable Terraform module for provisioning Microsoft Fabric capacities, domains, and workspaces — with built-in cost controls.**

[![Terraform Registry](https://img.shields.io/badge/Terraform_Registry-published-844FBA?logo=terraform&logoColor=white)](https://registry.terraform.io/modules/cloudandthings/fabric-platform/azurerm/latest)
[![Terraform](https://img.shields.io/badge/Terraform-%E2%89%A5_1.7.0-844FBA?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Fabric Provider](https://img.shields.io/badge/microsoft%2Ffabric-1.10.0-0078D4?logo=microsoftazure&logoColor=white)](https://registry.terraform.io/providers/microsoft/fabric/latest)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white)](https://pre-commit.com/)

---

## ✨ Features

- 🏗️ **Composable design** — use the full root module or pick individual sub-modules
- 💸 **Scheduled pause/resume** — automate weekly capacity downtime to cut costs
- 🛌 **Usage-based auto-pause** — suspend idle capacities based on Fabric job activity
- 🌐 **Domain & workspace management** — organize Fabric resources at scale
- 🔐 **Managed-identity workflow** — no secrets stored in Terraform state
- ✅ **Pre-commit & CI ready** — fmt, validate, tflint, checkov out of the box

## 📑 Table of Contents

- [Quick Start](#-quick-start)
- [Requirements](#-requirements)
- [Providers](#-providers)
- [Usage](#-usage)
  - [Root module](#root-module-all-resources)
  - [Sub-modules in isolation](#sub-modules-in-isolation)
- [Modules](#-modules)
- [Inputs](#-inputs)
- [Outputs](#-outputs)
- [Capacity Scheduler](#-capacity-scheduler)
- [Usage-based Auto-pause](#-usage-based-auto-pause-autostop)
- [Architecture](#-architecture)
- [Notes & Caveats](#-notes--caveats)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🚀 Quick Start

> **Tip:** This module is published to the [Terraform Registry](https://registry.terraform.io/modules/cloudandthings/fabric-platform/azurerm/latest). Pin to a released version in production.

```hcl
module "fabric" {
  source  = "cloudandthings/fabric-platform/azurerm"
  version = "~> 1.1"

  fabric_capacities = {
    "prod-capacity" = {
      location     = "eastus2"
      sku          = "F2"
      admin_emails = ["admin@yourdomain.com"]
    }
  }

  domains = {
    "analytics" = {
      description = "Analytics domain"
      admin_principals = [{ id = "00000000-0000-0000-0000-000000000000", type = "User" }]
    }
  }

  workspaces = {
    "sales-bi" = {
      capacity_basename = "prod-capacity"
      domain_name       = "analytics"
    }
  }

  providers = {
    fabric  = fabric
    azurerm = azurerm
    azuread = azuread
    time    = time
  }
}
```

---

## 📋 Requirements

| Tool | Version |
|---|---|
| [Terraform](https://www.terraform.io/) | `>= 1.7.0` |
| [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/) | latest (for `az login` authentication) |
| Microsoft Fabric tenant | with appropriate admin permissions |
| Azure subscription | with permissions to create Fabric capacities |

## 🔌 Providers

Configure these providers in your own root module and pass them to this module via the `providers` argument:

| Provider | Version | Required by |
|---|---|---|
| [`microsoft/fabric`](https://registry.terraform.io/providers/microsoft/fabric/latest) | `1.10.0` | `fabric_domain`, `fabric_workspace` |
| [`hashicorp/azurerm`](https://registry.terraform.io/providers/hashicorp/azurerm/latest) | `>= 3.98.0` | `fabric_capacity` |
| [`hashicorp/azuread`](https://registry.terraform.io/providers/hashicorp/azuread/latest) | `>= 2.47.0` | `fabric_capacity` |
| [`hashicorp/time`](https://registry.terraform.io/providers/hashicorp/time/latest) | `>= 0.9.0` | `fabric_capacity` |

Authenticate with `az login` before running `terraform apply`.

> **Important:** The `fabric` provider must be configured with `preview = true` to enable Fabric preview features used by this module.

---

## 📦 Usage

### Root module (all resources)

```hcl
# provider.tf
provider "fabric" {
  tenant_id = "00000000-0000-0000-0000-000000000000"
  use_cli   = true
  preview   = true
}

provider "azurerm" {
  features {}
  subscription_id = "00000000-0000-0000-0000-000000000000"
}

provider "azuread" {
  tenant_id = "00000000-0000-0000-0000-000000000000"
}
```

```hcl
# main.tf
module "fabric" {
  source  = "cloudandthings/fabric-platform/azurerm"
  version = "~> 1.0"

  fabric_capacities = {
    "test001" = {
      location     = "eastus2"
      sku          = "F2"
      admin_emails = ["admin@yourdomain.com"]

      scheduler = {
        pause_time  = "20:00"
        resume_time = "07:00"
        pause_days  = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
        resume_days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
      }

      usage_autostop = {
        check_interval_hours  = 1
        idle_threshold_checks = 2
      }
    }
  }

  domains = {
    "test-domain" = {
      description = "This is a test domain"
      admin_principals = [
        { id = "user-object-id-here", type = "User" }
      ]
    }
  }

  workspaces = {
    "test-workspace" = {
      description       = "This is a test workspace"
      capacity_basename = "test001"
      domain_name       = "test-domain"
    }
  }

  providers = {
    fabric  = fabric
    azurerm = azurerm
    azuread = azuread
    time    = time
  }
}
```

### Sub-modules in isolation

**Capacity only** — no `fabric` provider required

```hcl
module "my_capacity" {
  source  = "cloudandthings/fabric-platform/azurerm//modules/fabric_capacity"
  version = "~> 1.0"

  basename     = "my-capacity"
  location     = "eastus2"
  sku          = "F2"
  admin_emails = ["admin@yourdomain.com"]

  providers = {
    azurerm = azurerm
    azuread = azuread
    time    = time
  }
}
```

**Domain only**

```hcl
module "my_domain" {
  source  = "cloudandthings/fabric-platform/azurerm//modules/fabric_domain"
  version = "~> 1.0"

  display_name = "my-domain"
  description  = "My Fabric domain"
  admin_principals = [
    { id = "user-object-id-here", type = "User" }
  ]

  providers = {
    fabric = fabric
  }
}
```

**Workspace only**

```hcl
module "my_workspace" {
  source  = "cloudandthings/fabric-platform/azurerm//modules/fabric_workspace"
  version = "~> 1.0"

  display_name = "my-workspace"
  capacity_id  = "/subscriptions/.../resourceGroups/.../providers/Microsoft.Fabric/capacities/my-capacity"

  providers = {
    fabric = fabric
  }
}
```

---

## 🧩 Modules

| Module | Description | Required providers |
|---|---|---|
| [`fabric_capacity`](modules/fabric_capacity) | Azure Fabric capacity + optional cost-control automation | `azurerm`, `azuread`, `time` |
| [`fabric_domain`](modules/fabric_domain) | Fabric domain with admin role assignments | `fabric` |
| [`fabric_workspace`](modules/fabric_workspace) | Fabric workspace bound to a capacity (and optionally a domain) | `fabric` |

---

## 📥 Inputs

### Root module

| Name | Description | Type | Required |
|---|---|---|:---:|
| `fabric_capacities` | Map of Fabric capacities to create, keyed by capacity name. See [capacity attributes](#capacity-attributes). | `map(object)` | yes |
| `domains` | Map of Fabric domains, keyed by domain name. See [domain attributes](#domain-attributes). | `map(object)` | yes |
| `workspaces` | Map of Fabric workspaces, keyed by workspace name. See [workspace attributes](#workspace-attributes). | `map(object)` | yes |

#### Capacity attributes

| Attribute | Description | Type | Default |
|---|---|---|---|
| `location` | Azure region for the capacity. | `string` | — |
| `sku` | Fabric capacity SKU (e.g. `F2`, `F32`, `F64`, `F128`). | `string` | — |
| `admin_emails` | Administrator email addresses. | `list(string)` | — |
| `scheduler` | Optional weekly pause/resume schedule. See [Capacity Scheduler](#-capacity-scheduler). | `object` | `null` |
| `scheduler.pause_time` | Pause time in `HH:MM` UTC format. | `string` | — |
| `scheduler.resume_time` | Resume time in `HH:MM` UTC format. Omit to disable the resume schedule and only ever pause automatically. | `string` | `null` |
| `scheduler.pause_days` | Weekdays on which to pause. | `list(string)` | all days |
| `scheduler.resume_days` | Weekdays on which to resume. Ignored if `resume_time` is omitted. | `list(string)` | all days |
| `usage_autostop` | Optional usage-based auto-pause. See [Usage-based Auto-pause](#-usage-based-auto-pause-autostop). | `object` | `null` |
| `usage_autostop.check_interval_hours` | Poll frequency (1–24 hours). | `number` | `1` |
| `usage_autostop.idle_threshold_checks` | Consecutive idle polls before suspending. | `number` | `2` |

#### Domain attributes

| Attribute | Description | Type | Default |
|---|---|---|---|
| `description` | Description of the domain. | `string` | `""` |
| `parent_domain_id` | ID of the parent domain (for nested domains). | `string` | `""` |
| `admin_principals` | `[{ id, type }]` — Azure AD principal object IDs and type (`User` or `Group`). | `list(object)` | — |

#### Workspace attributes

| Attribute | Description | Type | Default |
|---|---|---|---|
| `description` | Description of the workspace. | `string` | `""` |
| `capacity_basename` | Key into `fabric_capacities` that this workspace binds to. | `string` | — |
| `domain_name` | Key into `domains`. Omit to skip domain assignment. | `string` | `""` |

### Sub-module: `fabric_capacity`

| Name | Description | Type | Default |
|---|---|---|---|
| `basename` | Base name used for resource group, capacity, and automation resources. | `string` | — |
| `location` | Azure region. | `string` | `"North Europe"` |
| `sku` | Fabric capacity SKU. | `string` | `"F2"` |
| `admin_emails` | Administrator email addresses. | `list(string)` | — |
| `scheduler` | See [capacity attributes](#capacity-attributes). | `object` | `null` |
| `usage_autostop` | See [capacity attributes](#capacity-attributes). | `object` | `null` |

### Sub-module: `fabric_domain`

| Name | Description | Type | Default |
|---|---|---|---|
| `display_name` | Display name of the Fabric domain. | `string` | — |
| `description` | Description of the domain. | `string` | `""` |
| `parent_domain_id` | Parent domain ID for nested domains. | `string` | `""` |
| `admin_principals` | `[{ id, type }]` admin principals. | `list(object)` | — |

### Sub-module: `fabric_workspace`

| Name | Description | Type | Default |
|---|---|---|---|
| `display_name` | Workspace display name. | `string` | — |
| `description` | Workspace description. | `string` | `""` |
| `capacity_id` | Azure resource ID of the Fabric capacity to bind to. | `string` | — |
| `fabric_domain_id` | ID of the Fabric domain to assign to. | `string` | `null` |
| `assign_to_domain` | Whether to assign the workspace to a domain. | `bool` | `false` |
| `monitor_principal_id` | Managed identity principal ID to add as workspace `Member` (typically from `fabric_capacity.monitor_principal_id`). | `string` | `null` |

---

## 📤 Outputs

### Sub-module: `fabric_capacity`

| Name | Description |
|---|---|
| `id` | Azure resource ID of the Fabric capacity. |
| `automation_account_id` | Azure resource ID of the Automation Account. `null` when both `scheduler` and `usage_autostop` are disabled. |
| `monitor_principal_id` | Principal ID of the Automation Account's managed identity. `null` when `usage_autostop` is disabled. |

### Sub-module: `fabric_domain`

| Name | Description |
|---|---|
| `id` | ID of the Fabric domain. |

---

## ⏰ Capacity Scheduler

When `scheduler` is configured, the `fabric_capacity` module provisions Azure resources to automate capacity cost management:

- 🤖 **Azure Automation Account** with a System-Assigned Managed Identity
- 🔑 **Role Assignment** — `Contributor` access on the Fabric Capacity
- 📜 **PowerShell 7.2 Runbook** ([`capacity_scheduler.ps1`](modules/fabric_capacity/scripts/capacity_scheduler.ps1)) — authenticates via Managed Identity and calls the Azure Management API
- 📅 **One or two weekly schedules** — a pause schedule always, plus a resume schedule only if `resume_time` is set

> **Note:** The runbook is idempotent — it checks the current capacity state before acting and skips the API call if the capacity is already in the target state.

> **Tip:** Omit `resume_time` to get a pause-only schedule — useful for a capacity you otherwise leave running, where you just want it automatically paused (e.g. overnight/weekends) to save cost. When you need it again, resume it manually (Azure Portal, CLI, or by running the `fabric-capacity-scheduler` runbook with `mode = "Resume"`); it stays running until the pause schedule fires again.

## 🛌 Usage-based Auto-pause (autostop)

When `usage_autostop` is configured, the module deploys an additional runbook ([`capacity_autostop.ps1`](modules/fabric_capacity/scripts/capacity_autostop.ps1)) that polls accessible Fabric workspaces for active job instances and suspends the capacity after sustained idle time.

> **Warning:** The Fabric Jobs API only reports **scheduled or triggered job instances**. Interactive and continuous workloads are invisible to this API and will **not** prevent suspension.

**Detected activity** (will prevent suspension)

| Workload | Activity |
|---|---|
| Data Factory | Data pipeline runs, Dataflow Gen2 refreshes, Copy Job runs |
| Data Engineering | Notebook runs (scheduled / triggered), Spark Job Definition runs, Lakehouse table maintenance (OPTIMIZE / VACUUM) |
| Data Science | ML Experiment / ML Model training jobs (when triggered as jobs) |
| Data Warehouse | Semantic model (dataset) refreshes |
| Real-Time Intelligence | KQL Database commands triggered as job instances, Mirrored Database initial snapshots (where exposed as jobs) |

**NOT detected activity** (capacity may be suspended while in use)

| Workload | Activity |
|---|---|
| Data Warehouse / SQL | Interactive SQL queries against Fabric Warehouses; queries against the Lakehouse SQL analytics endpoint |
| Real-Time Intelligence | Interactive KQL queries against Eventhouses, KQL Databases, KQL Querysets; Eventstream continuous ingestion; Activator (Reflex) rule evaluation; Real-Time Dashboards |
| Data Engineering | Interactive notebook sessions; Spark interactive sessions / Livy endpoint usage |
| Power BI / Data Science | Power BI report rendering, DirectQuery / Direct Lake reads, paginated reports; interactive ML Experiment exploration |
| Mirrored Database | Continuous change-data replication |

> **Tip:** For workloads dominated by interactive SQL, KQL, Power BI, or streaming usage, the `scheduler` option is safer — it pauses at predictable off-hours rather than relying on incomplete activity detection.

The managed identity must be a **Member** of every Fabric workspace it monitors. Workspaces created by this module are added automatically; any others must be added manually via the Fabric Admin Portal.

---

## 🏛️ Architecture

```
Azure Resource Group
├── Fabric Capacity
└── Automation Account
    ├── Managed Identity ──(Contributor)──► Fabric Capacity
    ├── Scheduler Runbook ──(Pause/Resume on schedule)──► Fabric Capacity
    └── Autostop Runbook  ──(Suspend when idle)──► Fabric Capacity

Fabric Domain
└── Fabric Workspace ◄──(capacity_id)── Fabric Capacity
                     ◄──(Workspace Member)── Automation Account
```

The solution creates a hierarchical structure:

1. **Azure Resource Groups** — container for Azure resources
2. **Fabric Capacities** — compute resources for Fabric workloads
3. **Fabric Domains** — organizational units for governance
4. **Fabric Workspaces** — development environments bound to capacities and domains

**Dependency order:** domains and capacities are created independently; workspaces depend on both.

---

## 📝 Notes & Caveats

- 🔐 The `fabric` provider should be configured with `preview = true` to enable preview features
- 👥 Admin emails and principal IDs must exist as valid users/groups in your Azure AD tenant
- 🌍 Fabric capacities are only available in [specific Azure regions](https://learn.microsoft.com/en-us/fabric/admin/region-availability)
- 🏷️ The `fabric_workspace` module extracts capacity names from Azure resource IDs for Fabric provider compatibility

---

## 🤝 Contributing

> This section applies to **contributors only**. End users do not need to clone the repo.

### Prerequisites

- [mise](https://mise.jdx.dev/) — manages all required tools (Terraform, tflint, Azure CLI, pre-commit, checkov)

### Setup

```bash
mise run setup
```

This installs all required tools at the correct versions and activates the pre-commit hooks.

### Pre-commit Hooks

Hooks run automatically on every `git commit` via [pre-commit-terraform](https://github.com/antonbabenko/pre-commit-terraform):

| Hook | Purpose |
|---|---|
| `terraform_fmt` | Formats all `.tf` files |
| `terraform_validate` | Validates Terraform configuration |
| `terraform_tflint` | Lints with tflint |
| `terraform_checkov` | Static security analysis |

Run all hooks manually:

```bash
pre-commit run --all-files
```

### Project Structure

```
.
├── main.tf                     # Root module: wires fabric_capacity, fabric_domain, fabric_workspace
├── variables.tf                # Root module variable definitions
├── locals.tf                   # Root module locals (domain ID lookup)
├── provider.tf                 # required_providers declaration
├── modules/
│   ├── fabric_capacity/        # Azure Fabric capacity module
│   │   └── scripts/            # PowerShell runbooks for scheduler & autostop
│   ├── fabric_domain/          # Microsoft Fabric domain module
│   └── fabric_workspace/       # Microsoft Fabric workspace module
└── README.md
```

---

## 📄 License

Licensed under the [Apache License 2.0](LICENSE). See the [LICENSE](LICENSE) file for details.