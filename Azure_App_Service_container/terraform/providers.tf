terraform {
  required_version = ">= 1.3"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.80"
    }
  }
}

provider "azurerm" {
  subscription_id = "963f807f-7239-465c-99d3-148c75cc1b69"
  features {}
}
