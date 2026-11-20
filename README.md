# Check Point Certified Cloud Specialist (CCCS R81.20) — AWS Lab em Terraform

Infraestrutura como Código (Terraform) para provisionamento rápido na AWS de toda a topologia prática do material **Check Point Certified Cloud Specialist (CCCS R81.20)** presente em `CCCS_R8120.pdf`.

---

## Arquitetura do Laboratório (CCCS AWS Topology)

A infraestrutura reproduz fielmente todos os laboratórios de AWS do curso (**Labs 3B, 4B, 5B, 6B e 8A**) utilizando os módulos oficiais da Check Point (`CheckPointSW/cloudguard-network-security/aws`):

1. **Lab 3B — Security Management Server (`lab3b_management.tf`)**
   - **Key Pair (`keypair.tf`)**: Gera automaticamente o par de chaves `AWS-Lab-Key` e salva `AWS-Lab-Key.pem` localmente.
   - **VPC `CPMGMT-vpc` (`10.1.0.0/16`)**: Subnet pública `10.1.0.0/24` + Internet Gateway + Route Table.
   - **Check Point Security Management Server (`CPMGMT`)**: Instância `m5.xlarge` (`R81.20-BYOL`), Elastic IP associado, `admin` shell `/bin/bash`, senha/maintenance mode `Checkpoint123` e **IAM Role do CME** com permissões Read-Write (Task 3B-3).
   - **Automação CME & Access Policy (Tasks 3B-4 & 3B-5)**: Script de bootstrap opcional (`auto_configure_cme_and_policy = true`) que já cria o pacote de política `AWS-Scale-Policy` (com regra de Accept + Log) e inicializa o **Cloud Management Extension (`autoprov_cfg`)** apontando para o template `AWS-Scale-Lab-Template`.

2. **Lab 4B — AWS EC2 Auto Scaling & Spoke VPCs (`lab4b_autoscale.tf`)**
   - **Spoke VPCs (Task 4B-1)**:
     - `Spoke1` (`10.10.0.0/24`) com subnet `Spoke1-subnet` (`10.10.0.0/24`) e Security Group `Open`.
     - `Spoke2` (`10.20.0.0/24`) com subnet `Spoke2-subnet` (`10.20.0.0/24`) e Security Group `Open`.
   - **Web Servers (Task 4B-2)**: Instâncias `t3.micro` (`Spoke1-Web-Server` e `Spoke2-Web-Server`) com Apache HTTP pré-configurado (funcionam sem necessidade de internet nas subnets isoladas dos Spokes e incluem o usuário `bitnami` para compatibilidade com a Task 5B-9).
   - **Auto Scale VPC (`AWS-AS-VPC` — Task 4B-3)**: CIDR `10.100.0.0/16` em 2 Availability Zones, com 2 subnets públicas (`10.100.0.0/24`, `10.100.1.0/24`), 2 subnets privadas (`10.100.2.0/24`, `10.100.3.0/24`) e Internet Gateway.
   - **CloudGuard Auto Scale Group (Task 4B-4)**: Gateways `c5.large` (`R81.20-BYOL`, min `2`, max `4`), tagueados com `x-chkp-tags` (`management=CPMGMT:template=AWS-Scale-Lab-Template:ip-address=public`).
   - **External & Internal Load Balancers (Task 4B-5)**:
     - **ALB Externo (`CP-External-1`)**: Internet-facing na porta `80` encaminhando para o Target Group `External-Target-Group` na porta `9080` dos Gateways do ASG.
     - **NLB Interno (`Internal-Load-Balancer`)**: No `Spoke1` na porta `TCP:80` encaminhando para `Internal-target-group` (`Spoke1-Web-Server`), tagueado com `x-chkp-management = CPMGMT` e `x-chkp-template = AWS-Scale-Lab-Template` para criação automática de regras de NAT/Access pelo CME.
   - **VPC Peering & Routing (Tasks 4B-6 & 4B-7)**: Peering `GW-to-Spoke1` entre `AWS-AS-VPC` e `Spoke1` com rotas bidirecionais configuradas.

3. **Lab 5B — CloudGuard Cluster & AWS Site-to-Site VPN (`lab5b_cluster_vpn.tf`)**
   - **Cluster VPC (`AWS-Cluster-VPC` — Task 5B-1)**: South Hub com CIDR `10.50.0.0/16`, subnet pública Frontend (`10.50.10.0/24`) e subnet privada Backend (`10.50.20.0/24`).
   - **CloudGuard Single-AZ HA Cluster (`AWS-Cluster` — Task 5B-1)**: 2 membros (`c5.large`, `R81.20-BYOL`) com 3 Elastic IPs (Cluster VIP, Member A, Member B), IPs secundários privados nas interfaces `eth0` e `eth1`, IAM Role de Cluster HA e rota default da subnet privada apontando para a ENI interna do Member A.
   - **AWS Site-to-Site VPN (Task 5B-3 & 5B-9)**:
     - Virtual Private Gateway `Spoke1-VPN` anexado à VPC `Spoke1`.
     - Customer Gateway apontando para o IP Público VIP do Cluster.
     - Conexão VPN estática `Spoke-1 VPN Connection` (`0.0.0.0/0`, IKEv1, AES-128, SHA-1, DH Group 2, CIDR interno `169.254.191.236/30`).
     - Rota `0.0.0.0/0` na Route Table do `Spoke1` apontando para o VGW (`vgw-xxxx`).

