# ==============================================================================
# Lab 4B: Deploy AWS EC2 Auto Scaling (Spokes, Web Servers, ASG, ALB/NLB, Peering)
# ==============================================================================

# ------------------------------------------------------------------------------
# Task 4B-1: Create the AWS Spoke VPCs (Spoke1 & Spoke2)
# ------------------------------------------------------------------------------
resource "aws_vpc" "spoke1" {
  count                = var.deploy_spokes ? 1 : 0
  cidr_block           = var.spoke1_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "Spoke1"
  }
}

resource "aws_subnet" "spoke1" {
  count                   = var.deploy_spokes ? 1 : 0
  vpc_id                  = aws_vpc.spoke1[0].id
  cidr_block              = var.spoke1_vpc_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name = "Spoke1-subnet"
  }
}

resource "aws_route_table" "spoke1" {
  count  = var.deploy_spokes ? 1 : 0
  vpc_id = aws_vpc.spoke1[0].id

  tags = {
    Name = "Spoke1-rtb"
  }
}

resource "aws_route_table_association" "spoke1" {
  count          = var.deploy_spokes ? 1 : 0
  subnet_id      = aws_subnet.spoke1[0].id
  route_table_id = aws_route_table.spoke1[0].id
}

resource "aws_vpc" "spoke2" {
  count                = var.deploy_spokes ? 1 : 0
  cidr_block           = var.spoke2_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "Spoke2"
  }
}

resource "aws_subnet" "spoke2" {
  count                   = var.deploy_spokes ? 1 : 0
  vpc_id                  = aws_vpc.spoke2[0].id
  cidr_block              = var.spoke2_vpc_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name = "Spoke2-subnet"
  }
}

resource "aws_route_table" "spoke2" {
  count  = var.deploy_spokes ? 1 : 0
  vpc_id = aws_vpc.spoke2[0].id

  tags = {
    Name = "Spoke2-rtb"
  }
}

resource "aws_route_table_association" "spoke2" {
  count          = var.deploy_spokes ? 1 : 0
  subnet_id      = aws_subnet.spoke2[0].id
  route_table_id = aws_route_table.spoke2[0].id
}

# ------------------------------------------------------------------------------
# Task 4B-2: Deploy the Web Servers into the Spoke VPCs
# ------------------------------------------------------------------------------
# Uses Amazon Linux 2023 with pre-baked Apache web page matching the Bitnami
# LAMP test page so it works 100% offline in isolated Spoke subnets (no NAT/IGW)
# and requires no Marketplace subscription.
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  webserver_userdata = <<-EOF
    #!/bin/bash
    dnf install -y httpd
    cat << 'HTML' > /var/www/html/index.html
    <!DOCTYPE html>
    <html>
    <head><title>CCCS CloudGuard Lab Web Server</title></head>
    <body style="font-family: Arial, sans-serif; margin: 40px;">
      <h1>Congratulations!</h1>
      <p>You are now running the CCCS Lab Web Server (LAMP simulation) on <b>$(hostname -f)</b>.</p>
      <p>Private IP: <b>$(hostname -I)</b></p>
    </body>
    </html>
    HTML
    systemctl enable --now httpd
    # Create 'bitnami' alias user with ec2-user SSH authorized_keys for Task 5B-9 compatibility
    useradd -m -s /bin/bash bitnami || true
    echo "bitnami ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/bitnami
    mkdir -p /home/bitnami/.ssh
    cp /home/ec2-user/.ssh/authorized_keys /home/bitnami/.ssh/authorized_keys || true
    chown -R bitnami:bitnami /home/bitnami/.ssh
    chmod 700 /home/bitnami/.ssh
    chmod 600 /home/bitnami/.ssh/authorized_keys || true
  EOF
}

# Security Group "Open" in Spoke1 (Task 4B-5 steps 4B-5.40 to 4B-5.44)
resource "aws_security_group" "spoke1_open" {
  count       = var.deploy_spokes ? 1 : 0
  name        = "Open"
  description = "Open"
  vpc_id      = aws_vpc.spoke1[0].id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Open"
  }
}

resource "aws_security_group" "spoke2_open" {
  count       = var.deploy_spokes ? 1 : 0
  name        = "Open"
  description = "Open"
  vpc_id      = aws_vpc.spoke2[0].id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Open"
  }
}

