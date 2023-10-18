variable "controller_ip" {
  description = "Define your Aviatrix controller IP address or FQDN"
}

variable "controller_password" {
  description = "Aviatrix controller administrator password"
  sensitive   = true
}

variable "azure_account_name" {
  description = "Name of the Azure account on Aviatrix controller pointing to the Azure subscription you want to deploy resources in"
}

variable "region" {
  description = "Azure region where you want to deploy resources to. Must be in the form 'West Europe' (with sapces)"
  default     = "West Europe"
}

variable "region_short" {
  description = "Short name of the region"
  default     = "we"
}

variable "ssh_public_key" {
  description = "SSH public key to access test VMs"
}
