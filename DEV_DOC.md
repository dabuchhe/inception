# Developer documentation

This document explains how to set the project up from scratch, build and run
it, manage its containers and volumes, and where its data lives. For day to
day use of the running site, see [USER_DOC.md](USER_DOC.md).

## Set up the environment from scratch

### Prerequisites

- A Linux virtual machine
- Docker Engine and the Docker Compose plugin (`docker compose version` must work)
- `make`
- `sudo` rights (used to edit `/etc/hosts` and by `make fclean`)
- Port 443 free on the host

The login `dabuchhe` appears in four places. All of them must be changed to
run the project under another login:

| File                                  | What                                        |
|---------------------------------------|---------------------------------------------|
| `Makefile`                            | `DATA_DIR = /home/dabuchhe/data`            |
| `srcs/docker-compose.yml`             | `device:` of the two volumes                |
| `srcs/requirements/nginx/Dockerfile`  | `CN=dabuchhe.42.fr` in the certificate      |
| `srcs/requirements/nginx/conf/nginx.conf` | `server_name dabuchhe.42.fr`            |

### Domain name

```sh
echo "127.0.0.1 dabuchhe.42.fr" | sudo tee -a /etc/hosts
```

### Configuration file: `srcs/.env`

This file is ignored by git and must be created by hand. It holds
non-sensitive configuration only, never a password. It is loaded into the
`mariadb` and `wordpress` containers through `env_file`.

```sh
DOMAIN_NAME=dabuchhe.42.fr

# MariaDB
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser

# WordPress
WP_TITLE=Inception
WP_ADMIN_USER=<login of the administrator>
WP_ADMIN_EMAIL=<e-mail of the administrator>
WP_USER=<login of the second user>
WP_USER_EMAIL=<e-mail of the second user>
```

| Variable         | Used by               | Purpose                                      |
|------------------|-----------------------|----------------------------------------------|
| `DOMAIN_NAME`    | `wordpress`           | Site URL given to `wp core install`          |
| `MYSQL_DATABASE` | `mariadb`, `wordpress`| Name of the database                         |
| `MYSQL_USER`     | `mariadb`, `wordpress`| Database user owned by WordPress             |
| `WP_TITLE`       | `wordpress`           | Title of the site                            |
| `WP_ADMIN_USER`  | `wordpress`           | Administrator login                          |
| `WP_ADMIN_EMAIL` | `wordpress`           | Administrator e-mail                         |
| `WP_USER`        | `wordpress`           | Login of the second user (role `author`)     |
| `WP_USER_EMAIL`  | `wordpress`           | E-mail of the second user                    |

All eight variables are required. The entrypoints run with `set -u`, so a
missing variable stops the container with an explicit error.

`WP_ADMIN_USER` must not contain `admin` or `administrator`, in any case
(subject rule). The two e-mail addresses must be different, because WordPress
refuses two accounts with the same address.

### Secrets: `secrets/`

This directory is ignored by git, at the root of the repository. `make`
creates the four files empty when they are missing, then stops until each one
is filled. Each file contains one password and nothing else.

| File                            | Secret name         | Mounted in             |
|---------------------------------|---------------------|------------------------|
| `secrets/db_user_password.txt`       | `db_user_password`       | `mariadb`, `wordpress` |
| `secrets/db_root_password.txt`  | `db_root_password`  | `mariadb`              |
| `secrets/wp_admin_password.txt` | `wp_admin_password` | `wordpress`            |
| `secrets/wp_user_password.txt`  | `wp_user_password`  | `wordpress`            |

```sh
mkdir -p secrets
for s in db_user_password db_root_password wp_admin_password wp_user_password; do
    openssl rand -hex 16 > "secrets/$s.txt"
done
chmod 600 secrets/*.txt
```

Inside a container, a secret is the read-only file `/run/secrets/<secret name>`.
The entrypoints read it with `$(cat /run/secrets/...)`.

The two database passwords are inserted into SQL statements between single
quotes, so they must not contain a single quote or a backslash.

## Build and launch

### With the Makefile

| Target        | Runs                                                              |
|---------------|-------------------------------------------------------------------|
| `make` / `make up` | `mkdir -p` of the two data directories, then `docker compose up -d --build` |
| `make down`   | `docker compose down`                                             |
| `make ps`     | `docker compose ps`                                               |
| `make logs`   | `docker compose logs -f`                                          |
| `make clean`  | `docker compose down --rmi all -v`                                |
| `make fclean` | `clean`, then `sudo rm -rf /home/dabuchhe/data`                   |
| `make re`     | `fclean`, then `all`                                              |

The data directories must exist before the volumes are mounted, otherwise the
containers fail to start. This is why `make up` creates them and why the
stack should be started with `make` rather than with a bare
`docker compose up`.

### With Docker Compose directly

The compose file is not at the root, so it must be given with `-f`:

