# ==============================================================================
# Module: Diagram as Code — Main
# ==============================================================================
locals {
  template_vars = {
    output_dir                    = var.output_dir
    aws_region                    = var.aws_region
    project_prefix                = var.project_prefix
    deploy_management             = var.deploy_management
    deploy_spokes                 = var.deploy_spokes
    deploy_autoscale              = var.deploy_autoscale
    deploy_cluster                = var.deploy_cluster
    deploy_vpn                    = var.deploy_vpn
    auto_configure_cme_and_policy = var.auto_configure_cme_and_policy
    auto_configure_cluster_vti    = var.auto_configure_cluster_vti
    mgmt_vpc_cidr                 = var.mgmt_vpc_cidr
    mgmt_subnet_cidr              = var.mgmt_subnet_cidr
    management_name               = var.management_name
    management_hostname           = var.management_hostname
    management_instance_type      = var.management_instance_type
    cme_configuration_template    = var.cme_configuration_template
    cme_controller_name           = var.cme_controller_name
    cme_policy_name               = var.cme_policy_name
    spoke1_vpc_cidr               = var.spoke1_vpc_cidr
    spoke2_vpc_cidr               = var.spoke2_vpc_cidr
    webserver_instance_type       = var.webserver_instance_type
    asg_vpc_cidr                  = var.asg_vpc_cidr
    asg_public_subnet_cidrs       = var.asg_public_subnet_cidrs
    asg_private_subnet_cidrs      = var.asg_private_subnet_cidrs
    asg_gateway_hostname          = var.asg_gateway_hostname
    asg_gateway_instance_type     = var.asg_gateway_instance_type
    asg_min_size                  = var.asg_min_size
    asg_max_size                  = var.asg_max_size
    cluster_vpc_cidr              = var.cluster_vpc_cidr
    cluster_public_subnet_cidr    = var.cluster_public_subnet_cidr
    cluster_private_subnet_cidr   = var.cluster_private_subnet_cidr
    cluster_name                  = var.cluster_name
    cluster_instance_type         = var.cluster_instance_type
    vpn_tunnel1_inside_cidr       = var.vpn_tunnel1_inside_cidr
  }

  mermaid_rendered = templatefile("${path.module}/templates/topology.mmd.tftpl", local.template_vars)

  markdown_rendered = templatefile("${path.module}/templates/topology.md.tftpl", merge(local.template_vars, {
    mermaid_content = local.mermaid_rendered
  }))

  python_diagrams_rendered = templatefile("${path.module}/templates/aws_diagrams.py.tftpl", local.template_vars)
}

resource "local_file" "topology_mermaid" {
  content  = local.mermaid_rendered
  filename = "${var.output_dir}/topology.mmd"
}

resource "local_file" "topology_markdown" {
  content  = local.markdown_rendered
  filename = "${var.output_dir}/topology.md"
}

resource "local_file" "topology_python_diagrams" {
  content         = local.python_diagrams_rendered
  filename        = "${var.output_dir}/topology_aws_icons.py"
  file_permission = "0755"
}

resource "null_resource" "render_aws_icons_png" {
  count = var.render_png ? 1 : 0

  triggers = {
    script_sha256 = sha256(local.python_diagrams_rendered)
  }

  provisioner "local-exec" {
    command = "python3 ${local_file.topology_python_diagrams.filename}"
  }

  depends_on = [local_file.topology_python_diagrams]
}
