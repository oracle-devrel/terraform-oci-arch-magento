## Copyright (c) 2022 Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

module "oci-arch-redis" {
  source                          = "github.com/oracle-devrel/terraform-oci-arch-redis"
  tenancy_ocid                    = var.tenancy_ocid
  user_ocid                       = "" 
  fingerprint                     = "" 
  private_key_path                = "" 
  region                          = var.region
  compartment_ocid                = var.compartment_ocid
  use_existing_vcn                = true
  vcn_id                          = oci_core_virtual_network.magento_mds_vcn.id
  use_private_subnet              = true 
  redis_subnet_id                 = oci_core_subnet.redis_subnet_private.id
  use_bastion_service             = true
  bastion_service_id              = oci_bastion_bastion.bastion_service_redis.id 
  numberOfMasterNodes             = 1
  numberOfReplicaNodes            = 0
  cluster_enabled                 = false
}
