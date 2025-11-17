Docker

Container lifecycle (what's running? why is it failing?)

```bash
docker ps
docker ps -a
docker logs <name-or-id> --tail 200
docker logs <name-or-id> --since 5m -f
docker inspect <name-or-id> | jq '.[0].State, .[0].Config, .[0].HostConfig.RestartPolicy'
```

Common failure: "Conflict. The container name is already in use"

```bash
docker ps -a --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}'
docker rm <old-id-or-name>     # remove stopped container with same name
```

Start/stop/remove

```bash
docker start <name>
docker stop <name>
docker rm <name>
```

Exec and environment (shell inside, env, files)

```bash
docker exec -it <name> sh
docker exec -it <name> bash
docker exec -it <name> env | sort
docker exec -it <name> ls -al /
```

Ports and reachability (host ↔ container)

List port mappings

```bash
docker ps --format 'table {{.ID}}\t{{.Names}}\t{{.Ports}}'
```

Test from host

```bash
nc -vz 127.0.0.1 <host_port>
curl -sS -m 3 http://127.0.0.1:<host_port>/healthz
```

Test from inside container

```bash
docker exec -it <name> sh -lc 'nc -vz <host> <port>'
docker exec -it <name> sh -lc 'curl -sS -m 3 http://<host>:<port>/healthz'
```

On macOS: access host from container

```bash
docker exec -it <name> sh -lc 'ping -c1 host.docker.internal || true'
```

Networking (networks, DNS, service discovery)

```bash
docker network ls
docker network inspect <network>
docker exec -it <name> cat /etc/resolv.conf
```

Two containers can talk only if:
- They share a Docker network (both listed in `docker network inspect <net>`)
- Use the container "service name" (Compose service name) as host
- No need to expose ports for container-to-container on the same network; use the internal container port

Recreate a broken network

```bash
docker network rm <network>; docker network create <network>
```

Volumes and data

```bash
docker volume ls
docker volume inspect <volume>
docker inspect <name> | jq '.[0].Mounts'
```

Copy files in/out

```bash
docker cp <name>:/path/in/container ./local/
docker cp ./local/file <name>:/path/in/container
```

Resource limits and health

```bash
docker inspect <name> | jq '.[0].HostConfig | {NanoCpus,Memory,MemorySwap}'
docker stats --no-stream
```

Healthcheck status (if defined)

```bash
docker inspect <name> | jq '.[0].State.Health'
```

Docker Compose (project-level)

```bash
docker compose ps
docker compose logs --tail 200 -f
docker compose up -d
docker compose down
docker compose exec <service> sh
```

Troubleshooting order:
- `docker compose ps` → see status
- `docker compose logs <service>` → errors
- `docker ps --format '{{.Names}} {{.Ports}}'` → ports
- `docker inspect <service>` → env, health, mounts

Name conflicts and cleanup

Name already in use

```bash
docker ps -a --filter "name=<name>" --format '{{.ID}} {{.Status}}'
docker rm <id>    # remove stopped container
```

Prune stopped containers and unused networks (careful)

```bash
docker container prune -f
docker network prune -f
docker volume prune -f     # only if you want to delete unused volumes
```

DB connectivity inside containers (TigerData/Postgres)

From app container to DB service (same network):

```bash
docker exec -it <app> sh -lc 'nc -vz tigerdata 5432'
docker exec -it <app> sh -lc '\''psql "host=tigerdata port=5432 user=<u> dbname=<db> sslmode=require" -c "SELECT 1;"'\'''
```

From host to DB in container:

```bash
nc -vz 127.0.0.1 5432
psql "host=127.0.0.1 port=5432 user=<u> dbname=<db> sslmode=require" -c 'SELECT 1;'
```

Quick incident playbook

- Container won't start
  - `docker logs <name>` → error?
  - Name conflict? `docker ps -a | grep <name>` → `docker rm <id>` then start
  - Wrong env/command? `docker inspect <name> | jq '.[0].Config'`
- Service unreachable from host
  - Ports mapped? `docker ps --format '{{.Names}} {{.Ports}}'`
  - Host firewall/VPN? Try `nc -vz 127.0.0.1 <host_port>`
- Containers can't talk
  - Same network? `docker network inspect <net>`
  - Resolve name? `docker exec <a> getent hosts <b> || nslookup <b>` (alpine: `nslookup`)
  - Using service name and internal port (not host port)
- Data not persisted
  - Check mounts: `docker inspect <name> | jq '.[0].Mounts'`
  - Verify volume path contents

