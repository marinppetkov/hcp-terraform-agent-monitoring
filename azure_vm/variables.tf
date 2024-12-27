variable "resource_group_name" {}

variable "location" {}

variable "usr_name" {
  default = "adminuser"
}

variable "agent_token" {
  description = "HCP Terraform agent token"
}

variable "address_prefix" {
  description = "Your public IP to allow network access to the Azure VM"
}