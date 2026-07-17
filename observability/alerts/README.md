# EventPulse Alerts

EventPulse alert rules are rendered by the Helm chart when monitoring is enabled.

## Alert Summary

| Alert | Severity | Meaning | First action |
| --- | --- | --- | --- |
| `EventPulseDeploymentUnavailable` | critical | No API replicas are available. | Check Deployment, Pods and recent rollout events. |
| `EventPulseHigh5xxRate` | warning | More than 5% of recent API requests returned 5xx responses. | Check API logs, database readiness and recent changes. |
| `EventPulseHighLatency` | warning | API p95 latency is above 500 ms for 10 minutes. | Check database latency, Pod CPU and memory pressure. |
| `EventPulsePodRestarting` | warning | At least one API container restarted recently. | Inspect the affected Pod's previous logs and termination reason. |
| `EventPulseDatabaseReadinessFailure` | warning | Database readiness checks have failed. | Confirm RDS availability, Secrets Store sync and network policy egress. |

## SLO Starting Point

Initial learning SLOs are intentionally modest and must be refined from measured traffic:

- Availability: 99% monthly success for public health/readiness-backed API traffic.
- Latency: 95% of API requests under 500 ms.
- Error rate: 5xx responses below 5% over a 10-minute window.

These are starting targets, not measured production guarantees.