---

## Pré-requisitos na AWS

1. **Aceitar os termos do AWS Marketplace (obrigatório pela AWS — veja pág. 379 do guia)**:
   Antes do `terraform apply`, acesse o AWS Marketplace na sua conta e aceite os termos (Subscribe) para:
   - **Check Point CloudGuard Network Security with R81.20 (BYOL)** — *Security Management*
   - **Check Point CloudGuard Network Security with R81.20 (BYOL)** — *Next-Gen Firewall / Security Gateway*
2. **Credenciais AWS configuradas** (`aws configure` ou variáveis de ambiente `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`).
3. **Terraform >= 1.3** instalado.

---

## Como fazer o Deploy Rápido

```bash
# 1. Inicializar os providers e módulos oficiais da Check Point
terraform init

# 2. (Opcional) Personalizar variáveis (região, flags de labs, etc.)
cp terraform.tfvars.example terraform.tfvars

# 3. Revisar o plano e aplicar
terraform apply
```

> **Tempo estimado**: A criação dos recursos na AWS leva ~5–8 minutos. A inicialização interna (First Time Wizard + CME) do Security Management Server e dos Gateways leva cerca de **15 a 20 minutos** após o término do `terraform apply`.

---

## Deploy Parcial (Por Laboratório)

Se você quiser subir apenas parte do laboratório para economizar custos ou praticar passo a passo, basta ajustar as flags no `terraform.tfvars` ou via linha de comando:

- **Apenas Lab 3B (Management Server)**:
  ```bash
  terraform apply -var="deploy_spokes=false" -var="deploy_autoscale=false" -var="deploy_cluster=false" -var="deploy_vpn=false"
  ```
- **Labs 3B + 4B (Management + Auto Scaling + Spokes)**:
  ```bash
  terraform apply -var="deploy_cluster=false" -var="deploy_vpn=false"
  ```

---

## Passos Pós-Deploy (SmartConsole — Labs 5B e 6B)

Após o `terraform apply`, execute `terraform output` para visualizar todos os IPs, URLs e comandos prontos:

1. **Testar o Lab 4B (Auto Scaling Inbound)**:
   - Acompanhe o provisionamento no Management Server:
     ```bash
     ssh -i AWS-Lab-Key.pem admin@<PUBLIC_IP_CPMGMT>
     tail -f /var/log/CPcme/cme.log
     ```
   - Assim que os gateways forem provisionados pelo CME, abra no navegador a URL retornada no output `external_alb_test_url` (`http://<DNS_DO_CP_EXTERNAL_1>`).

2. **Configurar o Cluster e VPN no SmartConsole (Lab 5B — Tasks 5B-2, 5B-4 a 5B-8)**:
   - Os valores exatos de **Cluster Public VIP**, **Member A/B Public IPs**, **Secondary Private IPs (`eth0` e `eth1`)** e os **comandos Clish da VTI (`vpnt1`)** são exibidos automaticamente no output `lab5b_cluster_and_vpn`.
   - Se desejar que o próprio Terraform já execute os comandos Clish das Tasks 5B-4 e 5B-5 nos membros do Cluster, defina `auto_configure_cluster_vti = true`.

3. **Destruir o Laboratório**:
   ```bash
   terraform destroy
   ```

---

## Diagram as Code (Módulo Opcional)

Para gerar uma visão gráfica da topologia AWS levando em consideração as flags, CIDRs e recursos configurados no seu código (`terraform.tfvars` / `variables.tf`), utilize o módulo opcional `modules/diagram_as_code` (desabilitado por padrão: `enable_diagram = false`).

```bash
# Gerar apenas a topologia gráfica em docs/ (sem criar recursos na AWS)
terraform apply -target=module.diagram_as_code -var="enable_diagram=true"
```

Arquivos gerados em `docs/`:
- `docs/topology.md` e `docs/topology.mmd`: Diagrama **Mermaid** pronto para visualização nativa no VS Code, GitHub ou GitLab (sem dependências externas).
- `docs/topology_aws_icons.py`: Script Python (`diagrams`) com ícones oficiais da AWS para geração de PNG (`python3 docs/topology_aws_icons.py` ou `-var="diagram_render_png=true"`).
