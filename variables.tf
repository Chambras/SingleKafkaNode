variable "location" {
  type        = string
  default     = "eastus2"
  description = "Azure region where resources are created."
}

variable "suffix" {
  type        = string
  default     = "bts"
  description = "Prefix/suffix added to resource names for identification."
}

variable "rgName" {
  type        = string
  default     = "SingleNodeRG"
  description = "Resource Group name (appended to var.suffix)."
}

variable "tags" {
  type = map(any)
  default = {
    "Environment" = "Dev"
    "Project"     = "BTS-SWIM"
    "BillingCode" = "Internal"
    "Customer"    = "DOT"
  }
  description = "Tags applied to all resources."
}

## Networking variables
variable "vnetName" {
  type        = string
  default     = "Main"
  description = "VNet name (appended to var.suffix)."
}

locals {
  base_cidr_block = "10.70.0.0/16"
}

variable "subnets" {
  type = map(any)
  default = {
    "workers"    = "1"
    "zookeeper"  = "2"
    "headnodes"  = "3"
    "management" = "4"
  }
  description = "Kafka-side subnets to create in the VNet. Values are the /24 octet index within base_cidr_block."
}

variable "dataBricksSubnets" {
  type = map(any)
  default = {
    "publicDB"  = "5"
    "privateDB" = "6"
  }
  description = "Databricks dedicated subnets for VNet injection."
}

## Security variables
variable "sourceIPs" {
  type        = list(string)
  default     = ["74.96.174.80"]
  description = "Public IPs allowed to reach admin ports (SSH, HTTP) on the Kafka VM. MUST be overridden per environment."
}

variable "workspaceName" {
  type        = string
  default     = "DBWokspaceSingleNode"
  description = "Databricks Workspace name (appended to var.suffix)."
}

## Storage
variable "storageAccountName" {
  type        = string
  default     = "btsclstrdataingested"
  description = "Storage account name. MUST be globally unique, 3-24 chars, lowercase letters and numbers only. An ADLS Gen2 account is also created with the suffix 'adsl'."
}

## VM
variable "vmUserName" {
  type        = string
  default     = "kafkaAdmin"
  description = "Admin username created on the Kafka VM."
}

variable "sshKeyPath" {
  type        = string
  default     = "~/.ssh/vm_ssh.pub"
  description = "Path to the SSH public key injected into the VM. Supports '~' expansion."
}
