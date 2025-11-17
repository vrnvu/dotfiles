SRE Linux

CPU and MEM

```bash
top
top -H
ps aux
ps -o pid,ppid,cmd,%cpu,%mem -p <pid>
```

Systemd and journal

```bash
systemctl status <service>
journalctl -u <service> -n 200 -f
systemctl --failed
systemctl is-enabled <service>
```

DNS

```bash
dig <host>
dig +trace <host>
getent hosts <host>
```

Network and ports

```bash
ss -ltnp
sudo lsof -nP -iTCP -sTCP:LISTEN
ss -tan | awk '{print $2}' | sort | uniq -c | sort -nr
nc -vz <host> 5432
```

PostgreSQL / TigerData

```bash
psql "host=<h> port=5432 user=<u> dbname=<db> sslmode=require" -c 'SELECT 1;'
psql ... -c "SELECT count(*) FROM pg_stat_activity;"
psql ... -c "SELECT pid, now()-xact_start AS age, state, query FROM pg_stat_activity ORDER BY age DESC LIMIT 10;"
psql ... -c "SHOW max_connections;"
openssl s_client -connect <dbhost>:5432 -servername <dbhost> -showcerts </dev/null
```

Disk and IO

```bash
df -h
iostat -xz 1
pidstat -d 1
```

Limits and FDs

```bash
ulimit -n
cat /proc/sys/fs/file-nr
```

TLS and time

```bash
date
openssl s_client -connect <host>:<port> -servername <host> -showcerts </dev/null
```

Containers (Docker)

```bash
docker ps
docker logs <id> --tail 200
docker ps --format 'table {{.ID}}\t{{.Names}}\t{{.Ports}}'
docker network ls
docker network inspect <network>
docker exec -it <id> sh -lc 'nc -vz <host> <port>'
getent hosts host.docker.internal
```

Troubleshooting

Is it up and running by name?

```bash
pgrep -fl <name>
```

Can host reach DB?

```bash
nc -vz <dbhost> 5432
psql ... -c 'SELECT 1;'
```

Port collision on host?

```bash
sudo lsof -nP -iTCP:<host_port> -sTCP:LISTEN
```

High TIME_WAIT/ESTABLISHED?

```bash
ss -tan | awk '{print $2}' | sort | uniq -c | sort -nr
```

