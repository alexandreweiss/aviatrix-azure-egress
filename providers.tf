terraform {
  required_providers {
    aviatrix = {
      source = "AviatrixSystems/aviatrix"
    }
  }
  cloud {
    organization = "ananableu"
    workspaces {
      name = "aviatrix-azure-egress"
    }
  }
}

# Configure Aviatrix provider
data "dns_a_record_set" "controller_ip" {
  host = var.controller_fqdn
}

provider "aviatrix" {
  controller_ip           = data.dns_a_record_set.controller_ip.addrs[0]
  username                = "admin"
  password                = var.controller_password
  skip_version_validation = true
}

provider "azurerm" {
  features {
  }
}

provider "random" {}
