resource "azurerm_public_ip" "kafkaPublicIP" {
  name                = "${var.suffix}-KafkaPublicIP"
  location            = azurerm_resource_group.genericRG.location
  resource_group_name = azurerm_resource_group.genericRG.name
  allocation_method   = "Static"

  tags = var.tags
}

resource "azurerm_network_interface" "kafkaNIC" {
  name                = "${var.suffix}-KafkaNIC"
  location            = azurerm_resource_group.genericRG.location
  resource_group_name = azurerm_resource_group.genericRG.name

  ip_configuration {
    name                          = "kafkaServer"
    subnet_id                     = azurerm_subnet.subnets["headnodes"].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.kafkaPublicIP.id
  }

  tags = var.tags
}

resource "azurerm_network_interface_security_group_association" "kafkaNICNSG" {
  network_interface_id      = azurerm_network_interface.kafkaNIC.id
  network_security_group_id = azurerm_network_security_group.genericNSG.id
}

resource "azurerm_linux_virtual_machine" "kafkaServer" {
  name                            = "${var.suffix}-KafkaServer"
  location                        = azurerm_resource_group.genericRG.location
  resource_group_name             = azurerm_resource_group.genericRG.name
  network_interface_ids           = [azurerm_network_interface.kafkaNIC.id]
  size                            = "Standard_DS3_v2"
  computer_name                   = "kafkaServer"
  admin_username                  = var.vmUserName
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.vmUserName
    public_key = file(pathexpand(var.sshKeyPath))
  }

  source_image_reference {
    publisher = var.vmImagePublisher
    offer     = var.vmImageOffer
    sku       = var.vmImageSku
    version   = var.vmImageVersion
  }

  os_disk {
    name                 = "${var.suffix}-kafkaServerosDisk1"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init/kafka-bootstrap.yaml.tftpl", {
    vm_user       = var.vmUserName
    java_package  = var.javaPackage
    kafka_version = var.kafkaVersion
    scala_version = var.kafkaScalaVersion
  }))

  tags = var.tags
}
