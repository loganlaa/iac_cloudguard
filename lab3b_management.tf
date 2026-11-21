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
  effective_management_version = coalesce(var.management_version, var.chkp_version)
  effective_gateway_version    = coalesce(var.gateway_version, var.chkp_version)
  chkp_version_short           = element(split("-", local.effective_gateway_version), 0)

  cluster_sic_bootstrap_script = var.deploy_cluster ? replace(<<-EOF
    # Wait until the cluster gateways finish their first boot before creating
    # the Management object and initializing SIC with the same member OTP.
    cluster_ready=0
    for i in $(seq 1 60); do
      if mgmt_cli -r true show simple-clusters --format json >/dev/null 2>&1; then
        cluster_ready=1
        break
      fi
      echo "Waiting for Management API before registering ClusterXL ($i/60)"
      sleep 15
    done
    if [ "$cluster_ready" -ne 1 ]; then
      echo "Management API did not become ready; cluster SIC registration skipped"
      exit 1
    fi

    cluster_name='${var.cluster_name}'
    if mgmt_cli -r true show simple-cluster name "$cluster_name" --format json >/dev/null 2>&1; then
      echo "Cluster object $cluster_name already exists; leaving it unchanged"
    else
      mgmt_cli -r true add simple-cluster \
        name "$cluster_name" \
        ipv4-address '${module.cluster[0].cluster_public_ip[0]}' \
        version '${local.chkp_version_short}' os-name Gaia \
        cluster-mode cluster-xl-ha firewall true vpn true \
        interfaces.1.name eth0 \
        interfaces.1.ip-address '${element(tolist(setsubtract(tolist(data.aws_network_interface.cluster_member_a_ext[0].private_ips), [data.aws_network_interface.cluster_member_a_ext[0].private_ip])), 0)}' \
        interfaces.1.ipv4-mask-length '${split("/", var.cluster_public_subnet_cidr)[1]}' \
        interfaces.1.interface-type cluster interfaces.1.topology EXTERNAL interfaces.1.anti-spoofing true \
        interfaces.2.name eth1 \
        interfaces.2.ip-address '${element(tolist(setsubtract(tolist(data.aws_network_interface.cluster_member_a_int[0].private_ips), [data.aws_network_interface.cluster_member_a_int[0].private_ip])), 0)}' \
        interfaces.2.ipv4-mask-length '${split("/", var.cluster_private_subnet_cidr)[1]}' \
        interfaces.2.interface-type cluster interfaces.2.topology INTERNAL interfaces.2.anti-spoofing true \
        members.1.name '${var.cluster_name}-Member-A' \
        members.1.ipv4-address '${module.cluster[0].member_a_public_ip[0]}' \
        members.1.one-time-password '${var.sic_key}' \
        members.1.interfaces.1.name eth0 \
        members.1.interfaces.1.ip-address '${data.aws_network_interface.cluster_member_a_ext[0].private_ip}' \
        members.1.interfaces.1.network-mask '${cidrnetmask(var.cluster_public_subnet_cidr)}' \
        members.1.interfaces.2.name eth1 \
        members.1.interfaces.2.ip-address '${data.aws_network_interface.cluster_member_a_int[0].private_ip}' \
        members.1.interfaces.2.network-mask '${cidrnetmask(var.cluster_private_subnet_cidr)}' \
        members.2.name '${var.cluster_name}-Member-B' \
        members.2.ipv4-address '${module.cluster[0].member_b_public_ip[0]}' \
        members.2.one-time-password '${var.sic_key}' \
        members.2.interfaces.1.name eth0 \
        members.2.interfaces.1.ip-address '${data.aws_network_interface.cluster_member_b_ext[0].private_ip}' \
        members.2.interfaces.1.network-mask '${cidrnetmask(var.cluster_public_subnet_cidr)}' \
        members.2.interfaces.2.name eth1 \
        members.2.interfaces.2.ip-address '${data.aws_network_interface.cluster_member_b_int[0].private_ip}' \
        members.2.interfaces.2.network-mask '${cidrnetmask(var.cluster_private_subnet_cidr)}' \
        --format json
      mgmt_cli -r true publish
    fi
  EOF
  , "\r\n", "\n") : ""

  mgmt_bootstrap_script = (var.auto_configure_cme_and_policy || var.deploy_cluster) ? replace(<<-EOF
    #!/bin/bash
    source /etc/profile.d/CP.sh
    exec >> /var/log/cccs_bootstrap.log 2>&1
    set -euo pipefail
    echo "[$(date)] Starting CCCS Lab 3B Automated Configuration (Policy & CME)..."

    # Aguardar a Management API ficar 100% pronta (ate 10 minutos)
    for i in $(seq 1 40); do
      if mgmt_cli -r true show packages --format json >/dev/null 2>&1; then
        echo "[$(date)] Management API ready (attempt $i)."
        break
      fi
      echo "[$(date)] Waiting for Management API ($i/40)..."
      sleep 15
    done
    if ! mgmt_cli -r true show packages --format json >/dev/null 2>&1; then
      echo "Management API did not become ready; aborting bootstrap"
      exit 1
    fi

    ${local.cluster_sic_bootstrap_script}

    # Criar politica AWS-Scale-Policy e liberar regra Cleanup (Accept + Log)
    ${var.auto_configure_cme_and_policy ? "mgmt_cli -r true add package name '${var.cme_policy_name}' access true threat-prevention false || true" : ""}
    ${var.auto_configure_cme_and_policy ? "mgmt_cli -r true set access-rule layer '${var.cme_policy_name} Network' rule-number 1 action 'Accept' track.type 'Log'" : ""}

    ${var.auto_configure_cme_and_policy ? "autoprov_cfg -f init AWS -mn '${var.management_name}' -tn '${var.cme_configuration_template}' -cn '${var.cme_controller_name}' -po '${var.cme_policy_name}' -otp '${var.sic_key}' -r '${data.aws_region.current.name}' -ver '${local.chkp_version_short}' -iam; service cme restart || true" : ""}
    echo "[$(date)] Finished CCCS Lab 3B Automated Configuration."
  EOF
  , "\r\n", "\n") : ""
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
  management_version                        = local.effective_management_version
  admin_shell                               = var.admin_shell
  management_password_hash                  = var.admin_password_hash
  management_maintenance_mode_password_hash = ""
  admin_cidr                                = var.admin_cidr
  gateway_management                        = "Over the internet"
  gateway_addresses                         = "0.0.0.0/0"
  management_bootstrap_script               = local.mgmt_bootstrap_script
  depends_on                                = [module.cluster]
}
