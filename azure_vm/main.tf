
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "public_vm_resource_group" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "vm_network" {
  name                = "vm-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.public_vm_resource_group.location
  resource_group_name = azurerm_resource_group.public_vm_resource_group.name
}

resource "azurerm_subnet" "vm_subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.public_vm_resource_group.name
  virtual_network_name = azurerm_virtual_network.vm_network.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "vm_public_ip" {
  name                = "vm-pip"
  resource_group_name = azurerm_resource_group.public_vm_resource_group.name
  location            = azurerm_resource_group.public_vm_resource_group.location
  allocation_method   = "Static"
  # sku                 = "Standard" ### This is for the nat gateway
}

resource "azurerm_network_interface" "public" {
  name                = "vm-public-nic"
  resource_group_name = azurerm_resource_group.public_vm_resource_group.name
  location            = azurerm_resource_group.public_vm_resource_group.location

  ip_configuration {
    name                          = "public"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_public_ip.id
  }
}

resource "azurerm_linux_virtual_machine" "public_vm" {
  name                = "ubuntu-machine"
  resource_group_name = azurerm_resource_group.public_vm_resource_group.name
  location            = azurerm_resource_group.public_vm_resource_group.location
  size                = "Standard_F2"
  admin_username      = var.usr_name
  user_data = base64encode(file("shell.sh"))
  network_interface_ids = [
    azurerm_network_interface.public.id
  ]

  admin_ssh_key {
    username   = var.usr_name
    public_key = file("./key.pub")
  }
  provisioner "file" {
    source      = "../docker-compose"
    destination = "/home/${self.admin_username}"
    connection {
      type        = "ssh"
      user        = var.usr_name
      private_key = file("./key")
      host        = self.public_ip_address
      timeout     = "2m"
    }
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version = "latest"
  }
}

### Deployment script
# https://learn.microsoft.com/en-us/azure/virtual-machines/extensions/custom-script-linux#extension-schema
resource "azurerm_virtual_machine_extension" "deployment_script" {
  name                 = "config_monitoring"
  virtual_machine_id   = azurerm_linux_virtual_machine.public_vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"
    timeouts {
      create = "5m"
    }
  settings = <<SETTINGS
 {
 "script": "${base64encode(templatefile ("../docker-compose/docker_compose_script.tftpl", {username = "${var.usr_name}",agent_token="${var.agent_token}" }))}"
 }
SETTINGS
}

### Security
resource "azurerm_network_security_group" "vm_sg_ssh" {
  name                = "vm-public-ssh-access"
  resource_group_name = azurerm_resource_group.public_vm_resource_group.name
  location            = azurerm_resource_group.public_vm_resource_group.location
}
resource "azurerm_network_interface_security_group_association" "public_ssh" {
  network_interface_id      = azurerm_network_interface.public.id
  network_security_group_id = azurerm_network_security_group.vm_sg_ssh.id
}
### Notes
/*
https://learn.microsoft.com/en-us/azure/virtual-network/network-security-groups-overview
 Network security groups are processed after Azure translates a public IP address to a 
private IP address for inbound traffic, and before Azure translates a private IP address to a 
public IP address for outbound traffic
*/
resource "azurerm_network_security_rule" "vm-public-ssh-access" {
  name                        = "ssh"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = 22
  source_address_prefix       = var.address_prefix
  destination_address_prefix = azurerm_network_interface.public.private_ip_address
  resource_group_name         = azurerm_resource_group.public_vm_resource_group.name
  network_security_group_name = azurerm_network_security_group.vm_sg_ssh.name
}

resource "azurerm_network_security_rule" "prometheus" {
  name                        = "prometheus"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = 9090
  source_address_prefix       = var.address_prefix
  # source_address_prefix       = "*"
  destination_address_prefix = azurerm_network_interface.public.private_ip_address
  resource_group_name         = azurerm_resource_group.public_vm_resource_group.name
  network_security_group_name = azurerm_network_security_group.vm_sg_ssh.name
}

resource "azurerm_network_security_rule" "grafana" {
  name                        = "grafana"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = 3000
  source_address_prefix       = var.address_prefix
  # source_address_prefix       = "*"
  destination_address_prefix = azurerm_network_interface.public.private_ip_address
  resource_group_name         = azurerm_resource_group.public_vm_resource_group.name
  network_security_group_name = azurerm_network_security_group.vm_sg_ssh.name
}
