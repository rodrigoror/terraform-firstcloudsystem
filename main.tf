provider "azurerm" {
  features {}
  #subscription
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}

# Criar um grupo de recursos
resource "azurerm_resource_group" "rg" {
  name     = "MyResourceGroup"
  location = "East US"
}

# Criar uma Virtual Network (VNet)
resource "azurerm_virtual_network" "vnet" {
  name                = "MyVNet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Criar uma sub-rede pública
resource "azurerm_subnet" "public_subnet" {
  name                 = "PublicSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Criar uma sub-rede privada
resource "azurerm_subnet" "private_subnet" {
  name                 = "PrivateSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Criar um IP público para a instância do NestJS
resource "azurerm_public_ip" "nestjs_ip" {
  name                = "NestJSAppIP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Criar um Network Security Group (NSG) para a sub-rede pública
resource "azurerm_network_security_group" "nsg" {
  name                = "MyNSG"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "HTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "SSH"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Criar uma interface de rede para a instância do NestJS
resource "azurerm_network_interface" "nestjs_nic" {
  name                = "NestJSNIC"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.nestjs_ip.id
  }
}

# Criar uma VM para o NestJS
resource "azurerm_linux_virtual_machine" "nestjs_vm" {
  name                = "NestJSApp"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = "azureuser"
  network_interface_ids = [
    azurerm_network_interface.nestjs_nic.id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

# Criar um MySQL Flexible Server na sub-rede privada
resource "azurerm_mysql_flexible_server" "mysql_flexible" {
  name                   = "mysql-flexible-server"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location
  administrator_login    = "mysqladmin"
  administrator_password = var.mysql_admin_password 
  sku_name               = "B_Standard_B1s"
  version                = "5.7"

  storage {
    size_gb = 20
  }

  delegated_subnet_id = azurerm_subnet.private_subnet.id
  private_dns_zone_id = azurerm_private_dns_zone.mysql_dns.id

  depends_on = [azurerm_private_dns_zone_virtual_network_link.mysql_dns_link]
}

# Criar uma zona DNS privada para o MySQL Flexible Server
resource "azurerm_private_dns_zone" "mysql_dns" {
  name                = "mysql.private.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

# Vincular a zona DNS privada à VNet
resource "azurerm_private_dns_zone_virtual_network_link" "mysql_dns_link" {
  name                  = "mysql-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.mysql_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# Output do IP público do NestJS
output "nestjs_public_ip" {
  value = azurerm_public_ip.nestjs_ip.ip_address
}