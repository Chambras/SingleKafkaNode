variable "location" {
  type        = string
  default     = "eastus2"
  description = "Azure region where resources are created."
}

variable "suffix" {
  type        = string
  default     = "mz"
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
    "Project"     = "Learning"
    "BillingCode" = "Internal"
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
  default     = ["74.96.174.80", "4.204.64.239", "40.117.67.16", "20.110.218.7"]
  description = "Public IPs allowed to reach admin ports (SSH, HTTP) on the Kafka VM. MUST be overridden per environment."
}

variable "workspaceName" {
  type        = string
  default     = "DBWorkspaceSingleNode"
  description = "Databricks Workspace name (appended to var.suffix)."
}

## Storage
variable "storageAccountName" {
  type        = string
  default     = "mzvclstrdataingested"
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

variable "vmImagePublisher" {
  type        = string
  default     = "RedHat"
  description = "Azure Marketplace publisher for the Kafka VM image."
}

variable "vmImageOffer" {
  type        = string
  default     = "RHEL"
  description = "Azure Marketplace offer for the Kafka VM image."
}

variable "vmImageSku" {
  type        = string
  default     = "9_7"
  description = "Azure Marketplace SKU for the Kafka VM image. RHEL 9_7 ships java-11-openjdk-devel (required by Solace connector 3.3.0). RHEL 10 drops OpenJDK 11, and 7-RAW-CI is deprecated/unavailable in some regions."
}

variable "vmImageVersion" {
  type        = string
  default     = "latest"
  description = "Azure Marketplace version for the Kafka VM image."
}

variable "javaPackage" {
  type        = string
  default     = "java-11-openjdk-devel"
  description = "Java package installed on the Kafka VM. Java 11 is required by the Solace PubSub+ Kafka source connector 3.3.0."
}

variable "kafkaVersion" {
  type        = string
  default     = "2.3.0"
  description = "Apache Kafka version installed on the VM by cloud-init."
}

variable "kafkaScalaVersion" {
  type        = string
  default     = "2.12"
  description = "Scala build of Apache Kafka to install (matches the kafka_<scala>-<kafka>.tgz artifact)."
}

## Databricks
variable "databricksNoPublicIP" {
  type        = bool
  default     = true
  description = "If true (default), the Databricks workspace uses Secure Cluster Connectivity and worker nodes have no public IPs. Set to false only if your scenario requires public worker IPs."
}
