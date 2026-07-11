# infra/k8s/base — Alaveteli stack base manifests

Plain Kubernetes manifests for the Alaveteli stack, deployed to the `handlingar`
namespace. Same backing-service versions as `docker-compose.yml` for dev↔K8s parity.

| Manifest | What | Status |
| --- | --- | --- |
| `namespace.yaml` | `handlingar` namespace | live |
| `configmap.yaml` | non-secret app config | live |
| `postgres.yaml` | PostgreSQL 14, StatefulSet + 10Gi CSI PVC | live |
| `redis.yaml` | Redis 7 (Sidekiq), ephemeral | live |
| `memcached.yaml` | memcached 1.6 (cache) | live |
| `alaveteli.yaml` | web + Sidekiq Deployments + Service | **placeholder, replicas: 0** |

The app Deployments are wired but scaled to 0 because the Alaveteli container
image is a **Phase 1** deliverable and does not exist yet. Bringing the app
online later is: build the image → set `image:` in `alaveteli.yaml` → scale up.

## Secret (not committed)

Secrets are kept out of git (Phase 3 will manage them with SOPS). Create the dev
secret once, out-of-band, before applying:

```bash
export KUBECONFIG=~/.kube/handlingar-dev.yaml
kubectl create namespace handlingar --dry-run=client -o yaml | kubectl apply -f -
kubectl -n handlingar create secret generic alaveteli-secrets \
  --from-literal=db-password='<choose-a-dev-password>'
```

## Apply

```bash
export PATH="$HOME/.local/bin:$PATH"
export KUBECONFIG=~/.kube/handlingar-dev.yaml
kubectl apply -f infra/k8s/base/        # idempotent; applies all manifests
kubectl -n handlingar get pods
```

Backing services (postgres, redis, memcached) come up immediately. The app pods
stay at 0 replicas until the Phase 1 image is set.

## Teardown

```bash
kubectl delete -f infra/k8s/base/        # or: kubectl delete namespace handlingar
```

Deleting the namespace also deletes the postgres PVC and its Hetzner volume.
