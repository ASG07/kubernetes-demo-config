#!/bin/bash
# =============================================================================
# DEPLOY LARAVEL APPLICATION TO GKE
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local missing_tools=""
    
    if ! command -v terraform &> /dev/null; then
        missing_tools="$missing_tools terraform"
    fi
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools="$missing_tools kubectl"
    fi
    
    if ! command -v gcloud &> /dev/null; then
        missing_tools="$missing_tools gcloud"
    fi
    
    if ! command -v helm &> /dev/null; then
        missing_tools="$missing_tools helm"
    fi
    
    if [[ -n "$missing_tools" ]]; then
        print_error "Missing required tools:$missing_tools"
        echo "Please install the missing tools and try again."
        exit 1
    fi
    
    print_success "All prerequisites are installed!"
}

# Function to enable required GCP APIs
enable_apis() {
    print_status "Enabling required GCP APIs..."
    
    gcloud services enable \
        container.googleapis.com \
        compute.googleapis.com \
        sql-component.googleapis.com \
        redis.googleapis.com \
        servicenetworking.googleapis.com \
        secretmanager.googleapis.com \
        monitoring.googleapis.com \
        logging.googleapis.com
    
    print_success "GCP APIs enabled!"
}

# Function to deploy infrastructure with Terraform
deploy_infrastructure() {
    print_status "Deploying GKE cluster and supporting infrastructure..."
    
    cd terraform
    
    # Check if terraform.tfvars exists
    if [[ ! -f "terraform.tfvars" ]]; then
        print_warning "terraform.tfvars not found!"
        print_status "Please copy terraform.tfvars.example to terraform.tfvars and fill in your values"
        print_status "Example:"
        echo "cp terraform.tfvars.example terraform.tfvars"
        echo "# Edit terraform.tfvars with your project details"
        exit 1
    fi
    
    terraform init
    terraform plan
    
    read -p "Do you want to apply these changes? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        terraform apply -auto-approve
        print_success "Infrastructure deployed successfully!"
    else
        print_warning "Deployment cancelled by user"
        exit 0
    fi
    
    cd ..
}

# Function to configure kubectl
configure_kubectl() {
    print_status "Configuring kubectl..."
    
    local cluster_name
    local region
    
    cd terraform
    cluster_name=$(terraform output -raw cluster_name)
    region=$(terraform output -raw region || echo "us-central1")
    cd ..
    
    gcloud container clusters get-credentials "$cluster_name" --region="$region"
    print_success "kubectl configured for cluster: $cluster_name"
}

# Function to install essential production tools
install_production_tools() {
    print_status "Installing essential production tools..."
    
    # Add Helm repositories
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add jetstack https://charts.jetstack.io
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    
    # Install Prometheus & Grafana for monitoring
    print_status "Installing Prometheus & Grafana..."
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --create-namespace \
        --set grafana.enabled=true \
        --set alertmanager.enabled=true \
        --wait
    
    # Install cert-manager for SSL certificates
    print_status "Installing cert-manager..."
    helm upgrade --install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --create-namespace \
        --set installCRDs=true \
        --wait
    
    # Install NGINX Ingress Controller
    print_status "Installing NGINX Ingress Controller..."
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.service.type=LoadBalancer \
        --wait
    
    print_success "Essential production tools installed!"
}

# Function to deploy Laravel application
deploy_application() {
    print_status "Deploying Laravel application..."
    
    # Apply Kubernetes manifests
    kubectl apply -f k8s-simple/
    
    # Wait for deployment to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/laravel -n laravel
    
    print_success "Laravel application deployed!"
    
    # Get service information
    print_status "Getting service information..."
    kubectl get services -n laravel
    
    # Get ingress IP (if available)
    print_status "Waiting for LoadBalancer IP..."
    external_ip=""
    while [ -z $external_ip ]; do
        print_status "Waiting for external IP..."
        external_ip=$(kubectl get svc laravel -n laravel --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
        [ -z "$external_ip" ] && sleep 10
    done
    
    print_success "Application is accessible at: http://$external_ip"
}

# Function to show access information
show_access_info() {
    print_status "=== ACCESS INFORMATION ==="
    
    # Application URL
    external_ip=$(kubectl get svc laravel -n laravel --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}" 2>/dev/null || echo "pending")
    echo "🚀 Laravel Application: http://$external_ip"
    
    # Grafana dashboard
    echo "📊 Grafana Dashboard:"
    echo "   kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80"
    echo "   Then open: http://localhost:3000"
    echo "   Username: admin"
    grafana_password=$(kubectl get secret --namespace monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode)
    echo "   Password: $grafana_password"
    
    # ArgoCD (if installed)
    if kubectl get namespace argocd &> /dev/null; then
        echo "🔄 ArgoCD Dashboard:"
        echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
        echo "   Then open: https://localhost:8080"
    fi
    
    print_success "Deployment completed successfully!"
}

# Main execution
main() {
    echo "==================================================================="
    echo "🚀 GKE Production Deployment Script"
    echo "==================================================================="
    
    check_prerequisites
    
    # Check if user wants to skip infrastructure deployment
    if [[ "$1" == "--skip-infra" ]]; then
        print_warning "Skipping infrastructure deployment"
        configure_kubectl
    else
        enable_apis
        deploy_infrastructure
        configure_kubectl
    fi
    
    # Check if user wants to install production tools
    read -p "Install production tools (Prometheus, cert-manager, ingress-nginx)? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_warning "Skipping production tools installation"
    else
        install_production_tools
    fi
    
    deploy_application
    show_access_info
    
    echo "==================================================================="
    print_success "🎉 Deployment completed! Your Laravel app is running on GKE!"
    echo "==================================================================="
}

# Run main function with all arguments
main "$@"
