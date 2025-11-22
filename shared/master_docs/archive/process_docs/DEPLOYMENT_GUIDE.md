# NSReady Platform - Tier-2 Deployment Guide

## Overview

This guide covers the deployment, scaling, and maintenance of the NTPPL NS-Ready Data Collection and Configuration Platform on Kubernetes (Tier-2).

## Prerequisites

### Cluster Requirements
- Kubernetes cluster (version ≥ 1.30)
- Helm (version ≥ 3.0)
- kubectl configured with cluster access
- Ingress controller (NGINX recommended)
- cert-manager (for TLS certificates)
- Storage class configured for PVCs

### Tools Required
- `kubectl` - Kubernetes CLI
- `helm` - Helm package manager
- `docker` - For building images (if building locally)
- `aws-cli` - For S3 backups (optional)

### Access Requirements
- Cluster admin access for initial setup
- Namespace creation permissions
- Image registry access (GHCR, Docker Hub, or private registry)

## Quick Start

### 1. Clone and Prepare

```bash
git clone <repository-url>
cd ntppl_nsready_platform
```

### 2. Configure Secrets

Update `deploy/k8s/secrets.yaml` or use Helm values:

```bash
# Generate secure passwords
POSTGRES_PASSWORD=$(openssl rand -base64 32)
JWT_SECRET=$(openssl rand -base64 32)
NATS_TOKEN=$(openssl rand -base64 32)

# Update values.yaml or use --set flags
```

### 3. Deploy Using Helm (Recommended)

```bash
# Add any required Helm repositories
helm repo add <repo-name> <repo-url>

# Install the chart
helm install nsready deploy/helm/nsready \
  --namespace nsready-tier2 \
  --create-namespace \
  --set secrets.postgresPassword="${POSTGRES_PASSWORD}" \
  --set secrets.jwtSecret="${JWT_SECRET}" \
  --set secrets.natsToken="${NATS_TOKEN}" \
  --set imageRegistry="ghcr.io/your-org" \
  --wait
```

### 4. Deploy Using kubectl (Alternative)

```bash
# Create namespace
kubectl apply -f deploy/k8s/namespace.yaml

# Apply secrets (update first!)
kubectl apply -f deploy/k8s/secrets.yaml

# Apply ConfigMaps
kubectl apply -f deploy/k8s/configmap.yaml

# Deploy services
kubectl apply -f deploy/k8s/postgres-statefulset.yaml
kubectl apply -f deploy/k8s/nats-statefulset.yaml
kubectl apply -f deploy/k8s/admin_tool-deployment.yaml
kubectl apply -f deploy/k8s/collector_service-deployment.yaml

# Deploy ingress
kubectl apply -f deploy/k8s/ingress.yaml

# Deploy autoscaling
kubectl apply -f deploy/k8s/hpa.yaml

# Deploy RBAC
kubectl apply -f deploy/k8s/rbac.yaml
```

## Configuration

### Environment Variables

Key configuration options in `deploy/helm/nsready/values.yaml`:

```yaml
# Worker Configuration
collectorService:
  workerPoolSize: 4
  workerBatchSize: 50
  workerBatchTimeout: 0.5
  natsPullBatchSize: 100

# Autoscaling
collectorService:
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
```

### Ingress Configuration

Update domain names in `deploy/k8s/ingress.yaml` or Helm values:

```yaml
ingress:
  hosts:
    - host: admin.nsready.example.com
    - host: collector.nsready.example.com
```

### Database Configuration

For production, use managed database services:

```yaml
postgres:
  useManagedService: true
  managedService:
    host: "your-rds-endpoint.amazonaws.com"
    port: 5432
```

## Monitoring Setup

### 1. Deploy Prometheus

```bash
kubectl apply -f deploy/monitoring/prometheus.yaml
```

### 2. Deploy Alertmanager

```bash
# Update Slack webhook in alertmanager.yaml
kubectl apply -f deploy/monitoring/alertmanager.yaml
```

### 3. Access Dashboards

```bash
# Port forward to access Prometheus
kubectl port-forward -n nsready-tier2 svc/prometheus 9090:9090

# Access at http://localhost:9090
```

### 4. Import Grafana Dashboard

Import `deploy/monitoring/grafana-dashboards/dashboard.json` into Grafana.

## Backup & Restore

### Automated Backups

Backups run daily via CronJob:

```bash
# View backup schedule
kubectl get cronjobs -n nsready-tier2

# Manually trigger backup
kubectl create job --from=cronjob/postgres-backup manual-backup-$(date +%s) -n nsready-tier2
```

### Manual Backup

