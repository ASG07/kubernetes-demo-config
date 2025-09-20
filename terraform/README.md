# GKE Production Cluster with Terraform

This Terraform configuration creates a production-ready Google Kubernetes Engine (GKE) cluster with all necessary supporting infrastructure.

## 🏗️ Architecture Overview

### Infrastructure Components
- **GKE Cluster**: Regional cluster with auto-scaling node pools
- **Networking**: Custom VPC with private subnets and NAT gateway
- **Database**: Cloud SQL MySQL with high availability
- **Caching**: Redis (Memorystore) for session/cache storage
- **Security**: Private cluster, Workload Identity, Network Policies
- **Monitoring**: Integrated GCP monitoring and logging

### Network Architecture
```
Internet → Cloud Load Balancer → GKE Cluster (Private)
                                      ↓
                              Cloud SQL (Private)
                                      ↓
                              Redis (Private)
```

## 🚀 Quick Start

### Prerequisites
1. **GCP Account** with billing enabled
2. **Terraform** >= 1.0 installed
3. **gcloud CLI** installed and authenticated
4. **kubectl** installed

### Setup Steps

1. **Enable Required APIs**
   ```bash
   gcloud services enable \
     container.googleapis.com \
     compute.googleapis.com \
     sql-component.googleapis.com \
     redis.googleapis.com \
     servicenetworking.googleapis.com
   ```

2. **Configure Authentication**
   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```

3. **Set Your Project**
   ```bash
   gcloud config set project YOUR_PROJECT_ID
   ```

4. **Configure Terraform Variables**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

5. **Deploy Infrastructure**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

6. **Configure kubectl**
   ```bash
   gcloud container clusters get-credentials $(terraform output -raw cluster_name) --region=$(terraform output -raw region)
   ```

## 📝 Configuration

### Required Variables (terraform.tfvars)
```hcl
project_id = "your-gcp-project-id"
region     = "us-central1"
cluster_name = "laravel-production"
```

### Optional Variables
See `variables.tf` for all available options including:
- Node pool configuration
- Database sizing
- Security settings
- Network configuration

## 🔒 Security Features

### Cluster Security
- ✅ Private cluster (nodes have no public IPs)
- ✅ Authorized networks for API server access
- ✅ Network policies enabled
- ✅ Workload Identity for pod-to-GCP service authentication
- ✅ Shielded GKE nodes
- ✅ Node auto-upgrade and auto-repair

### Database Security
- ✅ Private IP only (no public access)
- ✅ SSL/TLS required
- ✅ Automated backups with point-in-time recovery
- ✅ High availability (regional)

## 📊 Monitoring & Observability

### Built-in Monitoring
- **GKE Monitoring**: Cluster and node metrics
- **Application Logs**: Centralized logging
- **SQL Insights**: Database performance monitoring
- **Uptime Monitoring**: Application availability

### Recommended Add-ons (see Production Tools section)
- Prometheus & Grafana
- Jaeger for distributed tracing
- AlertManager for alerting

## 💰 Cost Optimization

### Included Features
- **Spot Instance Pool**: For non-critical workloads (60-91% savings)
- **Auto-scaling**: Scale down during low usage
- **Preemptible Nodes**: Optional spot instances
- **Resource Quotas**: Prevent resource waste

### Estimated Monthly Costs (us-central1)
- **GKE Cluster**: ~$75/month (management fee)
- **2x e2-standard-4 nodes**: ~$120/month
- **Cloud SQL (db-n1-standard-2)**: ~$170/month
- **Redis (1GB)**: ~$25/month
- **Load Balancer**: ~$20/month
- **Total**: ~$410/month

## 🔄 Deployment Workflow

### GitOps with ArgoCD
Your existing ArgoCD configuration will work seamlessly:

```yaml
# Update application.yaml
spec:
  destination:
    server: https://YOUR_GKE_CLUSTER_ENDPOINT
    namespace: laravel
```

### CI/CD Integration
```bash
# In your CI/CD pipeline
gcloud container clusters get-credentials $CLUSTER_NAME --region=$REGION
kubectl apply -f k8s-simple/
```

## 🛠️ Maintenance

### Regular Tasks
- Monitor cluster autoscaler events
- Review SQL slow query logs
- Update node images (automated)
- Review security advisories

### Backup Strategy
- **Database**: Automated daily backups (7-day retention)
- **Application Config**: Stored in Git (GitOps)
- **Persistent Volumes**: Automatic snapshot policies

## 🚨 Disaster Recovery

### Multi-Region Setup
For production, consider deploying across multiple regions:
```hcl
# In terraform.tfvars
region = "us-central1"  # Primary
# Add secondary region configuration
```

### Backup & Restore
- Database backups are automated
- Use Cloud SQL import/export for migrations
- GitOps ensures configuration reproducibility

## 📚 Next Steps

After deployment:
1. Install production tools (see recommendations below)
2. Configure monitoring dashboards
3. Set up alerting rules
4. Implement backup verification
5. Create runbooks for common operations

## 🆘 Troubleshooting

### Common Issues
1. **API Not Enabled**: Enable required GCP APIs
2. **Quota Exceeded**: Request quota increases
3. **Network Connectivity**: Check firewall rules
4. **Authentication**: Verify service account permissions

### Getting Help
- Check Terraform logs: `terraform apply -debug`
- GKE logs: `kubectl logs -n kube-system`
- GCP Console: Cloud Logging for detailed logs

## 🧹 Cleanup

To destroy all resources:
```bash
# WARNING: This will delete everything including databases
terraform destroy
```

For production, consider using deletion protection and backup policies.
