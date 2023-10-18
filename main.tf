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

resource "azurerm_subnet" "bastion-subnet" {
  address_prefixes     = ["10.1.3.64/27"]
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.marketing_spoke_rg.name
  virtual_network_name = azurerm_virtual_network.azure_spoke_marketing_vnet.name
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
  route_table_id = azurerm_route_table.marketing_application_rt.id
  subnet_id      = azurerm_subnet.mktg-app-subnet.id
}

# Creation of the Marketing application spoke and attachment to transit
module "azure_spoke_marketing" {
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version = "1.6.5"

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
  depends_on       = [module.azure_hub]
}

# # Creation of Azure Bastion to access Marketing application VM
# resource "azurerm_bastion_host" "bastion" {
#   location            = var.region
#   name                = "bastion"
#   resource_group_name = azurerm_resource_group.marketing_spoke_rg.name
#   ip_configuration {
#     name                 = "ipConfig"
#     public_ip_address_id = azurerm_public_ip.bastion_pip
#     subnet_id            = azurerm_subnet.bastion-subnet.id
#   }
# }

# resource "azurerm_public_ip" "bastion_pip" {
#   allocation_method   = "Static"
#   location            = var.region
#   name                = "bastion-pip"
#   resource_group_name = azurerm_resource_group.marketing_spoke_rg.name
# }

# Creation of test VMs
resource "azurerm_resource_group" "vms_rg" {
  location = var.region
  name     = "vms-rg"
}

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

module "marketing_vm" {
  source              = "github.com/alexandreweiss/misc-tf-modules/azr-linux-vm"
  environment         = "mktg"
  location            = var.region
  location_short      = var.region_short
  index_number        = 01
  resource_group_name = azurerm_resource_group.vms_rg.name
  subnet_id           = azurerm_subnet.mktg-app-subnet.id
  admin_ssh_key       = var.ssh_public_key
  depends_on = [
  ]
}
