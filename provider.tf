terraform {
  required_version = ">= 1.7.0"
  required_providers {
    fabric = {
      source  = "microsoft/fabric"
      version = "1.10.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.98.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 2.47.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }
  }
}