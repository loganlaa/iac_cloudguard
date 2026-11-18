# ==============================================================================
# Lab 5B: Create an AWS Cluster & Site-to-Site VPN (South Hub)
# ==============================================================================

# ------------------------------------------------------------------------------
# Task 5B-1: Create the Cluster VPC (10.50.0.0/16), Public (10.50.10.0/24)
# and Private (10.50.20.0/24) Subnets in Single Availability Zone
# ------------------------------------------------------------------------------
resource "aws_vpc" "cluster" {
  count                = var.deploy_cluster ? 1 : 0
  cidr_block           = var.cluster_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.cluster_name}-VPC"
  }
}

resource "aws_internet_gateway" "cluster" {
  count  = var.deploy_cluster ? 1 : 0
  vpc_id = aws_vpc.cluster[0].id

  tags = {
    Name = "${var.cluster_name}-IGW"
  }
}

resource "aws_subnet" "cluster_public" {
  count                   = var.deploy_cluster ? 1 : 0
  vpc_id                  = aws_vpc.cluster[0].id
  cidr_block              = var.cluster_public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.cluster_name}-Public-Subnet"
  }
}

resource "aws_subnet" "cluster_private" {
  count                   = var.deploy_cluster ? 1 : 0
  vpc_id                  = aws_vpc.cluster[0].id
  cidr_block              = var.cluster_private_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.cluster_name}-Private-Subnet"
  }
}

resource "aws_route_table" "cluster_public" {
  count  = var.deploy_cluster ? 1 : 0
  vpc_id = aws_vpc.cluster[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cluster[0].id
  }

  tags = {
    Name = "${var.cluster_name}-Public-RTB"
  }
}

resource "aws_route_table_association" "cluster_public" {
  count          = var.deploy_cluster ? 1 : 0
  subnet_id      = aws_subnet.cluster_public[0].id
  route_table_id = aws_route_table.cluster_public[0].id
}

resource "aws_route_table" "cluster_private" {
  count  = var.deploy_cluster ? 1 : 0
  vpc_id = aws_vpc.cluster[0].id

  tags = {
    Name = "${var.cluster_name}-Private-RTB"
  }
}

# ------------------------------------------------------------------------------
# Tasks 5B-4 & 5B-5: Optional Bootstrap Script for VTI & Static Route on Cluster
# ------------------------------------------------------------------------------
locals {
  # Inside a /30 tunnel CIDR (e.g. 169.254.191.236/30):
  # host 1 (.237) = AWS VGW side (remote)
  # host 2 (.238) = Check Point CGW side (local)
  vpn_tunnel1_aws_inside_ip  = cidrhost(var.vpn_tunnel1_inside_cidr, 1)
  vpn_tunnel1_chkp_inside_ip = cidrhost(var.vpn_tunnel1_inside_cidr, 2)

  cluster_vti_bootstrap_script = var.auto_configure_cluster_vti ? join("; ", [
    "clish -c 'add vpn tunnel 1 type numbered local ${local.vpn_tunnel1_chkp_inside_ip} remote ${local.vpn_tunnel1_aws_inside_ip} peer AWS_Tunnel1'",
    "clish -c 'set interface vpnt1 state on'",
    "clish -c 'set interface vpnt1 mtu 1399'",
    "clish -c 'set static-route ${var.spoke1_vpc_cidr} nexthop gateway logical vpnt1 priority 1 on'",
    "clish -c 'save config'"
  ]) : ""
}

# ------------------------------------------------------------------------------
# Task 5B-1: Deploy CloudGuard Single-AZ Cluster
# ------------------------------------------------------------------------------
module "cluster" {
  count   = var.deploy_cluster ? 1 : 0
  source  = "CheckPointSW/cloudguard-network-security/aws//modules/cluster"
  version = "1.2.1"

  vpc_id                                 = aws_vpc.cluster[0].id
  public_subnet_id                       = aws_subnet.cluster_public[0].id
  private_subnet_id                      = aws_subnet.cluster_private[0].id
  private_route_table                    = aws_route_table.cluster_private[0].id
  gateway_name                           = var.cluster_name
  gateway_instance_type                  = var.cluster_instance_type
  key_name                               = local.effective_key_name
  allocate_and_associate_eip             = true
  enable_instance_connect                = true
  gateway_version                        = var.chkp_version
  admin_shell                            = var.admin_shell
  gateway_SICKey                         = var.sic_key
  gateway_password_hash                  = var.admin_password_hash
  gateway_maintenance_mode_password_hash = ""
  memberAToken                           = ""
  memberBToken                           = ""
  gateway_bootstrap_script               = local.cluster_vti_bootstrap_script
}

