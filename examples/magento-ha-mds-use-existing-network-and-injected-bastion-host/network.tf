## Copyright (c) 2022, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

resource "oci_core_virtual_network" "magento_mds_vcn" {
  cidr_block     = var.vcn_cidr
  compartment_id = var.compartment_ocid
  display_name   = var.vcn
  dns_label      = "mamdsvcn"
}


resource "oci_core_internet_gateway" "internet_gateway" {
  compartment_id = var.compartment_ocid
  display_name   = "internet_gateway"
  vcn_id         = oci_core_virtual_network.magento_mds_vcn.id
}


resource "oci_core_nat_gateway" "nat_gateway" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.magento_mds_vcn.id
  display_name   = "nat_gateway"
}


resource "oci_core_route_table" "public_route_table" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.magento_mds_vcn.id
  display_name   = "RouteTableViaIGW"
  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.internet_gateway.id
  }
}

resource "oci_core_route_table" "private_route_table" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.magento_mds_vcn.id
  display_name   = "RouteTableViaNATGW"
  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.nat_gateway.id
  }
}

resource "oci_core_security_list" "public_security_list_ssh" {
  compartment_id = var.compartment_ocid
  display_name   = "Allow Public SSH Connections to WordPress"
  vcn_id         = oci_core_virtual_network.magento_mds_vcn.id
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "6"
  }
  ingress_security_rules {
    tcp_options {
      max = 22
      min = 22
    }
    protocol = "6"
    source   = "0.0.0.0/0"
  }
}

resource "oci_core_security_list" "public_security_list_http" {
  compartment_id = var.compartment_ocid
  display_name   = "Allow HTTP(S) to magento"
  vcn_id         = oci_core_virtual_network.magento_mds_vcn.id
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "6"
  }
  ingress_security_rules {
    tcp_options {
      max = 80
      min = 80
    }
    protocol = "6"
    source   = "0.0.0.0/0"
  }
  ingress_security_rules {
    tcp_options {
      max = 443
      min = 443
    }
    protocol = "6"
    source   = "0.0.0.0/0"
  }
}

resource "oci_core_security_list" "private_security_list" {
  compartment_id = var.compartment_ocid
  display_name   = "Private"
  vcn_id         = oci_core_virtual_network.magento_mds_vcn.id

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }
  ingress_security_rules {
    protocol = "1"
    source   = var.vcn_cidr
  }
  ingress_security_rules {
    tcp_options {
      max = 22
      min = 22
    }
    protocol = "6"
    source   = var.vcn_cidr
  }
  ingress_security_rules {
    tcp_options {
      max = 3306
      min = 3306
    }
    protocol = "6"
    source   = var.vcn_cidr
  }
  ingress_security_rules {
    tcp_options {
      max = 33061
      min = 33060
    }
    protocol = "6"
    source   = var.vcn_cidr
  }

  ingress_security_rules {
    protocol = "6"
    source   = var.vcn_cidr

    tcp_options {
      min = 2048
      max = 2050
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = var.vcn_cidr

    tcp_options {
      source_port_range {
        min = 2048
        max = 2050
      }
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = var.vcn_cidr

    tcp_options {
      min = 111
      max = 111
    }
  }
}

resource "oci_core_subnet" "magento_subnet" {
  cidr_block                 = cidrsubnet(var.vcn_cidr, 8, 2)
  display_name               = "magento_subnet"
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_virtual_network.magento_mds_vcn.id
  route_table_id             = oci_core_route_table.private_route_table.id 
  security_list_ids          = [oci_core_security_list.public_security_list_ssh.id, oci_core_security_list.public_security_list_http.id]
  dhcp_options_id            = oci_core_virtual_network.magento_mds_vcn.default_dhcp_options_id
  prohibit_public_ip_on_vnic = true 
  dns_label                  = "magsub"
}

resource "oci_core_subnet" "lb_subnet_public" {
  cidr_block        = cidrsubnet(var.vcn_cidr, 8, 0)
  display_name      = "lb_public_subnet"
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_virtual_network.magento_mds_vcn.id
  route_table_id    = oci_core_route_table.public_route_table.id
  security_list_ids = [oci_core_security_list.public_security_list_http.id]
  dhcp_options_id   = oci_core_virtual_network.magento_mds_vcn.default_dhcp_options_id
  dns_label         = "lbpub"
}

resource "oci_core_subnet" "bastion_subnet_public" {
  cidr_block        = cidrsubnet(var.vcn_cidr, 8, 1)
  display_name      = "bastion_public_subnet"
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_virtual_network.magento_mds_vcn.id
  route_table_id    = oci_core_route_table.public_route_table.id
  security_list_ids = [oci_core_security_list.public_security_list_ssh.id]
  dhcp_options_id   = oci_core_virtual_network.magento_mds_vcn.default_dhcp_options_id
  dns_label         = "bastionpub"
}

resource "oci_core_subnet" "fss_subnet_private" {
  cidr_block                 = cidrsubnet(var.vcn_cidr, 8, 4)
  display_name               = "fss_private_subnet"
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_virtual_network.magento_mds_vcn.id
  route_table_id             = oci_core_route_table.private_route_table.id
  dhcp_options_id            = oci_core_virtual_network.magento_mds_vcn.default_dhcp_options_id
  prohibit_public_ip_on_vnic = "true"
  dns_label                  = "fsspriv"
}

resource "oci_core_subnet" "mds_subnet_private" {
  cidr_block                 = cidrsubnet(var.vcn_cidr, 8, 3)
  display_name               = "mds_private_subnet"
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_virtual_network.magento_mds_vcn.id
  route_table_id             = oci_core_route_table.private_route_table.id
  security_list_ids          = [oci_core_security_list.private_security_list.id]
  dhcp_options_id            = oci_core_virtual_network.magento_mds_vcn.default_dhcp_options_id
  prohibit_public_ip_on_vnic = "true"
  dns_label                  = "mdspriv"
}

