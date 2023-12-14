variable "controller_fqdn" {
  description = "FQDN or IP of the Aviatrix Controller"
  sensitive   = true
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

variable "isStep2" {
  description = "Deploy Marketing spoke and enforce egress after Marketing VM is bootstrapped"
  default     = true
}

variable "source_ip" {
  description = "Your source IP to surf the container throught MKTG spoke DNAT"
  default     = "81.49.43.155/32"
}
