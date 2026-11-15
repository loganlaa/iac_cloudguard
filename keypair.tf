# ==============================================================================
# Task 3B-1: Create SSH Key Pair (AWS-Lab-Key)
# ==============================================================================
resource "tls_private_key" "lab_key" {
  count     = var.create_key_pair ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "lab_key" {
  count      = var.create_key_pair ? 1 : 0
  key_name   = var.key_name
  public_key = tls_private_key.lab_key[0].public_key_openssh

  tags = {
    Name = var.key_name
  }
}

resource "local_sensitive_file" "private_key_pem" {
  count           = var.create_key_pair ? 1 : 0
  content         = tls_private_key.lab_key[0].private_key_pem
  filename        = "${path.module}/${var.key_name}.pem"
  file_permission = "0400"
}

locals {
  effective_key_name = var.create_key_pair ? aws_key_pair.lab_key[0].key_name : var.key_name
}
