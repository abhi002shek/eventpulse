# Local Kubernetes Deployment Runbook

This runbook deploys EventPulse to a local Kind cluster using Helm.

It does not create AWS or GCP resources.

## Prerequisites

Install these tools before running the scripts:

- Docker
- Kind
- kubectl
- Helm
- Python 3.12 and the project virtual environment for application checks

Optional:

- kubeconform for rendered manifest validation

## Image

The chart deploys the already verified immutable image:

```text
ghcr.io/abhi002shek/eventpulse@sha256:76571b0ad6961c7ea7c72d9c3dc81b6014e22be2ceefb26a7157ea607b80e224
```

Do not deploy `latest`, `v0.1.0` alone, the SHA tag alone or `eventpulse-api:local`.

If GHCR requires authentication on your machine, create the least-privilege pull secret manually and configure the chart in a later change. Do not make the package public or store credentials in this repository without an explicit task.

## Create The Cluster

```bash
ops/kind/create-cluster.sh
```

The script creates:

- Kind cluster `eventpulse-local`
- namespace `eventpulse`

It reports the current Kubernetes context. It does not install metrics-server.

## Deploy

Use an environment variable for the local database password:

```bash
export EVENTPULSE_DB_PASSWORD="$(openssl rand -base64 32)"
ops/kind/deploy.sh
```

If `EVENTPULSE_DB_PASSWORD` is missing, the script uses an obvious local-only fake password and prints a warning. It does not print the password.

The deploy script:

- creates or updates a Kubernetes Secret named `eventpulse-database`
- runs `helm upgrade --install`
- waits for migration and seed Jobs
- waits for the API Deployment rollout

## Validate

```bash
ops/kind/validate.sh
```

The validation script checks:

- cluster connectivity
- `helm lint`
- `helm template`
- values schema rejection for an empty image digest
- rendered manifests with kubeconform when available
- Pods and Jobs
- Deployment rollout
- Service endpoints
- temporary port-forward
- `/health`
- `/ready`
- `/api/v1/events`
- non-root container UID
- privileged mode is false
- service-account token automount is disabled
- immutable image digest is used
- resource requests and limits exist
- NetworkPolicies exist
- HPA and PDB exist
- Helm test Pods can resolve and call the API service

## Manual Port Forward

```bash
kubectl -n eventpulse port-forward svc/eventpulse 8000:8000
```

Then:

```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/ready
curl http://127.0.0.1:8000/api/v1/events
```

## Logs

API logs:

```bash
kubectl -n eventpulse logs deploy/eventpulse
```

PostgreSQL logs:

```bash
kubectl -n eventpulse logs deploy/eventpulse-postgres
```

Job status:

```bash
kubectl -n eventpulse get jobs
kubectl -n eventpulse describe job eventpulse-migration
```

Migration and seed Jobs are Helm hooks and are kept after success for local inspection. The next Helm deployment deletes the previous hook Job before creating a fresh one.

## Troubleshooting

Check Pods:

```bash
kubectl -n eventpulse get pods -o wide
kubectl -n eventpulse describe pod POD_NAME
```

Check Service endpoints:

```bash
kubectl -n eventpulse get endpoints eventpulse
```

Check NetworkPolicies:

```bash
kubectl -n eventpulse get networkpolicy
```

Run Helm tests manually:

```bash
helm test eventpulse --namespace eventpulse --logs
kubectl -n eventpulse delete pod -l app.kubernetes.io/component=test --ignore-not-found
```

If the API image cannot be pulled, confirm GHCR visibility or configure a least-privilege `imagePullSecret`. Do not commit registry tokens.

If HPA metrics are unavailable, that is expected until metrics-server is installed from a pinned trusted source in a later task.

## Cleanup

Delete only the EventPulse Kind cluster:

```bash
ops/kind/destroy.sh
```

This deletes the Kind cluster and the local PostgreSQL data stored inside it.

## Known Local Limitations

- Local PostgreSQL is temporary and will be replaced by RDS in the AWS phase.
- Kind is single-node by default, so topology spread is configured with `ScheduleAnyway`.
- HPA exists, but CPU scaling is not validated unless metrics-server is installed.
- No Ingress, public TLS or cloud load balancer is configured in this milestone.
