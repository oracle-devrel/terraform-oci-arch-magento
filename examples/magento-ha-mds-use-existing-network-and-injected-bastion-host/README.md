## Create Magento multi-node + custom network & Bastion Host injected into module
This is an example of how to use the oci-arch-magento module to deploy Magento HA (multi-node) with MDS and network cloud infrastructure elements + Bastion Host injected into the module.
  
### Using this example
Update terraform.tfvars with the required information.

### Deploy the Magento
Initialize Terraform:
```
$ terraform init
```
View what Terraform plans do before actually doing it:
```
$ terraform plan
```
Use Terraform to Provision resources:
```
$ terraform apply
```
