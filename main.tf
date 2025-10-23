terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "tf_rg" {
  name     = "vnet-demo-rg"
  location = "Central India"
}

# Virtual Network
resource "azurerm_virtual_network" "tf_vnet" {
  name                = "demo-vnet"
  resource_group_name = azurerm_resource_group.tf_rg.name
  location            = azurerm_resource_group.tf_rg.location
  address_space       = ["15.0.0.0/16"]
}

# Web Subnet 1 and 2
resource "azurerm_subnet" "web_subnet1" {
  name                 = "web_subnet1"
  resource_group_name  = azurerm_resource_group.tf_rg.name
  virtual_network_name = azurerm_virtual_network.tf_vnet.name
  address_prefixes     = ["15.0.1.0/24"]
}

resource "azurerm_subnet" "web_subnet2" {
  name                 = "web_subnet2"
  resource_group_name  = azurerm_resource_group.tf_rg.name
  virtual_network_name = azurerm_virtual_network.tf_vnet.name
  address_prefixes     = ["15.0.2.0/24"]
}

# App Subnet 1 and 2
resource "azurerm_subnet" "app_subnet1" {
  name                 = "app_subnet1"
  resource_group_name  = azurerm_resource_group.tf_rg.name
  virtual_network_name = azurerm_virtual_network.tf_vnet.name
  address_prefixes     = ["15.0.5.0/24"]
}

resource "azurerm_subnet" "app_subnet2" {
  name                 = "app_subnet2"
  resource_group_name  = azurerm_resource_group.tf_rg.name
  virtual_network_name = azurerm_virtual_network.tf_vnet.name
  address_prefixes     = ["15.0.6.0/24"]
}

# DB Subnet 1 and 2
resource "azurerm_subnet" "db_subnet1" {
  name                 = "db_subnet1"
  resource_group_name  = azurerm_resource_group.tf_rg.name
  virtual_network_name = azurerm_virtual_network.tf_vnet.name
  address_prefixes     = ["15.0.7.0/24"]
}

resource "azurerm_subnet" "db_subnet2" {
  name                 = "db_subnet2"
  resource_group_name  = azurerm_resource_group.tf_rg.name
  virtual_network_name = azurerm_virtual_network.tf_vnet.name
  address_prefixes     = ["15.0.8.0/24"]
}

# Bastion Subnet 
resource "azurerm_subnet" "bastion_subnet" {
  name                 = "AzureBastionSubnet"  
  resource_group_name  = azurerm_resource_group.tf_rg.name
  virtual_network_name = azurerm_virtual_network.tf_vnet.name
  address_prefixes     = ["15.0.255.0/26"]    
}

# Public IP for Azure Bastion
resource "azurerm_public_ip" "bastion_pip" {
  name                = "bastion-public-ip"
  location            = azurerm_resource_group.tf_rg.location
  resource_group_name = azurerm_resource_group.tf_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Azure Bastion Host
resource "azurerm_bastion_host" "bastion" {
  name                = "eb-demo-bastion"
  location            = azurerm_resource_group.tf_rg.location
  resource_group_name = azurerm_resource_group.tf_rg.name
  sku                 = "Basic"  

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_pip.id
  }

  depends_on = [azurerm_subnet.bastion_subnet]
}

