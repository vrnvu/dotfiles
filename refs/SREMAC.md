SRE macOS

CPU and MEM

```bash
top -l 1 | head -n 20
top -o cpu
top -o mem
ps aux
ps -o pid,ppid,cmd,%cpu,%mem -p <pid>
vm_stat 1
```

Services and logs (launchd)

```bash
launchctl list | grep -i <name>
log stream --predicate 'process == "<name>"' --style syslog
log show --predicate 'process == "<name>"' --last 1h
```

DNS

```bash
scutil --dns
dig <host>
dig +trace <host>
host <host>
```

Network and ports

```bash
sudo lsof -nP -iTCP -sTCP:LISTEN
netstat -anv | awk '/^tcp/ {print $6}' | sort | uniq -c | sort -nr
netstat -anv | grep '\.5432 ' | wc -l
nc -vz <host> 5432
curl -sS -m 3 -w "code=%{http_code} time=%{time_total}\n" http://<host>:<port>/healthz -o /dev/null
traceroute <host>
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
iostat -w 1
sudo fs_usage
```

Limits and FDs

```bash
ulimit -n
sysctl kern.maxfiles kern.maxfilesperproc
launchctl limit maxfiles
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
docker exec -it <id> sh -lc 'cat /etc/resolv.conf'
ping host.docker.internal
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
netstat -anv | awk '/^tcp/ {print $6}' | sort | uniq -c | sort -nr
```

