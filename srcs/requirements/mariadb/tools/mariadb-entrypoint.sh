#!/bin/sh

set -e

mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld
chown -R mysql:mysql /var/lib/mysql

if [ ! -d "/var/lib/mysql/mysql" ]; then

    echo "Initialisation de MariaDB..."

    mariadb-install-db \
        --user=mysql \
        --datadir=/var/lib/mysql

    echo "Démarrage temporaire de MariaDB..."

    mariadbd \
        --user=mysql \
        --datadir=/var/lib/mysql \
        --skip-networking &

    pid="$!"

    sleep 2

    echo "Configuration de la base..."

    mariadb <<EOF
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;

CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%'
IDENTIFIED BY '${MYSQL_PASSWORD}';

GRANT ALL PRIVILEGES
ON \`${MYSQL_DATABASE}\`.*
TO '${MYSQL_USER}'@'%';

ALTER USER 'root'@'localhost'
IDENTIFIED BY '$[MYSQL_ROOT_PASSWORD]';

FLUSH PRIVILEGES;
EOF

    echo "Arrêt du serveur temporaire..."

    mariadb-admin shutdown

    wait "$pid"
fi

echo "Démarrage final de MariaDB..."

exec mariadbd \
    --user=mysql \
    --datadir=/var/lib/mysql \
    --bind-address=0.0.0.0