# Look up the Cluster Member A external & internal ENIs to expose the exact
# Secondary Private IPs (VIPs for eth0 and eth1) required in Task 5B-2
data "aws_network_interface" "cluster_member_a_ext" {
  count = var.deploy_cluster ? 1 : 0
  filter {
    name   = "tag:Name"
    values = ["${var.cluster_name}-Member_A_ExternalInterface"]
  }
  filter {
    name   = "vpc-id"
    values = [aws_vpc.cluster[0].id]
  }
  depends_on = [module.cluster]
}

data "aws_network_interface" "cluster_member_a_int" {
  count = var.deploy_cluster ? 1 : 0
  filter {
    name   = "tag:Name"
    values = ["${var.cluster_name}-Member_A_InternalInterface"]
  }
  filter {
    name   = "vpc-id"
    values = [aws_vpc.cluster[0].id]
  }
  depends_on = [module.cluster]
}

# ------------------------------------------------------------------------------
# Task 5B-3: Create the AWS VPN (VGW, Customer Gateway, Site-to-Site VPN)
# ------------------------------------------------------------------------------
resource "aws_vpn_gateway" "spoke1" {
  count  = var.deploy_vpn && var.deploy_spokes && var.deploy_cluster ? 1 : 0
  vpc_id = aws_vpc.spoke1[0].id

  tags = {
    Name = "Spoke1-VPN"
  }
}

resource "aws_customer_gateway" "cluster" {
  count      = var.deploy_vpn && var.deploy_spokes && var.deploy_cluster ? 1 : 0
  bgp_asn    = 65000
  ip_address = module.cluster[0].cluster_public_ip[0]
  type       = "ipsec.1"

  tags = {
    Name = "Spoke-1-Customer-Gateway"
  }
}

resource "aws_vpn_connection" "spoke1" {
  count                    = var.deploy_vpn && var.deploy_spokes && var.deploy_cluster ? 1 : 0
  vpn_gateway_id           = aws_vpn_gateway.spoke1[0].id
  customer_gateway_id      = aws_customer_gateway.cluster[0].id
  type                     = "ipsec.1"
  static_routes_only       = true
  local_ipv4_network_cidr  = "0.0.0.0/0"
  remote_ipv4_network_cidr = "0.0.0.0/0"

  # Tunnel 1 parameters matching Task 5B-7 (IKEv1, AES-128, SHA-1, DH Group 2)
  tunnel1_inside_cidr                  = var.vpn_tunnel1_inside_cidr
  tunnel1_preshared_key                = var.vpn_tunnel1_psk
  tunnel1_ike_versions                 = ["ikev1"]
  tunnel1_phase1_encryption_algorithms = ["AES128"]
  tunnel1_phase1_integrity_algorithms  = ["SHA1"]
  tunnel1_phase1_dh_group_numbers      = [2]
  tunnel1_phase2_encryption_algorithms = ["AES128"]
  tunnel1_phase2_integrity_algorithms  = ["SHA1"]
  tunnel1_phase2_dh_group_numbers      = [2]

  tags = {
    Name = "Spoke-1 VPN Connection"
  }
}

resource "aws_vpn_connection_route" "spoke1_default" {
  count                  = var.deploy_vpn && var.deploy_spokes && var.deploy_cluster ? 1 : 0
  destination_cidr_block = "0.0.0.0/0"
  vpn_connection_id      = aws_vpn_connection.spoke1[0].id
}

# ------------------------------------------------------------------------------
# Task 5B-9: Configure the Spoke1 VPC Route (0.0.0.0/0 -> VGW)
# ------------------------------------------------------------------------------
resource "aws_route" "spoke1_default_to_vgw" {
  count                  = var.deploy_vpn && var.deploy_spokes && var.deploy_cluster ? 1 : 0
  route_table_id         = aws_route_table.spoke1[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_vpn_gateway.spoke1[0].id
}