```bash
# PostgreSQL backup
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  pg_dump -U postgres nsready | gzip > backup_$(date +%Y%m%d).sql.gz

# Restore
gunzip -c backup_20241111.sql.gz | \
  kubectl exec -i -n nsready-tier2 nsready-db-0 -- psql -U postgres nsready
```

### S3 Backup Configuration

Update `deploy/k8s/backup-cronjob.yaml`:

```yaml
env:
- name: S3_BUCKET
  value: "your-backup-bucket"
- name: AWS_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      name: aws-credentials
      key: access-key-id
```

## Security Hardening

### TLS/HTTPS

1. Install cert-manager:
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

2. Create ClusterIssuer:
```bash
kubectl apply -f deploy/k8s/cert-manager-issuer.yaml
```

3. Update email in issuer configuration

### Network Policies

Apply network policies for service isolation:

```bash
kubectl apply -f deploy/k8s/network-policies.yaml
```

### RBAC

Service accounts and roles are configured in `deploy/k8s/rbac.yaml`.

## Scaling

### Horizontal Pod Autoscaling

HPA is configured for collector-service:

```bash
# Check HPA status
kubectl get hpa -n nsready-tier2

# View scaling events
kubectl describe hpa collector-service-hpa -n nsready-tier2
```

### Manual Scaling

```bash
# Scale collector service
kubectl scale deployment collector-service --replicas=5 -n nsready-tier2

# Scale admin tool
kubectl scale deployment admin-tool --replicas=3 -n nsready-tier2
```

### NATS JetStream Cluster

For high availability, configure NATS cluster:

```yaml
nats:
  jetstream:
    replicas: 3  # For production cluster
```

## Maintenance

### Rolling Updates

```bash
# Update image
kubectl set image deployment/collector-service \
  collector-service=ghcr.io/your-org/nsready-collector-service:v1.1.0 \
  -n nsready-tier2

# Monitor rollout
kubectl rollout status deployment/collector-service -n nsready-tier2
```

### Rollback

```bash
# Rollback to previous version
kubectl rollout undo deployment/collector-service -n nsready-tier2

# Rollback to specific revision
kubectl rollout undo deployment/collector-service --to-revision=2 -n nsready-tier2
```

### Health Checks

```bash
# Check pod status
kubectl get pods -n nsready-tier2

# Check service endpoints
kubectl get endpoints -n nsready-tier2

# View logs
kubectl logs -f deployment/collector-service -n nsready-tier2
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod events
kubectl describe pod <pod-name> -n nsready-tier2

# Check logs
kubectl logs <pod-name> -n nsready-tier2

# Check resource constraints
kubectl top pods -n nsready-tier2
```

### Database Connection Issues

```bash
# Test database connectivity
kubectl exec -it nsready-db-0 -n nsready-tier2 -- \
  psql -U postgres -d nsready -c "SELECT 1;"

# Check database logs
kubectl logs nsready-db-0 -n nsready-tier2
```

### NATS Connection Issues

```bash
# Check NATS status
kubectl exec -it nsready-nats-0 -n nsready-tier2 -- \
  nats server info

# Check JetStream streams
kubectl exec -it nsready-nats-0 -n nsready-tier2 -- \
  nats stream ls
```

### Ingress Issues

```bash
# Check ingress status
kubectl get ingress -n nsready-tier2

# Check ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

## CI/CD Integration

### GitHub Actions

The workflow (`.github/workflows/build-test-deploy.yml`) automatically:
1. Runs tests on PR
2. Builds and pushes images on push to main
3. Deploys to cluster on main branch

### Required Secrets

Configure in GitHub repository settings:
- `KUBECONFIG` - Base64 encoded kubeconfig
- `POSTGRES_PASSWORD` - Database password
- `JWT_SECRET` - JWT signing secret
- `NATS_TOKEN` - NATS authentication token

## Production Checklist

- [ ] Update all default passwords
- [ ] Configure managed database service
- [ ] Set up S3 backup bucket
- [ ] Configure Slack/email alerts
- [ ] Update domain names in ingress
- [ ] Enable network policies
- [ ] Configure resource limits
- [ ] Set up monitoring dashboards
- [ ] Test backup/restore procedures
- [ ] Configure autoscaling thresholds
- [ ] Review security contexts
- [ ] Set up log aggregation
- [ ] Configure disaster recovery plan

## Support

For issues or questions:
- Check logs: `kubectl logs -n nsready-tier2`
- Review metrics: Prometheus dashboard
- Check alerts: Alertmanager dashboard

## Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [NATS Documentation](https://docs.nats.io/)


