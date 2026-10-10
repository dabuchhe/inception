#!/bin/sh

# -e : stop at first error encounter / -u : error if a var is not defined
set -eu

DATADIR=/var/lib/mysql

# The volume comes from the host: make sure mysql owns it
chown -R mysql:mysql "$DATADIR"

# Initialisation: only at first start
if [ ! -f "$DATADIR/.initialized" ]; then

    DB_PASSWORD=$(cat /run/secrets/db_password)
    DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)

    # Create system tables if the volume is empty
    if [ ! -d "$DATADIR/mysql" ]; then
        mariadb-install-db --user=mysql --datadir="$DATADIR" --skip-test-db
    fi

    # --bootstrap: run the SQL below then exit (no network, no background server)
    mariadbd --user=mysql --bootstrap <<EOF
FLUSH PRIVILEGES;
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF

    # if success, marked as initialized
    touch "$DATADIR/.initialized"
fi

# exec: mariadb replace shell and is now PID 1
exec mariadbd --user=mysql --bind-address=0.0.0.0

healthcheck:
  test:["CMD", "mariadb-admin", "ping", "-h", "127.0.0.1", "--silent"]
  interval: 5s
  timeout: 3s
  retries: 10