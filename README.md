# **🚀 ENHANCED README FOR TERRAFORM-AWS-EKS-PRODUCTION**

Based on your instructor's README + your repo structure + production best practices.

---

```markdown
# Terraform AWS EKS Production

Production-grade EKS infrastructure with Terraform, featuring modular architecture, blue-green node group capability, and complete application deployment workflow.

## 📁 Repository Structure

```
terraform-aws-eks-production/
├── infra/                          # Environment-specific configurations
│   ├── 00-vpc/                     # VPC, subnets, NAT gateway, IGW
│   ├── 10-sg/                      # Security groups for bastion, EKS nodes, RDS
│   ├── 20-sg-rules/                # Security group ingress/egress rules
│   ├── 30-bastion/                 # Bastion host for cluster access
│   ├── 40-rds/                     # RDS MySQL instance
│   ├── 50-parameter-store/         # SSM parameters for cross-layer state
│   ├── 60-eks/                     # EKS cluster and node groups
│   ├── 70-acm/                     # ACM certificate with DNS validation
│   └── 80-frontend-alb/            # Frontend ALB, listener, target group
│
└── modules/                        # Reusable Terraform modules
    ├── terraform-aws-eks/          # EKS cluster module (blue-green capable)
    ├── terraform-aws-sg/           # Security group module
    ├── terraform-aws-vpc/          # VPC module
    └── terraform-roboshop-comp.../  # Component module (bastion, RDS, etc.)
```

## 🎯 Key Features

- **Modular Design**: Reusable Terraform modules for VPC, EKS, security groups
- **Blue-Green Node Groups**: Zero-downtime platform upgrades
- **State Management**: SSM Parameter Store for cross-layer dependencies
- **Production-Ready**: ACM certificates, ALB, RDS, auto-scaling
- **Security**: Private subnets for EKS nodes, bastion host access, security group isolation

---

## 🛠️ Prerequisites

### Required Tools
- AWS CLI (v2+)
- Terraform (v1.5+)
- kubectl (v1.28+)
- eksctl (v0.150+)
- Helm (v3.12+)

### AWS Permissions
- Administrator access or equivalent permissions for:
  - VPC, EC2, EKS, RDS
  - IAM roles and policies
  - Route53, ACM
  - Systems Manager Parameter Store

### Domain Setup
- Route53 hosted zone configured
- Domain name for application (e.g., `daws88s.online`)

---

## 📋 Infrastructure Setup

### Step 1: Deploy Base Infrastructure

Deploy in numerical order (each layer stores outputs in SSM Parameter Store):

```bash
# 1. VPC Layer
cd infra/00-vpc
terraform init
terraform apply -auto-approve

# 2. Security Groups
cd ../10-sg
terraform init
terraform apply -auto-approve

# 3. Security Group Rules
cd ../20-sg-rules
terraform init
terraform apply -auto-approve

# 4. Bastion Host
cd ../30-bastion
terraform init
terraform apply -auto-approve

# 5. RDS MySQL
cd ../40-rds
terraform init
terraform apply -auto-approve

# 6. Parameter Store (if separate layer)
cd ../50-parameter-store
terraform init
terraform apply -auto-approve
```

### Step 2: Deploy EKS Cluster

```bash
cd ../60-eks
terraform init
terraform apply -auto-approve

# Wait ~15 minutes for cluster creation
```

**EKS Module Features:**
- Blue-green node group capability
- OIDC provider for IRSA (IAM Roles for Service Accounts)
- EBS and EFS CSI driver IAM roles pre-configured
- Auto-scaling node groups

### Step 3: Deploy ACM Certificate

```bash
cd ../70-acm
terraform init
terraform apply -auto-approve

# DNS validation completes in 5-10 minutes
```

### Step 4: Deploy Frontend ALB

```bash
cd ../80-frontend-alb
terraform init
terraform apply -auto-approve
```

---

## ☸️ Kubernetes Setup

### Connect to EKS Cluster

```bash
# SSH to bastion host
ssh -i <key-pair>.pem ec2-user@<bastion-ip>

# Configure AWS credentials on bastion
aws configure

# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name roboshop-dev

