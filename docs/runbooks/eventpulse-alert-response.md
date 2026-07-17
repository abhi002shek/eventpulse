# EventPulse Alert Response

Use this runbook for the initial EventPulse Prometheus alerts.

## EventPulseDeploymentUnavailable

Meaning: no EventPulse API replicas are available.

Commands:

```bash
kubectl -n eventpulse get deployment,pods,events
kubectl -n eventpulse describe deployment eventpulse
kubectl -n eventpulse logs deployment/eventpulse --tail=100
```

Check recent Helm changes, image pull errors, database Secret sync and Kyverno admission events.

## EventPulseHigh5xxRate

Meaning: the API is returning too many 5xx responses.

Commands:

```bash
kubectl -n eventpulse logs deployment/eventpulse --tail=200
kubectl -n eventpulse get pods
curl -i http://<ALB_DNS>/ready
```

Check RDS state, Secrets Store CSI sync and EventPulse exception logs. Do not paste customer emails or request bodies into incident notes.

## EventPulseHighLatency

Meaning: p95 API latency is above the initial 500 ms target.

Commands:

```bash
kubectl -n eventpulse top pods
kubectl -n eventpulse describe hpa eventpulse
kubectl -n monitoring port-forward service/eventpulse-observability-grafana 3000:80
```

Check CPU throttling, memory pressure and database readiness latency.

## EventPulsePodRestarting

Meaning: at least one API container restarted recently.

Commands:

```bash
kubectl -n eventpulse get pods
kubectl -n eventpulse describe pod <POD_NAME>
kubectl -n eventpulse logs <POD_NAME> --previous
```

Look for OOMKilled, failed probes, image pull errors or application startup exceptions.

## EventPulseDatabaseReadinessFailure

Meaning: EventPulse readiness checks cannot reach PostgreSQL.

Commands:

```bash
kubectl -n eventpulse get pods
kubectl -n eventpulse describe pod -l app.kubernetes.io/component=api
aws rds describe-db-instances --db-instance-identifier eventpulse-dev-postgres
```

Check RDS availability, network policy egress, security groups and the Secrets Store CSI synced Secret.
