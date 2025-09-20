# 🚀 Production-Ready Kubernetes Tools & Best Practices

This guide covers essential tools and practices for running Kubernetes in production, specifically tailored for your Laravel application on GKE.

## 📊 **1. Monitoring & Observability Stack**

### **Core Monitoring: Prometheus + Grafana**
```bash
# Install Prometheus Operator
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.enabled=true \
  --set alertmanager.enabled=true
```

**What it provides:**
- ✅ Cluster, node, and pod metrics
- ✅ Custom application metrics
- ✅ Beautiful dashboards
- ✅ Alerting rules

### **Application Performance Monitoring (APM)**

#### **Option A: New Relic (Recommended for Laravel)**
```yaml
# newrelic-agent.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: newrelic-config
data:
  newrelic.ini: |
    [newrelic]
    license_key = "YOUR_LICENSE_KEY"
    appname = "Laravel App"
```

#### **Option B: Datadog**
```bash
helm repo add datadog https://helm.datadoghq.com
helm install datadog-operator datadog/datadog-operator
```

### **Distributed Tracing: Jaeger**
```bash
kubectl create namespace observability
kubectl apply -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.49.0/jaeger-operator.yaml -n observability
```

## 🔐 **2. Security & Compliance**

### **Security Scanning: Trivy + Falco**
```bash
# Install Trivy for vulnerability scanning
helm repo add aqua https://aquasecurity.github.io/helm-charts/
helm install trivy-operator aqua/trivy-operator \
  --namespace trivy-system \
  --create-namespace

# Install Falco for runtime security
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm install falco falcosecurity/falco \
  --namespace falco \
  --create-namespace
```

### **Policy Management: OPA Gatekeeper**
```bash
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml
```

### **Secret Management: External Secrets Operator**
```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets-system \
  --create-namespace
```

**Connect to Google Secret Manager:**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: google-secret-manager
spec:
  provider:
    gcpsm:
      projectId: "your-project-id"
      auth:
        workloadIdentity:
          clusterLocation: us-central1
          clusterName: laravel-production
          serviceAccountRef:
            name: external-secrets-sa
```

### **Certificate Management: cert-manager**
```bash
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true
```

## 🔄 **3. GitOps & CI/CD Enhancement**

### **ArgoCD Add-ons**
```bash
# Install ArgoCD Image Updater
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml

# Install ArgoCD Notifications
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/notifications_catalog/install.yaml
```

### **Enhanced CI/CD with GitHub Actions**
```yaml
# .github/workflows/deploy.yml
name: Deploy to GKE
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - id: auth
      uses: google-github-actions/auth@v1
      with:
        credentials_json: ${{ secrets.GCP_SA_KEY }}
    
    - name: Set up Cloud SDK
      uses: google-github-actions/setup-gcloud@v1
    
    - name: Configure Docker
      run: gcloud auth configure-docker
    
    - name: Build and Push
      run: |
        docker build -t gcr.io/${{ secrets.PROJECT_ID }}/laravel:${{ github.sha }} .
        docker push gcr.io/${{ secrets.PROJECT_ID }}/laravel:${{ github.sha }}
    
    - name: Update GitOps Repo
      run: |
        # Update image tag in kubernetes manifests
        sed -i 's|image: .*/laravel:.*|image: gcr.io/${{ secrets.PROJECT_ID }}/laravel:${{ github.sha }}|' k8s-simple/laravel.yaml
        git commit -am "Update image to ${{ github.sha }}"
        git push
```

## 🌐 **4. Networking & Ingress**

### **Ingress Controller: NGINX Ingress**
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer
```

### **Service Mesh: Istio (for advanced use cases)**
```bash
curl -L https://istio.io/downloadIstio | sh -
istioctl install --set values.defaultRevision=default
kubectl label namespace laravel istio-injection=enabled
```

## 📦 **5. Package Management & Deployment**

### **Helm for Complex Applications**
```bash
# Create Helm chart for your Laravel app
helm create laravel-app
```

### **Kustomize for Environment Management**
```bash
# Structure your configs
├── base/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   └── service.yaml
├── overlays/
│   ├── dev/
│   ├── staging/
│   └── production/
```

## 🔧 **6. Development & Testing Tools**

### **Local Development: Skaffold**
```yaml
# skaffold.yaml
apiVersion: skaffold/v3
kind: Config
build:
  artifacts:
  - image: laravel-app
deploy:
  kubectl:
    manifests:
    - k8s-simple/*.yaml
```