# Verify connectivity
kubectl get nodes
```

Expected output:
```
NAME                          STATUS   ROLES    AGE   VERSION
ip-10-0-11-123.ec2.internal   Ready    <none>   5m    v1.30.0-eks-036c24b
ip-10-0-12-456.ec2.internal   Ready    <none>   5m    v1.30.0-eks-036c24b
```

---

## 💾 Database Setup

### Install EBS CSI Driver

```bash
# Add Helm repository
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm repo update

# Install driver
helm upgrade --install aws-ebs-csi-driver \
  --namespace kube-system \
  aws-ebs-csi-driver/aws-ebs-csi-driver

# Verify installation
kubectl get pods -n kube-system | grep ebs-csi
```

### Create Namespace and Storage Class

```bash
cd 60-eks/app

# Create roboshop namespace
kubectl apply -f namespace.yaml

# Create EBS storage class
kubectl apply -f 01-storage-class/ebs-sc.yaml
```

**Storage Class Features:**
- `volumeBindingMode: WaitForFirstConsumer` - Creates EBS in correct AZ
- `reclaimPolicy: Retain` - Prevents accidental data loss
- Supports dynamic provisioning

### Deploy Databases (StatefulSets)

```bash
# MongoDB
kubectl apply -f 02-databases/mongodb/manifest.yaml

# Redis
kubectl apply -f 02-databases/redis/manifest.yaml

# RabbitMQ
kubectl apply -f 02-databases/rabbitmq/manifest.yaml

