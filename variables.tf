# ==============================================================================
# General & AWS Region Settings
# ==============================================================================
variable "aws_region" {
  description = "Região AWS para deploy do laboratório (recomendado pelo material: us-east-1, us-east-2 ou us-west-2)"
  type        = string
  default     = "us-east-1"
}

variable "project_prefix" {
  description = "Prefixo identificador do laboratório"
  type        = string
  default     = "CCCS-Lab"
}

# ==============================================================================
# Feature Flags (Modular Lab Deployment)
# ==============================================================================
variable "deploy_management" {
  description = "Lab 3B: Implantar o Check Point Security Management Server (CPMGMT) e sua VPC"
  type        = bool
  default     = true
}

variable "deploy_spokes" {
  description = "Lab 4B (Tasks 4B-1 & 4B-2): Implantar Spoke1 VPC, Spoke2 VPC e os Web Servers"
  type        = bool
  default     = true
}

variable "deploy_autoscale" {
  description = "Lab 4B (Tasks 4B-3 a 4B-7): Implantar VPC Auto Scale, CloudGuard ASG, ALB Externo, NLB Interno e VPC Peerings"
  type        = bool
  default     = true
}

variable "deploy_cluster" {
  description = "Lab 5B (Task 5B-1): Implantar a VPC do Cluster e o CloudGuard High Availability Cluster (Single-AZ)"
  type        = bool
  default     = true
}

variable "deploy_vpn" {
  description = "Lab 5B (Tasks 5B-3 & 5B-9): Implantar VGW, Customer Gateway, Site-to-Site VPN e rota default no Spoke1"
  type        = bool
  default     = true
}

variable "auto_configure_cme_and_policy" {
  description = "Executar automaticamente via bootstrap no Management Server a criação da política AWS-Scale-Policy e do CME (autoprov_cfg) do Lab 3B"
  type        = bool
  default     = true
}

variable "auto_configure_cluster_vti" {
  description = "Configurar automaticamente via bootstrap nos membros do Cluster a interface VTI (vpnt1) e rota estática para o Spoke1 (Tasks 5B-4 & 5B-5)"
  type        = bool
  default     = false
}

# ==============================================================================
# SSH Key Pair Settings (Task 3B-1)
# ==============================================================================
variable "create_key_pair" {
  description = "Criar automaticamente um par de chaves SSH na AWS e salvar o arquivo .pem localmente"
  type        = bool
  default     = true
}

variable "key_name" {
  description = "Nome do Key Pair na AWS (no material: AWS-Lab-Key)"
  type        = string
  default     = "AWS-Lab-Key"
}

# ==============================================================================
# Check Point Common Credentials & Version Settings
# ==============================================================================
variable "chkp_version" {
  description = "Versão e licença do Check Point CloudGuard (ex: R81.20-BYOL ou R81.20-PAYG)"
  type        = string
  default     = "R81.20-BYOL"
}

variable "admin_shell" {
  description = "Shell padrão do usuário admin (/bin/bash conforme os laboratórios)"
  type        = string
  default     = "/bin/bash"
}

variable "admin_password_hash" {
  description = "Hash MD5/SHA512 da senha admin e maintenance mode (gere com: openssl passwd -1 'SuaSenha'). Ex. do lab para 'Checkpoint123': $1$e1ea8700$LlfzK3ZxnGYdSAvgECsPy0"
  type        = string
  sensitive   = true
}

variable "sic_key" {
  description = "Chave SIC (One-time password, mín. 8 caracteres alfanuméricos) usada entre Management, CME, Auto Scale e Cluster"
  type        = string
  sensitive   = true
}

variable "admin_cidr" {
  description = "CIDR permitido para acesso administrativo (SSH/HTTPS/SmartConsole) ao Management Server (ex: SEU_IP_PUBLICO/32)"
  type        = string
  default     = "0.0.0.0/0"
}

# ==============================================================================
# Lab 3B: Security Management Server & CME Settings
# ==============================================================================
variable "mgmt_vpc_cidr" {
  description = "CIDR da VPC do Management Server (CPMGMT-VPC)"
  type        = string
  default     = "10.1.0.0/16"
}

variable "mgmt_subnet_cidr" {
  description = "CIDR da subnet pública do Management Server"
  type        = string
  default     = "10.1.0.0/24"
}

