provider "azurerm" {
    features {}
}



# resource groups
resource "azurerm_resource_group" "eastus_hub" {
    name                          = "eastus_hub"
    location                      = "eastus"
}

resource "azurerm_resource_group" "eastus_spoke" {
    name                          = "eastus_spoke"
    location                      = "eastus"
}



# network security groups
resource "azurerm_network_security_group" "eastus_hub_egress" {
    name                          = "eastus_hub_egress"
    location                      = azurerm_resource_group.eastus_hub.location
    resource_group_name           = azurerm_resource_group.eastus_hub.name
}

resource "azurerm_network_security_group" "eastus_hub_ingress" {
    name                          = "eastus_hub_ingress"
    location                      = azurerm_resource_group.eastus_hub.location
    resource_group_name           = azurerm_resource_group.eastus_hub.name
}


resource "azurerm_network_security_group" "eastus_spoke_egress" {
    name                          = "eastus_spoke_egress"
    location                      = azurerm_resource_group.eastus_spoke.location
    resource_group_name           = azurerm_resource_group.eastus_spoke.name
}



# vnet hub
resource "azurerm_virtual_network" "eastus_hub" {
    name                          = "eastus_hub"
    location                      = azurerm_resource_group.eastus_hub.location
    resource_group_name           = azurerm_resource_group.eastus_hub.name
    address_space                 = ["10.0.0.0/23"]
}

resource "azurerm_subnet" "eastus_hub_subnetEgress" {
    name                          = "subnetEgress"
    resource_group_name           = azurerm_virtual_network.eastus_hub.resource_group_name
    virtual_network_name          = azurerm_virtual_network.eastus_hub.name
    address_prefixes              = ["10.0.0.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "eastus_hub_subnetEgress" {
    subnet_id                     = azurerm_subnet.eastus_hub_subnetEgress.id
    network_security_group_id     = azurerm_network_security_group.eastus_hub_egress.id
}

resource "azurerm_subnet" "eastus_hub_subnetHub" {
    name                          = "subnetHub"
    resource_group_name           = azurerm_virtual_network.eastus_hub.resource_group_name
    virtual_network_name          = azurerm_virtual_network.eastus_hub.name
    address_prefixes              = ["10.0.1.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "eastus_hub_subnetHub" {
    subnet_id                     = azurerm_subnet.eastus_hub_subnetHub.id
    network_security_group_id     = azurerm_network_security_group.eastus_hub_ingress.id
}



# vnet spoke
resource "azurerm_virtual_network" "eastus_spoke" {
    name                          = "eastus_spoke"
    location                      = azurerm_resource_group.eastus_spoke.location
    resource_group_name           = azurerm_resource_group.eastus_spoke.name
    address_space                 = ["10.0.2.0/23"]
}

resource "azurerm_subnet" "eastus_spoke_subnetEgress" {
    name                          = "subnetEgress"
    resource_group_name           = azurerm_virtual_network.eastus_spoke.resource_group_name
    virtual_network_name          = azurerm_virtual_network.eastus_spoke.name
    address_prefixes              = ["10.0.2.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "eastus_spoke_subnetEgress" {
    subnet_id                     = azurerm_subnet.eastus_spoke_subnetEgress.id
    network_security_group_id     = azurerm_network_security_group.eastus_spoke_egress.id
}



# route hub
resource "azurerm_route_table" "eastus_hub_ingress" {
    name                          = "eastus_hub_ingress"
    location                      = azurerm_resource_group.eastus_hub.location
    resource_group_name           = azurerm_resource_group.eastus_hub.name
    disable_bgp_route_propagation = false

    route {
        name                      = "Default"
        address_prefix            = "0.0.0.0/0"
        next_hop_type             = "VirtualAppliance"
        next_hop_in_ip_address    = module.ub_eastus_hub.lb_ip
    }
}

resource "azurerm_subnet_route_table_association" "eastus_hub_ingress" {
    subnet_id                     = azurerm_subnet.eastus_hub_subnetHub.id
    route_table_id                = azurerm_route_table.eastus_hub_ingress.id
}


# route spoke
resource "azurerm_route_table" "eastus_spoke_egress" {
    name                          = "eastus_spoke_egress"
    location                      = azurerm_resource_group.eastus_spoke.location
    resource_group_name           = azurerm_resource_group.eastus_spoke.name
    disable_bgp_route_propagation = false

    route {
        name                      = "Default"
        address_prefix            = "0.0.0.0/0"
        next_hop_type             = "VirtualAppliance"
        next_hop_in_ip_address    = module.ub_eastus_hub.lb_ip
    }
}

resource "azurerm_subnet_route_table_association" "eastus_spoke_egress" {
    subnet_id                     = azurerm_subnet.eastus_spoke_subnetEgress.id
    route_table_id                = azurerm_route_table.eastus_spoke_egress.id
}



# peering
resource "azurerm_virtual_network_peering" "eastus_hubSpoke" {
    name                          = "eastus_spoke"
    resource_group_name           = azurerm_virtual_network.eastus_hub.resource_group_name
    virtual_network_name          = azurerm_virtual_network.eastus_hub.name
    remote_virtual_network_id     = azurerm_virtual_network.eastus_spoke.id
    allow_forwarded_traffic       = true
    allow_gateway_transit         = true
    allow_virtual_network_access  = true
    use_remote_gateways           = false
}

resource "azurerm_virtual_network_peering" "eastus_spokeHub" {
    name                          = "eastus_hub"
    resource_group_name           = azurerm_virtual_network.eastus_spoke.resource_group_name
    virtual_network_name          = azurerm_virtual_network.eastus_spoke.name
    remote_virtual_network_id     = azurerm_virtual_network.eastus_hub.id
    allow_forwarded_traffic       = true
    allow_gateway_transit         = false
    allow_virtual_network_access  = true
    use_remote_gateways           = false
}



# ubuntu vms
module "ub_eastus_hub" {
    source                        = "./ubuntu_hub"
    env                           = "eastus_hub"
    nsg                           = azurerm_network_security_group.eastus_hub_ingress.id
    rg_location                   = azurerm_resource_group.eastus_hub.location
    rg_name                       = azurerm_resource_group.eastus_hub.name
    subnetIngressId               = azurerm_subnet.eastus_hub_subnetHub.id
    subnetIngressCidr             = azurerm_subnet.eastus_hub_subnetHub.address_prefixes[0]
    subnetEgressId                = azurerm_subnet.eastus_hub_subnetEgress.id
    subnetEgressCidr              = azurerm_subnet.eastus_hub_subnetEgress.address_prefixes[0]
}

module "ub_eastus_spoke" {
    source                        = "./ubuntu_spoke"
    env                           = "eastus_spoke"
    rg_location                   = azurerm_resource_group.eastus_spoke.location
    rg_name                       = azurerm_resource_group.eastus_spoke.name
    subnetEgressId                = azurerm_subnet.eastus_spoke_subnetEgress.id
    subnetEgressCidr              = azurerm_subnet.eastus_spoke_subnetEgress.address_prefixes[0]
}
