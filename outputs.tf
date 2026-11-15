# ==============================================================================
# Outputs - Todos os IPs, DNS, Credenciais e Comandos para os Labs 3B, 4B, 5B, 6B, 8A
# ==============================================================================

output "ssh_private_key_file" {
  description = "Caminho local da chave privada SSH gerada (Task 3B-1)"
  value       = var.create_key_pair ? abspath(local_sensitive_file.private_key_pem[0].filename) : "Usando key pair existente: ${var.key_name}"
}

output "lab_credentials_info" {
  description = "Informações de acesso aos recursos Check Point"
  value = {
    username     = "admin"
    smartconsole = "Conectar ao IP público do CPMGMT com usuário 'admin' e a senha correspondente a var.admin_password_hash"
  }
}

# ------------------------------------------------------------------------------
# Lab 3B Outputs: Security Management Server & CME
# ------------------------------------------------------------------------------
output "lab3b_management" {
  description = "Informações do Lab 3B (Security Management Server & CME)"
  value = var.deploy_management ? {
    instance_id   = module.cpmgmt[0].management_instance_id
    name          = module.cpmgmt[0].management_instance_name
    public_ip     = module.cpmgmt[0].management_public_ip
    webui_url     = module.cpmgmt[0].management_url
    ssh_command   = "ssh -i ${var.key_name}.pem admin@${module.cpmgmt[0].management_public_ip}"
    cme_init_cmd  = "autoprov_cfg init AWS -mn \"${var.management_name}\" -tn \"${var.cme_configuration_template}\" -otp \"<SUA_SIC_KEY>\" -ver \"${local.chkp_version_short}\" -po \"${var.cme_policy_name}\" -cn \"${var.cme_controller_name}\" -r \"${data.aws_region.current.name}\" -iam"
    cme_Watch_log = "tail -f /var/log/CPcme/cme.log"
  } : null
}

# ------------------------------------------------------------------------------
# Lab 4B Outputs: Spokes, Web Servers, Auto Scale & Load Balancers
# ------------------------------------------------------------------------------
output "lab4b_spokes_and_autoscale" {
  description = "Informações do Lab 4B (Spokes, Web Servers, Auto Scale Group e Load Balancers)"
  value = {
    spoke1_vpc_id         = var.deploy_spokes ? aws_vpc.spoke1[0].id : null
    spoke1_web_private_ip = var.deploy_spokes ? aws_instance.spoke1_web[0].private_ip : null
    spoke2_vpc_id         = var.deploy_spokes ? aws_vpc.spoke2[0].id : null
    spoke2_web_private_ip = var.deploy_spokes ? aws_instance.spoke2_web[0].private_ip : null
    asg_vpc_id            = var.deploy_autoscale ? aws_vpc.asg[0].id : null
    asg_name              = var.deploy_autoscale ? module.autoscale[0].autoscale_autoscaling_group_name : null
    external_alb_dns_name = var.deploy_autoscale ? aws_lb.external[0].dns_name : null
    external_alb_test_url = var.deploy_autoscale ? "http://${aws_lb.external[0].dns_name}" : null
    internal_nlb_dns_name = var.deploy_autoscale && var.deploy_spokes ? aws_lb.internal[0].dns_name : null
    vpc_peering_id        = var.deploy_autoscale && var.deploy_spokes ? aws_vpc_peering_connection.gw_to_spoke1[0].id : null
  }
}

# ------------------------------------------------------------------------------
# Lab 5B Outputs: CloudGuard Cluster & Site-to-Site VPN
# ------------------------------------------------------------------------------
output "lab5b_cluster_and_vpn" {
  description = "Informações do Lab 5B (Cluster IPs/VIPs para SmartConsole e comandos VTI da VPN)"
  value = var.deploy_cluster ? {
    cluster_vpc_id             = aws_vpc.cluster[0].id
    cluster_public_vip         = try(module.cluster[0].cluster_public_ip[0], null)
    member_a_public_ip         = try(module.cluster[0].member_a_public_ip[0], null)
    member_b_public_ip         = try(module.cluster[0].member_b_public_ip[0], null)
    member_a_ssh               = try("ssh -i ${var.key_name}.pem admin@${module.cluster[0].member_a_public_ip[0]}", null)
    member_b_ssh               = try("ssh -i ${var.key_name}.pem admin@${module.cluster[0].member_b_public_ip[0]}", null)
    member_a_eth0_primary_ip   = data.aws_network_interface.cluster_member_a_ext[0].private_ip
    cluster_eth0_secondary_vip = try(element(tolist(setsubtract(tolist(data.aws_network_interface.cluster_member_a_ext[0].private_ips), [data.aws_network_interface.cluster_member_a_ext[0].private_ip])), 0), null)
    member_a_eth1_primary_ip   = data.aws_network_interface.cluster_member_a_int[0].private_ip
    cluster_eth1_secondary_vip = try(element(tolist(setsubtract(tolist(data.aws_network_interface.cluster_member_a_int[0].private_ips), [data.aws_network_interface.cluster_member_a_int[0].private_ip])), 0), null)
    vpn_connection_id          = var.deploy_vpn && var.deploy_spokes ? aws_vpn_connection.spoke1[0].id : null
    vpn_tunnel1_aws_public_ip  = var.deploy_vpn && var.deploy_spokes ? aws_vpn_connection.spoke1[0].tunnel1_address : null
    vpn_tunnel1_aws_inside_ip  = var.deploy_vpn && var.deploy_spokes ? aws_vpn_connection.spoke1[0].tunnel1_vgw_inside_address : null
    vpn_tunnel1_chkp_inside_ip = var.deploy_vpn && var.deploy_spokes ? aws_vpn_connection.spoke1[0].tunnel1_cgw_inside_address : null
    clish_vti_commands = var.deploy_vpn && var.deploy_spokes ? [
      "add vpn tunnel 1 type numbered local ${aws_vpn_connection.spoke1[0].tunnel1_cgw_inside_address} remote ${aws_vpn_connection.spoke1[0].tunnel1_vgw_inside_address} peer AWS_Tunnel1",
      "set interface vpnt1 state on",
      "set interface vpnt1 mtu 1399",
      "set static-route ${var.spoke1_vpc_cidr} nexthop gateway logical vpnt1 priority 1 on",
      "save config"
    ] : []
  } : null
}