resource "aws_instance" "spoke1_web" {
  count                       = var.deploy_spokes ? 1 : 0
  ami                         = nonsensitive(data.aws_ssm_parameter.al2023_ami.value)
  instance_type               = var.webserver_instance_type
  subnet_id                   = aws_subnet.spoke1[0].id
  vpc_security_group_ids      = [aws_security_group.spoke1_open[0].id]
  key_name                    = local.effective_key_name
  associate_public_ip_address = false
  user_data                   = local.webserver_userdata

  tags = {
    Name = "Spoke1-Web-Server"
  }
}

resource "aws_instance" "spoke2_web" {
  count                       = var.deploy_spokes ? 1 : 0
  ami                         = nonsensitive(data.aws_ssm_parameter.al2023_ami.value)
  instance_type               = var.webserver_instance_type
  subnet_id                   = aws_subnet.spoke2[0].id
  vpc_security_group_ids      = [aws_security_group.spoke2_open[0].id]
  key_name                    = local.effective_key_name
  associate_public_ip_address = false
  user_data                   = local.webserver_userdata

  tags = {
    Name = "Spoke2-Web-Server"
  }
}

# ------------------------------------------------------------------------------
# Task 4B-3: Create the VPC for the Auto Scale Deployment (AWS-AS-VPC)
# ------------------------------------------------------------------------------
resource "aws_vpc" "asg" {
  count                = var.deploy_autoscale ? 1 : 0
  cidr_block           = var.asg_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "AWS-AS-VPC-vpc"
  }
}

resource "aws_internet_gateway" "asg" {
  count  = var.deploy_autoscale ? 1 : 0
  vpc_id = aws_vpc.asg[0].id

  tags = {
    Name = "AWS-AS-VPC-igw"
  }
}

resource "aws_subnet" "asg_public" {
  count                   = var.deploy_autoscale ? 2 : 0
  vpc_id                  = aws_vpc.asg[0].id
  cidr_block              = var.asg_public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "AWS-AS-VPC-subnet-public${count.index + 1}-${data.aws_availability_zones.available.names[count.index]}"
  }
}

resource "aws_subnet" "asg_private" {
  count                   = var.deploy_autoscale ? 2 : 0
  vpc_id                  = aws_vpc.asg[0].id
  cidr_block              = var.asg_private_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "AWS-AS-VPC-subnet-private${count.index + 1}-${data.aws_availability_zones.available.names[count.index]}"
  }
}

resource "aws_route_table" "asg_public" {
  count  = var.deploy_autoscale ? 1 : 0
  vpc_id = aws_vpc.asg[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.asg[0].id
  }

  tags = {
    Name = "AWS-AS-VPC-rtb-public"
  }
}

resource "aws_route_table_association" "asg_public" {
  count          = var.deploy_autoscale ? 2 : 0
  subnet_id      = aws_subnet.asg_public[count.index].id
  route_table_id = aws_route_table.asg_public[0].id
}

resource "aws_route_table" "asg_private" {
  count  = var.deploy_autoscale ? 2 : 0
  vpc_id = aws_vpc.asg[0].id

  tags = {
    Name = "AWS-AS-VPC-rtb-private${count.index + 1}-${data.aws_availability_zones.available.names[count.index]}"
  }
}

resource "aws_route_table_association" "asg_private" {
  count          = var.deploy_autoscale ? 2 : 0
  subnet_id      = aws_subnet.asg_private[count.index].id
  route_table_id = aws_route_table.asg_private[count.index].id
}

# ------------------------------------------------------------------------------
# Task 4B-4 & 4B-5: External Target Group (Port 9080) & CloudGuard Auto Scale
# ------------------------------------------------------------------------------
resource "aws_lb_target_group" "external" {
  count       = var.deploy_autoscale ? 1 : 0
  name        = "External-Target-Group"
  port        = 9080
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.asg[0].id

  health_check {
    protocol = "HTTP"
    port     = "traffic-port"
    path     = "/"
  }

  tags = {
    Name = "External-Target-Group"
  }
}

module "autoscale" {
  count   = var.deploy_autoscale ? 1 : 0
  source  = "CheckPointSW/cloudguard-network-security/aws//modules/autoscale"
  version = "1.2.1"

