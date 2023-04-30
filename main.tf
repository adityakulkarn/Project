terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "project-rg" {
  name     = "test-resources"
  location = "East US"
  tags = {
    "environment" = "online_test"
  }
}

resource "azurerm_virtual_network" "project-vnet" {
  name                = "test-network"
  resource_group_name = azurerm_resource_group.project-rg.name
  location            = azurerm_resource_group.project-rg.location
  address_space       = ["10.123.0.0/16"]

  tags = {
    "environment" = "online_test"
  }
}

resource "azurerm_subnet" "web-subnet" {
  name                 = "web-subnet"
  resource_group_name  = azurerm_resource_group.project-rg.name
  virtual_network_name = azurerm_virtual_network.project-vnet.name
  address_prefixes     = ["10.123.1.0/24"]
}

resource "azurerm_subnet" "app-subnet" {
  name                 = "app-subnet"
  resource_group_name  = azurerm_resource_group.project-rg.name
  virtual_network_name = azurerm_virtual_network.project-vnet.name
  address_prefixes     = ["10.123.2.0/24"]
}

resource "azurerm_subnet" "db-subnet" {
  name                 = "db-subnet"
  resource_group_name  = azurerm_resource_group.project-rg.name
  virtual_network_name = azurerm_virtual_network.project-vnet.name
  address_prefixes     = ["10.123.3.0/24"]
}

resource "azurerm_network_security_group" "web-sg" {
  name                = "web-sg"
  location            = azurerm_resource_group.project-rg.location
  resource_group_name = azurerm_resource_group.project-rg.name

  security_rule {
    name                       = "web-rule"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "80"
    destination_port_range     = "80"
    source_address_prefix      = "[0.0.0.0/0]"
    destination_address_prefix = "[0.0.0.0/0]"
  }

  tags = {
    environment = "online_test"
  }
}

resource "azurerm_network_security_group" "app-sg" {
  name                = "app-sg"
  location            = azurerm_resource_group.project-rg.location
  resource_group_name = azurerm_resource_group.project-rg.name

  security_rule {
    name                   = "app-rule"
    priority               = 100
    direction              = "Inbound"
    access                 = "Allow"
    protocol               = "Tcp"
    source_port_range      = "80"
    destination_port_range = "80"
  }

  tags = {
    environment = "online_test"
  }
}

resource "azurerm_network_security_group" "db-sg" {
  name                = "db-sg"
  location            = azurerm_resource_group.project-rg.location
  resource_group_name = azurerm_resource_group.project-rg.name

  security_rule {
    name                       = "db-rule"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "3306"
    destination_port_range     = "3306"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "online_test"
  }
}

resource "azurerm_subnet_network_security_group_association" "web-sga" {
  subnet_id                 = azurerm_subnet.web-subnet.id
  network_security_group_id = azurerm_network_security_group.web-sg.id
}

resource "azurerm_subnet_network_security_group_association" "app-sga" {
  subnet_id                 = azurerm_subnet.app-subnet.id
  network_security_group_id = azurerm_network_security_group.app-sg.id
}

resource "azurerm_subnet_network_security_group_association" "db-sga" {
  subnet_id                 = azurerm_subnet.db-subnet.id
  network_security_group_id = azurerm_network_security_group.db-sg.id
}

resource "azurerm_public_ip" "web-pip" {
  name                = "web-pip"
  resource_group_name = azurerm_resource_group.project-rg.name
  location            = azurerm_resource_group.project-rg.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "online_test"
  }
}

resource "azurerm_network_interface" "web-nic" {
  name                = "web-nic"
  location            = azurerm_resource_group.project-rg.location
  resource_group_name = azurerm_resource_group.project-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.web-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.web-pip.id
  }

  tags = {
    environment = "online_test"
  }
}

resource "azurerm_linux_virtual_machine" "web-server" {
  name                = "web-server"
  resource_group_name = azurerm_resource_group.project-rg.name
  location            = azurerm_resource_group.project-rg.location
  size                = "Standard_B1s"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.web-nic.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/webazurekey.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "22.04-LTS"
    version   = "latest"
  }

  tags = {
    environment = "online_test"
  }
}