### **Testing: Kubernetes Test Framework**
```bash
# Install Ginkgo for testing
go install github.com/onsi/ginkgo/v2/ginkgo@latest
```

## 💾 **7. Backup & Disaster Recovery**

### **Velero for Cluster Backup**
```bash
# Install Velero CLI
curl -fsSL -o velero-v1.12.1-linux-amd64.tar.gz https://github.com/vmware-tanzu/velero/releases/download/v1.12.1/velero-v1.12.1-linux-amd64.tar.gz

# Install Velero on cluster
velero install \
  --provider gcp \
  --plugins velero/velero-plugin-for-gcp:v1.8.0 \
  --bucket your-backup-bucket \
  --secret-file ./credentials-velero
```

## 📈 **8. Cost Management & Optimization**

### **Cost Monitoring: KubeCost**
```bash
helm repo add kubecost https://kubecost.github.io/cost-analyzer/
helm install kubecost kubecost/cost-analyzer \
  --namespace kubecost \
  --create-namespace \
  --set kubecostToken="your-token"
```

### **Resource Right-Sizing: Goldilocks**
```bash
helm repo add fairwinds-stable https://charts.fairwinds.com/stable
helm install goldilocks fairwinds-stable/goldilocks \
  --namespace goldilocks \
  --create-namespace
```

## 🏗️ **9. Infrastructure as Code Enhancements**

### **Terraform Modules Structure**
```
terraform/
├── modules/
│   ├── gke/
│   ├── networking/
│   └── monitoring/
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
└── shared/
```

### **Terragrunt for Multi-Environment Management**
```hcl
# terragrunt.hcl
terraform {
  source = "../../modules/gke"
}

inputs = {
  project_id    = "my-project-dev"
  environment   = "dev"
  node_count    = 2
}
```

## 📱 **10. Mobile/API-Specific Tools**

### **API Gateway: Kong**
```bash
helm repo add kong https://charts.konghq.com
helm install kong kong/kong \
  --namespace kong \
  --create-namespace
```

### **Rate Limiting & Traffic Management**
```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: laravel-rate-limit
spec:
  http:
  - match:
    - uri:
        prefix: "/api"
    fault:
      delay:
        percentage:
          value: 0.1
        fixedDelay: 5s
```

## 🎯 **11. Recommended Tool Stack by Priority**

### **Tier 1 (Essential - Deploy Immediately)**
1. **Monitoring**: Prometheus + Grafana
2. **Security**: cert-manager for TLS
3. **Ingress**: NGINX Ingress Controller
4. **Secrets**: External Secrets Operator
5. **Backup**: Velero

### **Tier 2 (Important - Deploy Within 1 Month)**
1. **APM**: New Relic or Datadog
2. **Security**: Trivy + Falco
3. **Policy**: OPA Gatekeeper
4. **Cost**: KubeCost
5. **Testing**: Proper CI/CD pipelines

### **Tier 3 (Advanced - After Stabilization)**
1. **Service Mesh**: Istio (if microservices)
2. **Tracing**: Jaeger
3. **API Gateway**: Kong
4. **Advanced Monitoring**: Custom dashboards

## 📋 **12. Production Checklist**

### **Pre-Launch**
- [ ] Security scanning enabled
- [ ] Monitoring dashboards configured
- [ ] Alerting rules set up
- [ ] Backup strategy tested
- [ ] Disaster recovery plan documented
- [ ] Load testing completed
- [ ] SSL certificates configured

### **Post-Launch**
- [ ] Monitor resource usage patterns
- [ ] Optimize based on real traffic
- [ ] Set up automated scaling rules
- [ ] Regular security audits
- [ ] Performance tuning based on metrics

## 💡 **Quick Start Priority List**

**Week 1:**
```bash
# Core monitoring
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

# TLS certificates
helm install cert-manager jetstack/cert-manager -n cert-manager --create-namespace --set installCRDs=true

# Ingress
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace
```

**Week 2:**
```bash
# Security
helm install trivy-operator aqua/trivy-operator -n trivy-system --create-namespace

# Secrets management
helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace

# Backup
velero install --provider gcp
```

This comprehensive toolset will give you a production-ready Kubernetes environment with proper observability, security, and operational capabilities! 🚀
