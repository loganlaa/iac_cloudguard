# ==============================================================================
# Module: Diagram as Code — Variables
# ==============================================================================

variable "output_dir" {
  description = "Diretório onde os arquivos de diagrama serão gerados"
  type        = string
  default     = "docs"
}

variable "render_png" {
  description = "Se true, executa o script Python (requer biblioteca 'diagrams' e Graphviz instalados) para gerar o PNG com ícones oficiais AWS"
  type        = bool
  default     = false
}

# ==============================================================================
# General & Feature Flags (espelham o código IaC raiz)
# ==============================================================================
variable "aws_region" {
  description = "Região AWS do laboratório"
  type        = string
}

variable "project_prefix" {
  description = "Prefixo identificador do projeto"
  type        = string
}

variable "deploy_management" {
  description = "Lab 3B habilitado"
  type        = bool
}

variable "deploy_spokes" {
  description = "Lab 4B (Spokes e Web Servers) habilitado"
  type        = bool
}

variable "deploy_autoscale" {
  description = "Lab 4B (Auto Scale, ALB, NLB, Peering) habilitado"
  type        = bool
}

variable "deploy_cluster" {
  description = "Lab 5B (Cluster HA) habilitado"
  type        = bool
}

variable "deploy_vpn" {
  description = "Lab 5B (Site-to-Site VPN) habilitado"
  type        = bool
}

variable "auto_configure_cme_and_policy" {
  description = "Bootstrap CME e política automática habilitados"
  type        = bool
  default     = true
}

variable "auto_configure_cluster_vti" {
  description = "Bootstrap VTI (vpnt1) no Cluster habilitado"
  type        = bool
  default     = false
}

# ==============================================================================
# Lab 3B — Management & CME
# ==============================================================================
variable "mgmt_vpc_cidr" {
  type = string
}

variable "mgmt_subnet_cidr" {
  type = string
}

variable "management_name" {
  type = string
}

variable "management_hostname" {
  type = string
}

variable "management_instance_type" {
  type = string
}

variable "cme_configuration_template" {
  type = string
}

variable "cme_controller_name" {
  type = string
}

variable "cme_policy_name" {
  type = string
}

# ==============================================================================
# Lab 4B — Spokes, Auto Scale & Load Balancers
# ==============================================================================
variable "spoke1_vpc_cidr" {
  type = string
}

variable "spoke2_vpc_cidr" {
  type = string
}

variable "webserver_instance_type" {
  type = string
}

variable "asg_vpc_cidr" {
  type = string
}

variable "asg_public_subnet_cidrs" {
  type = list(string)
}

variable "asg_private_subnet_cidrs" {
  type = list(string)
}

variable "asg_gateway_hostname" {
  type = string
}

variable "asg_gateway_instance_type" {
  type = string
}

variable "asg_min_size" {
  type = number
}

variable "asg_max_size" {
  type = number
}

# ==============================================================================
# Lab 5B — Cluster & Site-to-Site VPN
# ==============================================================================
variable "cluster_vpc_cidr" {
  type = string
}

variable "cluster_public_subnet_cidr" {
  type = string
}

variable "cluster_private_subnet_cidr" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_instance_type" {
  type = string
}

variable "vpn_tunnel1_inside_cidr" {
  type = string
}