# Network Interface
resource "azurerm_network_interface" "tf_nic" {
  name                = "eb_demo_nic"
  location            = azurerm_resource_group.tf_rg.location
  resource_group_name = azurerm_resource_group.tf_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.web_subnet1.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "tf_vm" {
  name                = "web-nginx-vm"
  resource_group_name = azurerm_resource_group.tf_rg.name
  location            = azurerm_resource_group.tf_rg.location
  size                = "Standard_B1s"  
  admin_username      = "azureuser"

  network_interface_ids = [
    azurerm_network_interface.tf_nic.id
  ]

  admin_password = "P@ssword1234!"
  disable_password_authentication = false

  os_disk {
    name                 = "eb-demo-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  # custom_data = base64encode(file("${path.module}/setup.sh"))

    custom_data = base64encode(<<-EOT
      #!/bin/bash
      sudo apt update
      sudo apt install -y nginx
      sudo systemctl start nginx
      sudo systemctl enable nginx
      EOT
    )
}

# Public IP Address
resource "azurerm_public_ip" "tf_public_ip" {
  name                = "eb_demo_PublicIp"
  resource_group_name = azurerm_resource_group.tf_rg.name
  location            = azurerm_resource_group.tf_rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Public IP for NAT Gateway
resource "azurerm_public_ip" "nat_pip" {
  name                = "nat-gateway-pip"
  resource_group_name = azurerm_resource_group.tf_rg.name
  location            = azurerm_resource_group.tf_rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# NAT Gateway
resource "azurerm_nat_gateway" "web_nat_gw" {
  name                    = "web-nat-gateway"
  location                = azurerm_resource_group.tf_rg.location
  resource_group_name     = azurerm_resource_group.tf_rg.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
}

# Associate NAT Gateway with web subnet
resource "azurerm_subnet_nat_gateway_association" "web_nat_assoc" {
  subnet_id      = azurerm_subnet.web_subnet1.id
  nat_gateway_id = azurerm_nat_gateway.web_nat_gw.id
}

# Link NAT Gateway to Public IP
resource "azurerm_nat_gateway_public_ip_association" "nat_pip_assoc" {
  nat_gateway_id       = azurerm_nat_gateway.web_nat_gw.id
  public_ip_address_id = azurerm_public_ip.nat_pip.id
}

# Network Security Groups
resource "azurerm_network_security_group" "web_nsg" {
  name                = "web-nsg"
  location            = azurerm_resource_group.tf_rg.location
  resource_group_name = azurerm_resource_group.tf_rg.name

  # Azure Load Balancer security rule
  security_rule {
    name                       = "allow_azure_lb"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  # SSH from Bastion Host security rule
  security_rule {
    name                       = "allow_ssh_from_bastion"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = azurerm_subnet.bastion_subnet.address_prefixes[0]
    destination_address_prefix = "*"
  }

  # HTTP security rule
  security_rule {
    name                       = "allow_http"
    priority                   = 400
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  # Outbound Internet Access rule
  security_rule {
    name                       = "allow_outbound_internet"
    priority                   = 150
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }  

  tags = {
    environment = "Test"
  }
}

resource "azurerm_network_security_group" "app_nsg" {
  name                = "app-nsg"
  location            = azurerm_resource_group.tf_rg.location
  resource_group_name = azurerm_resource_group.tf_rg.name

  security_rule {
    name                       = "allow_app_from_web"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = azurerm_subnet.web_subnet1.address_prefixes[0]
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Test"
  }
}

resource "azurerm_network_security_group" "db_nsg" {
  name                = "db-nsg"
  location            = azurerm_resource_group.tf_rg.location
  resource_group_name = azurerm_resource_group.tf_rg.name

  security_rule {
    name                       = "allow_db_from_app"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = azurerm_subnet.app_subnet1.address_prefixes[0]
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Test"
  }
}

# NSG Association with Subnets
resource "azurerm_subnet_network_security_group_association" "web_nsg_assoc1" {
  subnet_id                 = azurerm_subnet.web_subnet1.id
  network_security_group_id = azurerm_network_security_group.web_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "web_nsg_assoc2" {
  subnet_id                 = azurerm_subnet.web_subnet2.id
  network_security_group_id = azurerm_network_security_group.web_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "app_nsg_assoc1" {
  subnet_id                 = azurerm_subnet.app_subnet1.id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "app_nsg_assoc2" {
  subnet_id                 = azurerm_subnet.app_subnet2.id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "db_nsg_assoc1" {
  subnet_id                 = azurerm_subnet.db_subnet1.id
  network_security_group_id = azurerm_network_security_group.db_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "db_nsg_assoc2" {
  subnet_id                 = azurerm_subnet.db_subnet2.id
  network_security_group_id = azurerm_network_security_group.db_nsg.id
}

# Load Balancer
resource "azurerm_lb" "web_public_lb" {
  name                = "web-public-elb"
  sku                  = "Standard"
  location            = azurerm_resource_group.tf_rg.location
  resource_group_name = azurerm_resource_group.tf_rg.name

  frontend_ip_configuration {
    name                 = "web-elb-ip"
    public_ip_address_id = azurerm_public_ip.tf_public_ip.id
  }
}

resource "azurerm_lb_backend_address_pool" "web_backend_pool_lb" {
  loadbalancer_id = azurerm_lb.web_public_lb.id
  name            = "web-backend-pool"
}

# Load Balancer Health Probe and Rule
resource "azurerm_lb_probe" "web_health_probe" {
  loadbalancer_id = azurerm_lb.web_public_lb.id
  name            = "web-health-probe"
  protocol        = "Tcp"
  port            = 80
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "web_http_rule" {
  loadbalancer_id            = azurerm_lb.web_public_lb.id
  name                       = "web-http-rule"
  protocol                   = "Tcp"
  frontend_port              = 80
  backend_port               = 80
  frontend_ip_configuration_name = azurerm_lb.web_public_lb.frontend_ip_configuration[0].name
  probe_id                   = azurerm_lb_probe.web_health_probe.id
  backend_address_pool_ids = [azurerm_lb_backend_address_pool.web_backend_pool_lb.id]
}

resource "azurerm_network_interface_backend_address_pool_association" "web_nic_lb_assoc" {
  network_interface_id    = azurerm_network_interface.tf_nic.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.web_backend_pool_lb.id
  
}

# Output the public IP address of the VM
output "public_ip_address" {
  value = azurerm_public_ip.tf_public_ip.ip_address
}
