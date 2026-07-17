# EventPulse Request Flow

## Successful API Request

1. A user sends an HTTP request to the temporary public ALB.
2. The ALB health checks `/health` and routes healthy traffic to EventPulse Pod IP targets.
3. Kubernetes Service labels select EventPulse Pods, and NetworkPolicies restrict allowed traffic.
4. FastAPI receives the request through middleware that records request count, latency and request ID metadata.
5. The route handler validates input using Pydantic models.
6. For database-backed requests, the application uses SQLAlchemy sessions.
7. Database credentials are provided through a Kubernetes Secret synced from AWS Secrets Manager by Secrets Store CSI.
8. EventPulse connects to private RDS PostgreSQL using TLS.
9. Booking creation locks the target Event row inside a transaction before checking and decrementing capacity.
10. The response returns only public identifiers and safe response fields.
11. Application logs are written to stdout.
12. Fluent Bit tails stdout logs and forwards EventPulse logs to CloudWatch Logs.
13. Prometheus scrapes `/metrics` from EventPulse.
14. Alert rules are evaluated by Prometheus and surfaced through Alertmanager/Grafana.

## Booking Transaction Flow

1. The user posts a booking request with an Event public UUID, customer name, customer email and quantity.
2. FastAPI validates the UUID, email and positive quantity.
3. The service layer opens one database transaction.
4. The repository loads the Event by public UUID and locks the row.
5. If the Event does not exist, the service raises a domain exception and the transaction rolls back.
6. If available capacity is insufficient, the service raises a domain exception and the transaction rolls back.
7. If capacity is available, the service creates a Booking and decrements Event availability.
8. SQLAlchemy commits both changes together.
9. The API response exposes Booking public UUID, Event public UUID, quantity, status and timestamp.
10. Customer email is not returned in the public response and must not be logged.

## Failure Paths

### Pod Unready

If an EventPulse Pod fails readiness, Kubernetes removes it from Service endpoints. The ALB target becomes unhealthy and traffic routes to remaining healthy Pods.

### RDS Unavailable

`/ready` returns a controlled unavailable response. `/health` remains process-only and does not check external dependencies. Database exceptions are not returned to clients.

### Unsigned Or Untrusted Image

Kyverno rejects workloads using unsigned EventPulse images, mutable tags or signatures from an untrusted GitHub workflow identity.

### Failing ALB Health Check

If `/health` fails, the ALB target is marked unhealthy. Traffic should not be routed to that Pod until the health check recovers.

### Secret Retrieval Failure

If Secrets Store CSI or Pod Identity cannot retrieve database credentials, the Pod cannot start or readiness fails. Operators inspect CSI events, Pod events and Secrets Manager permissions.

### Observability Regression

If the live image lacks `/metrics`, Prometheus marks the EventPulse target down. This happened during validation and was fixed by publishing and deploying a new signed image containing the metrics endpoint.
