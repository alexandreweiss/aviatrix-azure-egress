# Creation of the Hub
module "azure_hub" {
  source  = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version = "2.5.1"

  cloud   = "azure"
  region  = var.region
  cidr    = "10.1.0.0/23"
  account = var.azure_account_name
  ha_gw   = false
  name    = "azure-hub"
}

# Creation of the Accounting application spoke and attachment to transit
module "azure_spoke_accounting" {
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version = "1.6.5"

  name       = "azure-acct-spoke"
  cloud      = "azure"
  region     = var.region
  cidr       = "10.1.2.0/24"
  account    = var.azure_account_name
  transit_gw = module.azure_hub.transit_gateway.gw_name
  attached   = true
  ha_gw      = false
  depends_on = [module.azure_hub]
}

# Creation of Marketing spoke vnet RG
resource "azurerm_resource_group" "marketing_spoke_rg" {
  location = var.region
  name     = "azure_mktg_spoke_rg"
}

# Creation of Marketing spoke vnet to include Azure Bastion, Aviatrix Spoke Gateway and the Marketing Application VM
resource "azurerm_virtual_network" "azure_spoke_marketing_vnet" {
  address_space       = ["10.1.3.0/24"]
  location            = var.region
  name                = "azure_spoke_mktg_vn"
  resource_group_name = azurerm_resource_group.marketing_spoke_rg.name
}

resource "azurerm_subnet" "gw-subnet" {
  address_prefixes     = ["10.1.3.0/28"]
  name                 = "avx-gw-subnet"
  resource_group_name  = azurerm_resource_group.marketing_spoke_rg.name
  virtual_network_name = azurerm_virtual_network.azure_spoke_marketing_vnet.name
}

resource "azurerm_subnet" "aci-subnet" {
  address_prefixes     = ["10.1.3.64/27"]
  name                 = "aci-subnet"
  resource_group_name  = azurerm_resource_group.marketing_spoke_rg.name
  virtual_network_name = azurerm_virtual_network.azure_spoke_marketing_vnet.name
  delegation {
    name = "delegation"
    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "mktg-app-subnet" {
  address_prefixes     = ["10.1.3.128/28"]
  name                 = "mktg-app-subnet"
  resource_group_name  = azurerm_resource_group.marketing_spoke_rg.name
  virtual_network_name = azurerm_virtual_network.azure_spoke_marketing_vnet.name
}

# Creation of route table to direct Internet breakout to None
resource "azurerm_route_table" "marketing_application_rt" {
  location            = var.region
  name                = "mktg_application_rt"
  resource_group_name = azurerm_resource_group.marketing_spoke_rg.name
  route {
    address_prefix = "0.0.0.0/0"
    name           = "internetDefaultBlackhole"
    next_hop_type  = "None"
  }

  # we need to ignore further update made by Aviatrix in Terraform state.
  lifecycle {
    ignore_changes = [
      route,
    ]
  }
}

# Attach route table to Marketing application subnet
resource "azurerm_subnet_route_table_association" "marketing_route_table_assoc" {
  count = var.isStep2 ? 1 : 0

  route_table_id = azurerm_route_table.marketing_application_rt.id
  subnet_id      = azurerm_subnet.mktg-app-subnet.id
}

# Attach route table to Marketing ACI application subnet
resource "azurerm_subnet_route_table_association" "marketing_aci_route_table_assoc" {
  count = var.isStep2 ? 1 : 0

  route_table_id = azurerm_route_table.marketing_application_rt.id
  subnet_id      = azurerm_subnet.aci-subnet.id
}

# Creation of the Marketing application spoke and attachment to transit
module "azure_spoke_marketing" {
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version = "1.6.5"
  count   = var.isStep2 ? 1 : 0

  name             = "azure-mktg-spoke"
  cloud            = "azure"
  region           = var.region
  account          = var.azure_account_name
  transit_gw       = module.azure_hub.transit_gateway.gw_name
  attached         = true
  resource_group   = azurerm_resource_group.marketing_spoke_rg.name
  ha_gw            = false
  use_existing_vpc = true
  vpc_id           = "${azurerm_virtual_network.azure_spoke_marketing_vnet.name}:${azurerm_resource_group.marketing_spoke_rg.name}:${azurerm_virtual_network.azure_spoke_marketing_vnet.guid}"
  gw_subnet        = azurerm_subnet.gw-subnet.address_prefixes[0]
  single_ip_snat   = true
  instance_size    = "Standard_B2ms"
  depends_on       = [azurerm_subnet_route_table_association.marketing_route_table_assoc]
}

resource "aviatrix_gateway_dnat" "dnat_rules_spoke_marketing" {
  count   = var.isStep2 ? 1 : 0
  gw_name = module.azure_spoke_marketing[0].spoke_gateway.gw_name

  dnat_policy {
    src_cidr          = var.source_ip
    dst_cidr          = "${module.azure_spoke_marketing[0].spoke_gateway.private_ip}/32"
    dnat_ips          = azurerm_container_group.container-group.ip_address
    dst_port          = "80"
    protocol          = "tcp"
    dnat_port         = "8080"
    apply_route_entry = true
  }
}

# Creation of test VMs
resource "azurerm_resource_group" "vms_rg" {
  location = var.region
  name     = "vms-rg"
}

# Accounting VM in Accounting spoke vnet
module "accounting_vm" {
  source              = "github.com/alexandreweiss/misc-tf-modules/azr-linux-vm"
  environment         = "acct"
  location            = var.region
  location_short      = var.region_short
  index_number        = 01
  resource_group_name = azurerm_resource_group.vms_rg.name
  subnet_id           = module.azure_spoke_accounting.vpc.private_subnets[0].subnet_id
  admin_ssh_key       = var.ssh_public_key
  depends_on = [
  ]
}

# Marketing application VM in the Marketing spoke vnet installing probes to external sites
# User Data bootstrap preparation

data "template_file" "gatus-config" {
  template = file("${path.module}/mktg-cloud-init.tpl")

  vars = {
    "accounting_vm_ip" = module.accounting_vm.vm_private_ip
  }
}

data "template_cloudinit_config" "config" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = data.template_file.gatus-config.rendered
  }
}

# Marketing VM with bootstrap script rendered as custom_data
module "marketing_vm" {
  source              = "github.com/alexandreweiss/misc-tf-modules/azr-linux-vm"
  environment         = "mktg"
  location            = var.region
  location_short      = var.region_short
  index_number        = 01
  resource_group_name = azurerm_resource_group.vms_rg.name
  subnet_id           = azurerm_subnet.mktg-app-subnet.id
  admin_ssh_key       = var.ssh_public_key
  custom_data         = data.template_cloudinit_config.config.rendered
}