  prefix                                 = ""
  asg_name                               = "AWS-AutoScaling-GatewayGroup"
  vpc_id                                 = aws_vpc.asg[0].id
  subnet_ids                             = aws_subnet.asg_public[*].id
  gateway_name                           = "Check-Point-Gateway"
  gateway_instance_type                  = var.asg_gateway_instance_type
  key_name                               = local.effective_key_name
  enable_instance_connect                = true
  minimum_group_size                     = var.asg_min_size
  maximum_group_size                     = var.asg_max_size
  target_groups                          = [aws_lb_target_group.external[0].arn]
  gateway_version                        = var.chkp_version
  admin_shell                            = var.admin_shell
  gateway_password_hash                  = var.admin_password_hash
  gateway_maintenance_mode_password_hash = ""
  gateway_SICKey                         = var.sic_key
  gateways_provision_address_type        = "public"
  management_server                      = var.management_name
  configuration_template                 = var.cme_configuration_template
  gateway_bootstrap_script               = "clish -c 'set hostname ${var.asg_gateway_hostname}' -s"
}

# ------------------------------------------------------------------------------
# Task 4B-5: External Application Load Balancer (CP-External-1)
# ------------------------------------------------------------------------------
resource "aws_lb" "external" {
  count              = var.deploy_autoscale ? 1 : 0
  name               = "CP-External-1"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.autoscale[0].autoscale_security_group_id]
  subnets            = aws_subnet.asg_public[*].id

  tags = {
    Name = "CP-External-1"
  }
}

resource "aws_lb_listener" "external_http" {
  count             = var.deploy_autoscale ? 1 : 0
  load_balancer_arn = aws_lb.external[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.external[0].arn
  }
}

# ------------------------------------------------------------------------------
# Task 4B-5: Internal Network Load Balancer in Spoke1 (Internal-Load-Balancer)
# Tagged with x-chkp-management and x-chkp-template for CME auto-NAT/rule
# ------------------------------------------------------------------------------
resource "aws_lb_target_group" "internal" {
  count       = var.deploy_autoscale && var.deploy_spokes ? 1 : 0
  name        = "Internal-target-group"
  port        = 80
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = aws_vpc.spoke1[0].id

  health_check {
    protocol = "TCP"
    port     = "traffic-port"
  }

  tags = {
    Name = "Internal-target-group"
  }
}

resource "aws_lb_target_group_attachment" "internal_spoke1_web" {
  count            = var.deploy_autoscale && var.deploy_spokes ? 1 : 0
  target_group_arn = aws_lb_target_group.internal[0].arn
  target_id        = aws_instance.spoke1_web[0].id
  port             = 80
}

resource "aws_lb" "internal" {
  count              = var.deploy_autoscale && var.deploy_spokes ? 1 : 0
  name               = "Internal-Load-Balancer"
  internal           = true
  load_balancer_type = "network"
  security_groups    = [aws_security_group.spoke1_open[0].id]
  subnets            = [aws_subnet.spoke1[0].id]

  tags = {
    Name              = "Internal-Load-Balancer"
    x-chkp-management = var.management_name
    x-chkp-template   = var.cme_configuration_template
  }
}

resource "aws_lb_listener" "internal_tcp_80" {
  count             = var.deploy_autoscale && var.deploy_spokes ? 1 : 0
  load_balancer_arn = aws_lb.internal[0].arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.internal[0].arn
  }
}

# ------------------------------------------------------------------------------
# Task 4B-6 & 4B-7: Create VPC Peering (GW-to-Spoke1) and Configure Routing
# ------------------------------------------------------------------------------
resource "aws_vpc_peering_connection" "gw_to_spoke1" {
  count       = var.deploy_autoscale && var.deploy_spokes ? 1 : 0
  vpc_id      = aws_vpc.asg[0].id
  peer_vpc_id = aws_vpc.spoke1[0].id
  auto_accept = true

  tags = {
    Name = "GW-to-Spoke1"
  }
}

resource "aws_route" "spoke1_to_asg" {
  count                     = var.deploy_autoscale && var.deploy_spokes ? 1 : 0
  route_table_id            = aws_route_table.spoke1[0].id
  destination_cidr_block    = var.asg_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.gw_to_spoke1[0].id
}

resource "aws_route" "asg_public_to_spoke1" {
  count                     = var.deploy_autoscale && var.deploy_spokes ? 1 : 0
  route_table_id            = aws_route_table.asg_public[0].id
  destination_cidr_block    = var.spoke1_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.gw_to_spoke1[0].id
}
