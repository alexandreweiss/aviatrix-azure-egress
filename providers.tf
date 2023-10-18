terraform {
  required_providers {
    aviatrix = {
      source = "AviatrixSystems/aviatrix"
    }
  }
}

# Configure Aviatrix provider
provider "aviatrix" {
  controller_ip = var.controller_ip
  username      = "admin"
  password      = var.controller_password
}

provider "azurerm" {
  features {
  }
}
