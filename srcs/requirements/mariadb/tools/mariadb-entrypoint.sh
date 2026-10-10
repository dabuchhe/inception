#!/bin/sh

# -e : stop at firt error encounter / -u : error if a var is not defined
set -eu

DATADIR=/var/lib/mysql

DB_PASSWORD=$(cat /run/secrets/db_password)
DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)

mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld
chown -R mysql:mysql "$DATADIR"

# Initialisation: only if not exist
if [ ! -f "$DATADIR/.initialized" ]; then

    echo "Initialisation de MariaDB..."

    # Create system table if volume don't exist
    if [ ! -d "$DATADIR/mysql" ]; then
        mariadb-install-db --user=mysql --datadir="$DATADIR"
    fi

    echo "Démarrage temporaire de MariaDB..."

    # Temporary server, access only by local socket
    mariadbd --user=mysql --datadir="$DATADIR" --skip-networking &
    pid="$!"

    # Wait for server respond (30 attempt max)
    i=0
    until mariadb-admin ping --silent; do
        i=$((i + 1))
        if [ "$i" -ge 30 ]; then
            echo "MariaDB ne démarre pas" >&2
            exit 1
        fi
        sleep 1
    done

    echo "Configuration de la base..."

    mariadb <<EOF
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF

    echo "Arrêt du serveur temporaire..."

    # root password
    mariadb-admin -uroot -p"${DB_ROOT_PASSWORD}" shutdown
    wait "$pid"

    # if success, marked at initialized
    touch "$DATADIR/.initialized"
fi

echo "Démarrage final de MariaDB..."

# exec: mariadb replace shell and is now PID 1
exec mariadbd --user=mysql --datadir="$DATADIR" --bind-address=0.0.0.0
