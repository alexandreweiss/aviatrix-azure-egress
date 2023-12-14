resource "random_integer" "example" {
  min = 10000
  max = 99999
}

output "random_integer" {
  value = random_integer.example.result
}


resource "azurerm_storage_account" "aci-sa" {
  name                     = "acisa${random_integer.example.result}"
  resource_group_name      = azurerm_resource_group.vms_rg.name
  location                 = var.region
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
}

# Marketing application VM in the Marketing spoke vnet installing probes to external sites
# User Data bootstrap preparation

# data "template_file" "gatus-config-yaml" {
#   template = file("${path.module}/config.tpl")

#   vars = {
#     "accounting_vm_ip" = module.accounting_vm.vm_private_ip
#   }
#   filename = "config.yaml"
# }

resource "azurerm_storage_share" "aci-share" {
  name                 = "aci-config"
  storage_account_name = azurerm_storage_account.aci-sa.name
  quota                = 1
}

resource "local_file" "config-yaml" {
  filename = "config.yaml"
  content  = templatefile("${path.module}/config.tpl", { "accounting_vm_ip" = module.accounting_vm.vm_private_ip })
}
resource "azurerm_storage_share_file" "config_file" {
  name             = "config.yaml"
  content_type     = "text/yaml"
  source           = local_file.config-yaml.filename
  storage_share_id = azurerm_storage_share.aci-share.id
}

resource "azurerm_container_group" "container-group" {
  name                = "mktg-cg"
  resource_group_name = azurerm_resource_group.vms_rg.name
  location            = var.region
  depends_on          = [azurerm_subnet.aci-subnet, azurerm_storage_share_file.config_file]

  container {
    name   = "gatus"
    image  = "docker.io/aweiss4876/gatus-aviatrix:latest"
    cpu    = "1"
    memory = "1.5"
    ports {
      port     = 8080
      protocol = "TCP"
    }
    volume {
      name                 = "config"
      share_name           = "aci-config"
      mount_path           = "/config"
      storage_account_key  = azurerm_storage_account.aci-sa.primary_access_key
      storage_account_name = azurerm_storage_account.aci-sa.name
    }
  }
  exposed_port = [{
    port     = 8080
    protocol = "TCP"
  }]
  ip_address_type = "Private"
  subnet_ids      = [azurerm_subnet.aci-subnet.id]
  os_type         = "Linux"
}