```sh
docker compose -f srcs/docker-compose.yml build nginx          # rebuild one image
docker compose -f srcs/docker-compose.yml up -d --build nginx  # rebuild and restart one service
docker compose -f srcs/docker-compose.yml restart wordpress
docker compose -f srcs/docker-compose.yml logs -f mariadb
docker compose -f srcs/docker-compose.yml config               # print the resolved configuration
```

The Compose project is named `srcs`, after the directory of the compose file.
Docker objects are therefore named `srcs_inception` (network),
`srcs_mariadb_data` and `srcs_wordpress_data` (volumes). Containers have fixed
names: `mariadb`, `wordpress`, `nginx`. Images are `mariadb:inception`,
`wordpress:inception` and `nginx:inception`.

### What happens at startup

1. `mariadb` starts. On the first start, its entrypoint creates the system
   tables, then runs `mariadbd --bootstrap` to create the database, the
   WordPress user and the root password, and writes the marker file
   `/var/lib/mysql/.initialized`. It then execs `mariadbd`.
2. Compose waits for the `mariadb` health check (`mariadb-admin ping`, every
   5 seconds, up to 10 tries).
3. `wordpress` starts. Its entrypoint downloads WordPress if `wp-load.php` is
   missing, creates `wp-config.php` if it is missing, and installs the site
   and the two users if `wp core is-installed` fails. It then execs
   `php-fpm8.2 -F`, which listens on port 9000.
4. `nginx` starts and listens on 443.

Every step is skipped when its result already exists, so restarting never
resets the site. To replay the initialisation, the data must be deleted
(`make re`).

## Manage the containers and volumes

### Containers

```sh
make ps                                   # state and health
docker exec -it wordpress sh              # shell in a container
docker logs -f nginx                      # logs of one container
docker inspect mariadb                    # full configuration
docker top nginx                          # processes; the service must be PID 1
docker network inspect srcs_inception     # containers attached to the network
```

Checks that are useful during an evaluation:

```sh
# TLS: 1.2 and 1.3 are accepted, 1.1 is refused
openssl s_client -connect dabuchhe.42.fr:443 -tls1_2 </dev/null
openssl s_client -connect dabuchhe.42.fr:443 -tls1_3 </dev/null
openssl s_client -connect dabuchhe.42.fr:443 -tls1_1 </dev/null

# only port 443 is published
docker ps --format '{{.Names}}\t{{.Ports}}'

# WordPress users and their roles
docker exec wordpress wp user list --allow-root

# database content
docker exec -it mariadb mariadb -u root -p
#   SHOW DATABASES;  USE <MYSQL_DATABASE>;  SHOW TABLES;  SELECT user_login FROM wp_users;
```

The root password asked by the last command is in
`secrets/db_root_password.txt`.

### Volumes

```sh
docker volume ls
docker volume inspect srcs_wordpress_data   # shows the device /home/dabuchhe/data/wordpress
docker volume inspect srcs_mariadb_data
```

### Changing a database password without losing data

The secret files are read only during the first initialisation. To change the
password of the WordPress database user on an existing site, change it in the
three places that hold it:

```sh
docker exec -it mariadb mariadb -u root -p \
    -e "ALTER USER '<MYSQL_USER>'@'%' IDENTIFIED BY '<new password>';"
docker exec wordpress wp config set DB_PASSWORD '<new password>' --allow-root
printf '%s' '<new password>' > secrets/db_user_password.txt
```

## Where the data is stored and how it persists

| Volume           | Mounted in                                         | Host directory                  | Content                          |
|------------------|----------------------------------------------------|---------------------------------|----------------------------------|
| `mariadb_data`   | `mariadb:/var/lib/mysql`                           | `/home/dabuchhe/data/mariadb`   | Database files                   |
| `wordpress_data` | `wordpress:/var/www/html`, `nginx:/var/www/html` (read-only) | `/home/dabuchhe/data/wordpress` | WordPress core, `wp-config.php`, themes, plugins, uploads |

Both are Docker named volumes, declared in the top-level `volumes:` section
of the compose file with the `local` driver and the options `type: none`,
`o: bind`, `device: <host directory>`. Docker manages them as volumes, and
their data is stored in the host directory given as `device`.

What each operation does to the data:

| Operation                       | Containers | Images  | Docker volumes | Files in `/home/dabuchhe/data` |
|---------------------------------|------------|---------|----------------|--------------------------------|
| Container crash or restart      | restarted  | kept    | kept           | kept                           |
| `make down`                     | removed    | kept    | kept           | kept                           |
| `make clean`                    | removed    | removed | removed        | **kept**                       |
| `make fclean`                   | removed    | removed | removed        | **deleted**                    |

`make clean` removes the Docker volume objects, but a volume of this kind
only points to the host directory, so the files remain. The next `make`
recreates the volumes on top of the same directories and the site comes back
unchanged. Only `make fclean` (or `make re`) gives a blank installation.

The files in `/home/dabuchhe/data` are owned by the users of the containers
(`mysql`, `www-data`), not by the host user. This is why `make fclean` uses
`sudo` to delete them.

The TLS certificate is not persistent data. It is generated when the NGINX
image is built and is replaced each time that image is rebuilt.
