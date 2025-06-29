locals {
  common_tags = {
	project = var.project
	env = var.env
	Terraform = "true"
  }
  az_names = slice(data.aws_availability_zones.available.names, 0, 2)
}