terraform {
  backend "azurerm" {    
  }

  required_providers {
    azurerm = {
      /* source  = "hashicorp/azurerm" */
      version = "~> 2.93"
    }
  }
}

# Set target subscription for deployment
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
