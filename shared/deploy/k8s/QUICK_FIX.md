# Quick Fix Guide for Deployment Issues

## Issue 1: Image Pull Errors

The deployments are trying to pull images from `ghcr.io/your-org/...` which doesn't exist.

### Option A: Use Local Images (Docker Desktop / Kind)

If you're using Docker Desktop or Kind, you can use local images:

```bash
# Build images locally
docker build -t nsready-admin-tool:latest ./admin_tool
docker build -t nsready-collector-service:latest ./collector_service

# Update deployments to use local images
kubectl set image deployment/admin-tool admin-tool=nsready-admin-tool:latest -n nsready-tier2
kubectl set image deployment/collector-service collector-service=nsready-collector-service:latest -n nsready-tier2

# Or update the YAML files directly
sed -i '' 's|ghcr.io/your-org/nsready-admin-tool:latest|nsready-admin-tool:latest|g' deploy/k8s/admin_tool-deployment.yaml
sed -i '' 's|ghcr.io/your-org/nsready-collector-service:latest|nsready-collector-service:latest|g' deploy/k8s/collector_service-deployment.yaml

# Reapply
kubectl apply -f deploy/k8s/admin_tool-deployment.yaml
kubectl apply -f deploy/k8s/collector_service-deployment.yaml
```

### Option B: Update Image Registry

Update the image references in the deployment files:

```bash
# Edit admin_tool-deployment.yaml
# Change: image: ghcr.io/your-org/nsready-admin-tool:latest
# To: image: your-registry/nsready-admin-tool:latest

# Edit collector_service-deployment.yaml  
# Change: image: ghcr.io/your-org/nsready-collector-service:latest
# To: image: your-registry/nsready-collector-service:latest

# Then reapply
kubectl apply -f deploy/k8s/admin_tool-deployment.yaml
kubectl apply -f deploy/k8s/collector_service-deployment.yaml
```

## Issue 2: PVC Pending

The PersistentVolumeClaims are pending because the storage class "standard" may not exist.

### Check Available Storage Classes

```bash
kubectl get storageclass
```

### Option A: Create Standard Storage Class (if missing)

```bash
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
provisioner: docker.io/hostpath
volumeBindingMode: WaitForFirstConsumer
EOF
```

### Option B: Update PVCs to Use Existing Storage Class

Find your storage class:
```bash
kubectl get storageclass
```

Then update the PVCs:
```bash
# Edit postgres-statefulset.yaml and nats-statefulset.yaml
# Change: storageClassName: standard
# To: storageClassName: <your-storage-class-name>

# Or use hostPath for local testing
kubectl patch pvc postgres-pvc -n nsready-tier2 -p '{"spec":{"storageClassName":"hostpath"}}'
kubectl patch pvc nats-pvc -n nsready-tier2 -p '{"spec":{"storageClassName":"hostpath"}}'
```

### Option C: Use EmptyDir for Testing (No Persistence)

For local testing, you can temporarily use emptyDir instead of PVCs.

## Quick Status Check

After fixes, check status:

```bash
# Check pods
kubectl get pods -n nsready-tier2

# Check PVCs
kubectl get pvc -n nsready-tier2

# Check events
kubectl get events -n nsready-tier2 --sort-by='.lastTimestamp'
```

## Complete Fix Script (Docker Desktop)

```bash
#!/bin/bash
# Quick fix for local Docker Desktop deployment

# 1. Build local images
docker build -t nsready-admin-tool:latest ./admin_tool
docker build -t nsready-collector-service:latest ./collector_service

# 2. Update image references
kubectl set image deployment/admin-tool admin-tool=nsready-admin-tool:latest -n nsready-tier2
kubectl set image deployment/collector-service collector-service=nsready-collector-service:latest -n nsready-tier2

# 3. Create storage class if needed
kubectl get storageclass standard || kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
provisioner: docker.io/hostpath
volumeBindingMode: WaitForFirstConsumer
EOF

# 4. Wait for pods
kubectl wait --for=condition=ready pod -l app=admin-tool -n nsready-tier2 --timeout=300s
kubectl wait --for=condition=ready pod -l app=collector-service -n nsready-tier2 --timeout=300s

# 5. Check status
kubectl get all -n nsready-tier2
```