variable "management_name" {
  description = "Nome do Security Management Server (usado na tag x-chkp-management e CME -mn)"
  type        = string
  default     = "CPMGMT"
}

variable "management_instance_type" {
  description = "Instance type do Security Management Server (padrão do lab: m5.xlarge)"
  type        = string
  default     = "m5.xlarge"
}

variable "cme_configuration_template" {
  description = "Nome do Configuration Template no CME (-tn e tag x-chkp-template)"
  type        = string
  default     = "AWS-Scale-Lab-Template"
}

variable "cme_controller_name" {
  description = "Nome do Controller AWS no CME (-cn)"
  type        = string
  default     = "AWS-Scale-Lab-Controller"
}

variable "cme_policy_name" {
  description = "Nome do pacote de política de segurança para o Auto Scale (-po)"
  type        = string
  default     = "AWS-Scale-Policy"
}

# ==============================================================================
# Lab 4B: Spoke VPCs & Web Servers Settings
# ==============================================================================
variable "spoke1_vpc_cidr" {
  description = "CIDR da VPC Spoke1 (Task 4B-1)"
  type        = string
  default     = "10.10.0.0/24"
}

variable "spoke2_vpc_cidr" {
  description = "CIDR da VPC Spoke2 (Task 4B-1)"
  type        = string
  default     = "10.20.0.0/24"
}

variable "webserver_instance_type" {
  description = "Instance type dos Web Servers nos Spokes (Task 4B-2: t3.micro)"
  type        = string
  default     = "t3.micro"
}

# ==============================================================================
# Lab 4B: Auto Scale Group & Load Balancers Settings
# ==============================================================================
variable "asg_vpc_cidr" {
  description = "CIDR da VPC de Auto Scaling (AWS-AS-VPC - Task 4B-3)"
  type        = string
  default     = "10.100.0.0/16"
}

variable "asg_public_subnet_cidrs" {
  description = "CIDRs das 2 subnets públicas da VPC de Auto Scaling"
  type        = list(string)
  default     = ["10.100.0.0/24", "10.100.1.0/24"]
}

variable "asg_private_subnet_cidrs" {
  description = "CIDRs das 2 subnets privadas da VPC de Auto Scaling"
  type        = list(string)
  default     = ["10.100.2.0/24", "10.100.3.0/24"]
}

variable "asg_gateway_instance_type" {
  description = "Instance type dos Gateways do Auto Scaling Group (Task 4B-4: c5.large)"
  type        = string
  default     = "c5.large"
}

variable "asg_min_size" {
  description = "Quantidade mínima de Gateways no Auto Scaling Group"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Quantidade máxima de Gateways no Auto Scaling Group"
  type        = number
  default     = 4
}

# ==============================================================================
# Lab 5B: CloudGuard Cluster & Site-to-Site VPN Settings
# ==============================================================================
variable "cluster_vpc_cidr" {
  description = "CIDR da VPC do Cluster (South Hub - Task 5B-1)"
  type        = string
  default     = "10.50.0.0/16"
}

variable "cluster_public_subnet_cidr" {
  description = "CIDR da subnet pública (Frontend) do Cluster"
  type        = string
  default     = "10.50.10.0/24"
}

variable "cluster_private_subnet_cidr" {
  description = "CIDR da subnet privada (Backend/Sync) do Cluster"
  type        = string
  default     = "10.50.20.0/24"
}

variable "cluster_name" {
  description = "Nome do Cluster CloudGuard"
  type        = string
  default     = "AWS-Cluster"
}

variable "cluster_instance_type" {
  description = "Instance type dos membros do Cluster (Task 5B-1: c5.large)"
  type        = string
  default     = "c5.large"
}

variable "vpn_tunnel1_inside_cidr" {
  description = "CIDR interno (/30 dentro de 169.254.0.0/16) para o Túnel 1 da VPN Site-to-Site (Task 5B-3 & 5B-4)"
  type        = string
  default     = "169.254.191.236/30"
}

variable "vpn_tunnel1_psk" {
  description = "Pre-Shared Key (PSK) do Túnel 1 da VPN Site-to-Site (mínimo 8 caracteres)"
  type        = string
  sensitive   = true
}
