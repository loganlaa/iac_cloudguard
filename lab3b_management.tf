# ==============================================================================
# Lab 3B: Deploy a Security Management Server (AWS)
# ==============================================================================

# ------------------------------------------------------------------------------
# Task 3B-1: Create the CPMGMT VPC, Subnet, IGW & Route Table
# ------------------------------------------------------------------------------
resource "aws_vpc" "cpmgmt" {
  count                = var.deploy_management ? 1 : 0
  cidr_block           = var.mgmt_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "CPMGMT-vpc"
  }
}

resource "aws_internet_gateway" "cpmgmt" {
  count  = var.deploy_management ? 1 : 0
  vpc_id = aws_vpc.cpmgmt[0].id

  tags = {
    Name = "CPMGMT-igw"
  }
}

resource "aws_subnet" "cpmgmt_public" {
  count                   = var.deploy_management ? 1 : 0
  vpc_id                  = aws_vpc.cpmgmt[0].id
  cidr_block              = var.mgmt_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "CPMGMT-subnet-public1-${data.aws_availability_zones.available.names[0]}"
  }
}

resource "aws_route_table" "cpmgmt_public" {
  count  = var.deploy_management ? 1 : 0
  vpc_id = aws_vpc.cpmgmt[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cpmgmt[0].id
  }

  tags = {
    Name = "CPMGMT-rtb-public"
  }
}

resource "aws_route_table_association" "cpmgmt_public" {
  count          = var.deploy_management ? 1 : 0
  subnet_id      = aws_subnet.cpmgmt_public[0].id
  route_table_id = aws_route_table.cpmgmt_public[0].id
}

# ------------------------------------------------------------------------------
# Tasks 3B-4 & 3B-5: Optional Bootstrap Script for CME & Access Policy
# ------------------------------------------------------------------------------
locals {
  chkp_version_short = element(split("-", var.chkp_version), 0)

  mgmt_bootstrap_script = var.auto_configure_cme_and_policy ? join("; ", [
    "echo 'Starting CCCS Lab 3B Automated Configuration (Policy & CME)...'",
    "mgmt_cli -r true add package name '${var.cme_policy_name}' access true threat-prevention false",
    "mgmt_cli -r true set access-rule layer '${var.cme_policy_name} Network' rule-number 1 action 'Accept' track.type 'Log'",
    "autoprov_cfg -f init AWS -mn '${var.management_name}' -tn '${var.cme_configuration_template}' -cn '${var.cme_controller_name}' -po '${var.cme_policy_name}' -otp '${var.sic_key}' -r '${data.aws_region.current.name}' -ver '${local.chkp_version_short}' -iam",
    "echo 'Finished CCCS Lab 3B Automated Configuration.'"
  ]) : ""
}

# ------------------------------------------------------------------------------
# Task 3B-1 & 3B-3: CloudGuard Security Management Server + CME IAM Role
# ------------------------------------------------------------------------------
module "cpmgmt" {
  count   = var.deploy_management ? 1 : 0
  source  = "CheckPointSW/cloudguard-network-security/aws//modules/management"
  version = "1.2.1"

  vpc_id                                    = aws_vpc.cpmgmt[0].id
  subnet_id                                 = aws_subnet.cpmgmt_public[0].id
  management_name                           = var.management_name
  management_hostname                       = var.management_hostname
  management_instance_type                  = var.management_instance_type
  key_name                                  = local.effective_key_name
  allocate_and_associate_eip                = true
  enable_instance_connect                   = true
  iam_permissions                           = "Create with read-write permissions"
  management_version                        = var.chkp_version
  admin_shell                               = var.admin_shell
  management_password_hash                  = var.admin_password_hash
  management_maintenance_mode_password_hash = ""
  admin_cidr                                = var.admin_cidr
  gateway_management                        = "Over the internet"
  gateway_addresses                         = "0.0.0.0/0"
  management_bootstrap_script               = local.mgmt_bootstrap_script
}