# Verify all databases are running
kubectl get pods -n roboshop -l tier=database
```

Expected output:
```
NAME          READY   STATUS    RESTARTS   AGE
mongodb-0     1/1     Running   0          2m
redis-0       1/1     Running   0          2m
rabbitmq-0    1/1     Running   0          2m
```

### Load MySQL Data (RDS)

MySQL is deployed as RDS (managed service). Load schema from bastion:

```bash
# Transfer schema files to bastion
scp -i <key>.pem schema/*.sql ec2-user@<bastion-ip>:/tmp/

# SSH to bastion
ssh -i <key>.pem ec2-user@<bastion-ip>

# Connect to RDS and load data
mysql -h <rds-endpoint> -u root -pRoboShop#123

# Load schemas
mysql -h <rds-endpoint> -u root -pRoboShop#123 < /tmp/shipping.sql
```

**Security Note**: RDS security group already configured to accept traffic from EKS nodes (via Terraform).

---

## 🚀 Application Deployment

### Deploy Backend Microservices (Helm)

All backend services are packaged as Helm charts:

```bash
cd 60-eks/app/03-backend

# Catalogue service
cd catalogue
helm upgrade --install catalogue . --namespace roboshop
cd ..

# User service
cd user
helm upgrade --install user . --namespace roboshop
cd ..

# Cart service
cd cart
helm upgrade --install cart . --namespace roboshop
cd ..

# Shipping service
cd shipping
helm upgrade --install shipping . --namespace roboshop
cd ..

# Payment service
cd payment
helm upgrade --install payment . --namespace roboshop
cd ..

# Verify all backend services
kubectl get pods -n roboshop -l tier=backend
```

### Deploy Frontend Application

```bash
cd ../04-frontend
helm upgrade --install frontend . --namespace roboshop

# Verify frontend deployment
kubectl get pods -n roboshop -l component=frontend
```

---

## 🌐 Expose Application to Internet

Two approaches available: **Ingress API (legacy)** and **Gateway API (modern)**. Gateway API is recommended for production.

---

### Option 1: Ingress API (Legacy)

**Note**: Ingress API is deprecated in favor of Gateway API but still widely used.

#### Prerequisites

OIDC provider already created as part of EKS Terraform module.

#### Create IAM Policy

```bash
# Download AWS Load Balancer Controller IAM policy
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.0/docs/install/iam_policy.json

# Create IAM policy
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam-policy.json

# Note the ARN from output:
# arn:aws:iam::<AWS_ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy
```

#### Create Service Account with IAM Role

```bash
eksctl create iamserviceaccount \
  --cluster=roboshop-dev \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::<AWS_ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --region us-east-1 \
  --approve
```

**What this does:**
1. Creates IAM role with OIDC trust policy
2. Attaches AWSLoadBalancerControllerIAMPolicy to role
3. Creates Kubernetes ServiceAccount with role annotation
4. Links ServiceAccount → IAM role via IRSA

#### Install AWS Load Balancer Controller (Helm)

```bash
# Add EKS Helm repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=roboshop-dev \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# Verify installation
kubectl get pods -n kube-system | grep aws-load-balancer-controller
```

Expected output:
```
aws-load-balancer-controller-abc123   1/1   Running   0   30s
aws-load-balancer-controller-def456   1/1   Running   0   30s
```

#### Deploy Ingress Resource

```bash
cd 60-eks/app/04-frontend
helm upgrade --install frontend . --namespace roboshop

# Verify Ingress created
kubectl get ingress -n roboshop

# Wait for ALB creation (2-3 minutes)
kubectl get ingress frontend -n roboshop -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

---

### Option 2: Gateway API (Modern, Recommended) ⭐

**Why Gateway API?**
- Type-safe resources (no annotation debugging)
- Role separation: Platform team manages Gateway, App team manages HTTPRoute
- Portable across cloud providers
- Advanced routing capabilities

#### Install Gateway API CRDs

```bash
# Install v1.5.0 (required for AWS LBC v3.x compatibility)
kubectl apply --server-side=true \
  -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml

# Verify CRDs installed
kubectl get crd | grep gateway
```

Expected output:
```
gatewayclasses.gateway.networking.k8s.io
gateways.gateway.networking.k8s.io
httproutes.gateway.networking.k8s.io
grpcroutes.gateway.networking.k8s.io
tlsroutes.gateway.networking.k8s.io
referencegrants.gateway.networking.k8s.io
backendtlspolicies.gateway.networking.k8s.io
```

#### Install AWS-Specific Gateway CRDs

```bash
# LoadBalancerConfiguration, TargetGroupConfiguration, etc.
kubectl apply \
  -f https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/refs/heads/main/config/crd/gateway/gateway-crds.yaml

# Verify TLSRoute is v1 (required by LBC v3.x)
kubectl get crd tlsroutes.gateway.networking.k8s.io -o yaml | grep "name: v1"
```

Must show: `name: v1`

#### Install AWS Load Balancer Controller (Gateway Mode)

```bash
# Get VPC ID from SSM Parameter Store
VPC_ID=$(aws ssm get-parameter --name /roboshop/dev/vpc_id \
  --region us-east-1 --query Parameter.Value --output text)

# Install with Gateway API feature gates enabled
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=roboshop-dev \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=us-east-1 \
  --set vpcId=$VPC_ID \
  --set controllerConfig.featureGates.ALBGatewayAPI=true \
  --set controllerConfig.featureGates.NLBGatewayAPI=true

# Wait for deployment to be ready
kubectl rollout status deployment aws-load-balancer-controller -n kube-system

# Verify pods running
kubectl get pods -n kube-system | grep aws-load-balancer-controller
```

#### Create GatewayClass (Platform Team)

```bash
cd 60-eks/app/05-gateway
kubectl apply -f gatewayclass.yaml

# Wait for ACCEPTED status
kubectl get gatewayclass roboshop-aws-alb
```

Expected output:
```
NAME              CONTROLLER            ACCEPTED   AGE
roboshop-aws-alb  gateway.k8s.aws/alb   True       10s
```

#### Create LoadBalancerConfiguration (Platform Team)

```bash
kubectl apply -f loadbalancerconfiguration.yaml
```

**What this configures:**
- `scheme: internet-facing` - Public ALB
- `ipAddressType: ipv4` - IPv4 only
- Subnet discovery via tags: `kubernetes.io/role/elb=1`

#### Create Gateway (Platform Team)

This creates the actual AWS ALB:

```bash
kubectl apply -f gateway.yaml

# Watch until PROGRAMMED=True and ADDRESS appears
kubectl get gateway -n roboshop -w
```

Expected output:
```
NAME               CLASS             ADDRESS                           PROGRAMMED   AGE
roboshop-gateway   roboshop-aws-alb  k8s-roboshop-xxx.us-east-1.elb... True         2m
```

**Gateway Configuration:**
- HTTP listener (port 80) - Redirects to HTTPS
- HTTPS listener (port 443) - TLS termination with ACM certificate
- Shared by all microservices

#### Expose Frontend (App Team)

```bash
kubectl apply -f frontend.yaml
```

This creates:
1. **TargetGroupConfiguration** - Registers pod IPs in ALB target group
2. **HTTPRoute** - Routes traffic from domain to frontend service

**Verify:**
```bash
# Check HTTPRoute created
kubectl get httproute -n roboshop

# Check TargetGroupConfiguration
kubectl get targetgroupconfiguration -n roboshop

# Test application
curl https://roboshop-dev.daws88s.online
```

---

## 🔄 Blue-Green Deployment

### Application-Level Blue-Green

Deploy new version alongside old version, test, then switch traffic:

```bash
# See k8s-blue-green repo for complete example
# https://github.com/chellojuramu/k8s-blue-green

# Quick workflow:
kubectl apply -f blue-deployment.yaml    # v1
kubectl apply -f main-service.yaml       # Points to blue
kubectl apply -f green-deployment.yaml   # v2
kubectl apply -f preview-service.yaml    # Points to green (testing)

# Test green internally
curl http://<preview-service-ip>

# Switch traffic to green (instant cutover)
kubectl patch service main -p '{"spec":{"selector":{"version":"green"}}}'

# Scale down blue to save costs
kubectl patch deployment blue -p '{"spec":{"replicas":0}}'

# Rollback if needed (30 seconds)
kubectl patch deployment blue -p '{"spec":{"replicas":2}}'
kubectl patch service main -p '{"spec":{"selector":{"version":"blue"}}}'
```

### Platform-Level Blue-Green (EKS Upgrade)

Upgrade EKS cluster from 1.34 to 1.35:

```bash
# Step 1: Upgrade control plane
cd infra/60-eks
terraform apply \
  -var="eks_version=1.35" \
  -var="eks_nodegroup_blue_version=1.34"

# Step 2: Create green node group
terraform apply \
  -var="eks_version=1.35" \
  -var="eks_nodegroup_blue_version=1.34" \
  -var="enable_green=true" \
  -var="eks_nodegroup_green_version=1.35"

# Step 3: Drain blue nodes (from bastion)
kubectl cordon <blue-node-1>
kubectl drain <blue-node-1> --ignore-daemonsets --delete-emptydir-data

# Step 4: Delete blue node group
terraform apply \
  -var="eks_version=1.35" \
  -var="enable_blue=false" \
  -var="enable_green=true" \
  -var="eks_nodegroup_green_version=1.35"
```

**Downtime:** Brief intermittent errors during pod migrations (not true zero downtime).

---

## 🧹 Cleanup

### Delete Kubernetes Resources

```bash
# Delete Gateway/Ingress (triggers ALB deletion)
kubectl delete gateway roboshop-gateway -n roboshop
# OR
kubectl delete ingress frontend -n roboshop

# Uninstall Load Balancer Controller
helm uninstall aws-load-balancer-controller -n kube-system

# Delete all applications
helm uninstall frontend catalogue user cart shipping payment -n roboshop

# Delete databases
kubectl delete -f 02-databases/mongodb/manifest.yaml
kubectl delete -f 02-databases/redis/manifest.yaml
kubectl delete -f 02-databases/rabbitmq/manifest.yaml

# Delete namespace
kubectl delete namespace roboshop
```

### Destroy Infrastructure

```bash
# Destroy in reverse order
cd infra/80-frontend-alb && terraform destroy -auto-approve
cd ../70-acm && terraform destroy -auto-approve
cd ../60-eks && terraform destroy -auto-approve
cd ../40-rds && terraform destroy -auto-approve
cd ../30-bastion && terraform destroy -auto-approve
cd ../20-sg-rules && terraform destroy -auto-approve
cd ../10-sg && terraform destroy -auto-approve
cd ../00-vpc && terraform destroy -auto-approve
```

---

## 🔍 Troubleshooting

### Common Issues

#### Issue 1: Nodes Not Ready

```bash
# Check node status
kubectl get nodes

# Describe node for events
kubectl describe node <node-name>

# Check kubelet logs (SSH to node)
journalctl -u kubelet -f
```

**Solution**: Verify security group rules allow pod networking (port 10250).

#### Issue 2: Pods ImagePullBackOff

```bash
# Check pod events
kubectl describe pod <pod-name> -n roboshop

# Common causes:
# - Wrong image name
# - Private registry without credentials
# - Network issue pulling from Docker Hub
```

**Solution**: Verify image exists in Docker Hub or ECR.

#### Issue 3: ALB Not Creating

```bash
# Check load balancer controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Common causes:
# - Subnet tags missing (kubernetes.io/role/elb=1)
# - IAM policy insufficient permissions
# - VPC ID mismatch
```

**Solution**: Verify subnet tags in VPC Terraform.

#### Issue 4: 404 Errors After Deployment

```bash
# Check service endpoints
kubectl get endpoints -n roboshop <service-name>

# If empty, pods not matching service selector
kubectl get pods -n roboshop --show-labels

# Check ALB target group health
aws elbv2 describe-target-health --target-group-arn <arn>
```

**Solution**: Ensure pod labels match service selector.

---

## 📚 Architecture Diagrams

### Infrastructure Architecture

```
Internet
   ↓
Route53 (roboshop-dev.daws88s.online)
   ↓
ALB (internet-facing, public subnets)
   ↓
EKS Cluster (private subnets)
   ├── Frontend Pods (Deployment)
   ├── Backend Pods (Deployments)
   │   ├── Catalogue
   │   ├── User
   │   ├── Cart
   │   ├── Shipping
   │   └── Payment
   └── Databases (StatefulSets)
       ├── MongoDB (EBS persistent storage)
       ├── Redis (cache)
       └── RabbitMQ (message queue)

MySQL RDS (private subnets, managed service)

Bastion Host (public subnet, SSH access)
```

### Gateway API Request Flow

```
User Browser
   ↓
DNS: roboshop-dev.daws88s.online → ALB
   ↓
ALB (HTTPS 443, TLS termination with ACM cert)
   ↓
Gateway Listener (matches host header)
   ↓
HTTPRoute (routes /api/cart to cart service)
   ↓
TargetGroupConfiguration (registers pod IPs)
   ↓
Service (ClusterIP, selects pods)
   ↓
Pod IP (direct connection, no NodePort)
```

---

## 🎯 Best Practices

### Security
- ✅ EKS nodes in private subnets
- ✅ Bastion host for cluster access (no direct internet)
- ✅ IRSA for pod-level IAM permissions (no static credentials)
- ✅ Security group isolation (nodes, RDS, bastion)
- ✅ TLS termination at ALB with ACM certificate

### High Availability
- ✅ Multi-AZ deployment (EKS nodes, RDS, ALB)
- ✅ Auto-scaling node groups
- ✅ StatefulSets for databases with persistent storage
- ✅ Health checks and readiness probes

### Operational Excellence
- ✅ SSM Parameter Store for cross-layer state
- ✅ Terraform modules for reusability
- ✅ Helm charts for application deployment
- ✅ Blue-green capability for zero-downtime upgrades
- ✅ Comprehensive logging and monitoring setup

### Cost Optimization
- ✅ Right-sized instance types (t3.medium for nodes)
- ✅ Auto-scaling to match demand
- ✅ Spot instances for non-critical workloads (optional)
- ✅ Blue-green node groups scaled down after cutover

---

## 📖 Additional Resources

- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Helm Documentation](https://helm.sh/docs/)

---

## 📝 Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request with clear description

---

## 📄 License

MIT License - See LICENSE file for details

---

## 👤 Author

**Ramu Chelloju**
- GitHub: [@chellojuramu](https://github.com/chellojuramu)
- Docker Hub: [chelloju](https://hub.docker.com/u/chelloju)
- LinkedIn: [Ramu Chelloju](https://linkedin.com/in/ramuchelloju)

---

## 🙏 Acknowledgments

- DevOps Simplified Community
- AWS EKS Documentation
- Kubernetes SIG-Network (Gateway API)
