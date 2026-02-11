# Operations Runbook

## Standard Compose Update
```bash
scripts/update_compose_stack.sh /srv/stacks/databases
scripts/update_compose_stack.sh /srv/stacks/platform
scripts/update_compose_stack.sh /srv/stacks/observability
scripts/update_compose_stack.sh /srv/stacks/nextcloud
```

## Jenkins Initial Admin Password
```bash
sudo cat /srv/data/platform/jenkins/secrets/initialAdminPassword
```

## n8n Uses Postgres Check
```bash
docker exec -it n8n env | grep '^DB_TYPE='
```

## Backup Preflight
```bash
scripts/backup_preflight.sh
```
