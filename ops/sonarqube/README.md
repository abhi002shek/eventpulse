# EventPulse SonarQube Community Build

This package prepares a temporary, self-hosted SonarQube Community Build instance for EventPulse portfolio demonstrations. It does not provision AWS resources, register a GitHub runner, or create a GitHub Actions workflow.

## Recommended EC2 Instance

- Ubuntu 24.04 or 26.04 LTS x86_64
- 2 vCPU
- 8 GB RAM
- 30 GB gp3 EBS

Do not allocate an Elastic IP initially. The future GitHub self-hosted runner will use outbound HTTPS and does not require a stable inbound public address. If the instance is stopped and started, the auto-assigned public IP may change.

## Security Group

Inbound rules:

- TCP 22 from the administrator's current `/32` public IP only
- No inbound TCP 9000
- No inbound TCP 5432

Outbound HTTPS must be available for Ubuntu packages, Docker images, GitHub, and future scanner downloads.

## Installation

Clone or copy this repository to the EC2 host, then run:

```bash
cd /path/to/eventpulse/ops/sonarqube
sudo ./setup-host.sh --docker-user ubuntu
```

Only pass `--docker-user` for an existing dedicated operator user. Docker group membership is root-equivalent host access.

Create the server-side environment file:

```bash
cp .env.sonar.example .env.sonar
chmod 600 .env.sonar
```

Generate a long local database password:

```bash
openssl rand -base64 32
```

Put the generated value in `.env.sonar`. Do not commit `.env.sonar`, paste it into logs, or store it in shell history where avoidable.

Validate and start the stack:

```bash
./validate.sh
```

## SSH Tunnel And Browser Access

SonarQube binds only to localhost on the EC2 host. Open a tunnel from your workstation:

```bash
ssh -L 9000:127.0.0.1:9000 ubuntu@EC2_PUBLIC_IP
```

Open:

```text
http://127.0.0.1:9000
```

## Initial SonarQube Setup

Sign in with SonarQube's documented initial administrator credentials, then immediately change the administrator password.

Create:

- EventPulse project
- Project-scoped analysis token

Do not paste the analysis token into files or terminal history where avoidable. The token belongs later in the GitHub repository secret named `SONAR_TOKEN`.

## Operations

Start:

```bash
docker compose --env-file .env.sonar -f compose.yaml up -d
```

Stop:

```bash
docker compose --env-file .env.sonar -f compose.yaml stop
```

Restart:

```bash
docker compose --env-file .env.sonar -f compose.yaml restart
```

Status:

```bash
docker compose --env-file .env.sonar -f compose.yaml ps
```

Logs:

```bash
docker compose --env-file .env.sonar -f compose.yaml logs sonarqube
docker compose --env-file .env.sonar -f compose.yaml logs sonar-db
```

Disk inspection:

```bash
df -h
docker system df
docker volume ls
```

Graceful shutdown before stopping the EC2 instance:

```bash
docker compose --env-file .env.sonar -f compose.yaml stop
sudo shutdown -h now
```

## Volume Warning

`docker compose down` removes containers and networks but keeps named volumes.

`docker compose down -v` permanently deletes SonarQube and PostgreSQL data for this stack.

`docker volume prune` and broad Docker cleanup commands may also destroy important data. Use them only after confirming the named volumes are no longer needed.

## EC2 Stop And Start Behavior

- Compute billing stops while the instance is stopped.
- EBS storage remains allocated and continues to incur storage charges.
- Auto-assigned public IP addresses may change after stop/start.
- Recheck your current public IP and update the SSH security-group source before reconnecting.

## Backup

Use PostgreSQL logical backup as the primary database backup:

```bash
docker compose --env-file .env.sonar -f compose.yaml exec -T sonar-db \
  sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' > sonarqube.backup.sql
```

An EBS snapshot can be useful as an infrastructure-level backup, but do not call an untested snapshot alone a complete database backup. Test restore procedures before relying on them.

## Cleanup

When the later self-hosted runner phase exists, remove the GitHub runner from GitHub before terminating the instance.

Then:

```bash
docker compose --env-file .env.sonar -f compose.yaml down
```

If intentionally deleting all SonarQube data:

```bash
docker compose --env-file .env.sonar -f compose.yaml down -v
```

Finally delete:

- EC2 instance
- unattached EBS volumes
- unwanted EBS snapshots
- security group
- future GitHub secrets such as `SONAR_TOKEN`
