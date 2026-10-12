*This project has been created as part of the 42 curriculum by dabuchhe.*

# Inception

## Description

Inception is a system administration project. Its goal is to build a small web
infrastructure with Docker Compose, where every service runs in its own
container and every image is built from a hand-written Dockerfile instead of
being pulled ready-made from a registry.

The stack serves a WordPress website over HTTPS at `https://dabuchhe.42.fr`:

| Service     | Role                                              | Listens on              |
|-------------|---------------------------------------------------|-------------------------|
| `nginx`     | TLS termination, static files, entry point        | 443 (published on host) |
| `wordpress` | WordPress run by php-fpm, set up with WP-CLI      | 9000 (internal only)    |
| `mariadb`   | Database of the WordPress site                    | 3306 (internal only)    |

```
            host :443
                |
           +---------+    :9000    +-----------+    :3306    +---------+
           |  nginx  | ----------> | wordpress | ----------> | mariadb |
           +---------+             +-----------+             +---------+
                |                        |                        |
                +------ wordpress_data --+                  mariadb_data
                    /home/dabuchhe/data/wordpress     /home/dabuchhe/data/mariadb
```

Two more documents complete this file:

- [USER_DOC.md](USER_DOC.md): how to use and administer the running stack.
- [DEV_DOC.md](DEV_DOC.md): how to set the project up from scratch and work on it.

## Project description

### Use of Docker

Each service is described by a Dockerfile in `srcs/requirements/<service>/`.
`srcs/docker-compose.yml` builds the three images, creates the network, the
volumes and the secrets, and starts the containers in dependency order. The
`Makefile` at the root of the repository is the single entry point: it creates
the data directories on the host and drives Docker Compose.

### Sources included in the project

```
Makefile                          build, start, stop and clean the stack
secrets/                          password files (ignored by git)
srcs/.env                         non-sensitive configuration (ignored by git)
srcs/docker-compose.yml           services, network, volumes, secrets
srcs/requirements/
    mariadb/Dockerfile
    mariadb/tools/mariadb-entrypoint.sh       first-start database initialisation
    wordpress/Dockerfile
    wordpress/conf/www.conf                   php-fpm pool, listening on port 9000
    wordpress/tools/wordpress-entrypoint.sh   WordPress download, config, install
    nginx/Dockerfile
    nginx/conf/nginx.conf                     HTTPS server block and FastCGI proxy
```

### Main design choices

- **Base image**: every image starts from `debian:bookworm`, the penultimate
  stable Debian release. No other image is pulled.
- **Image names**: each image has the name of its service (`nginx`,
  `wordpress`, `mariadb`) with the tag `inception`. The `latest` tag is never
  used.
- **One process per container, running as PID 1**: the entrypoint scripts end
  with `exec`, so `mariadbd` and `php-fpm8.2 -F` replace the shell, and NGINX
  is started with `daemon off;`. Each daemon runs in the foreground and
  receives signals directly. No `tail -f`, `sleep infinity` or loop keeps a
  container alive.
- **Idempotent entrypoints**: the database is initialised only when the marker
  file `.initialized` is absent from the data directory, and WordPress is
  downloaded, configured and installed only when it is not already there.
  Restarting a container never overwrites existing data.
- **Startup order**: `mariadb` has a health check (`mariadb-admin ping`) and
  `wordpress` waits for it to be healthy before starting, so WP-CLI never
  talks to a database that is not ready.
- **Single entry point**: only NGINX publishes a port (443). It accepts
  TLSv1.2 and TLSv1.3 only, with a self-signed certificate generated when the
  image is built. PHP requests are forwarded to `wordpress:9000` over FastCGI.
  NGINX mounts the WordPress files read-only, because it only needs to read
  them to serve static content.
- **Crash recovery**: every service uses `restart: unless-stopped`.
- **WordPress users**: two accounts are created at installation, an
  administrator and a second user with the `author` role.

### Virtual Machines vs Docker

| | Virtual machine | Docker container |
|---|---|---|
| What is virtualised | Hardware; each VM runs its own kernel and a full OS | The operating system; containers share the host kernel |
| Isolation | Strong, enforced by the hypervisor | Lighter, based on kernel namespaces and cgroups |
| Size and startup | Gigabytes, tens of seconds | Megabytes, about a second |
| Typical unit | A whole machine with many services | One process or one service |
| Reproducibility | Disk image or provisioning scripts | Dockerfile, rebuilt layer by layer |

This project uses both: a virtual machine provides an isolated host, and
Docker runs each service inside it. A container is not a small VM. It has no
init system and lives exactly as long as its main process, which is why each
service here runs in the foreground as PID 1.

### Secrets vs Environment Variables

| | Environment variables (`srcs/.env`) | Docker secrets (`secrets/*.txt`) |
|---|---|---|
| Delivered as | Variables in the process environment | Read-only files in `/run/secrets/` |
| Visible with `docker inspect` | Yes | No |
| Inherited by child processes | Yes | No, a process must read the file |
| Scope | Every service that loads the file | Only the services that list the secret |
| Used here for | Domain name, database name, user names, e-mails, site title | The four passwords |

Environment variables are convenient for configuration but leak easily, so
this project keeps every password in a Docker secret. Each service receives
only the secrets it needs: `nginx` gets none, and `wordpress` never sees the
database root password. Both `srcs/.env` and `secrets/` are ignored by git,
and no password appears in a Dockerfile.

### Docker Network vs Host Network

| | Docker bridge network | Host network |
|---|---|---|
| Network stack | Each container has its own | Shared with the host |
| Reaching another service | By service name, through Docker's internal DNS | Through `localhost` |
| Exposure | Only ports explicitly published | Every listening port is on the host |
| Port conflicts | None between containers | Possible with host services |

The stack uses a dedicated bridge network named `inception`. The containers
reach each other by name (`mariadb:3306`, `wordpress:9000`) and those two
ports are never reachable from outside. With `network: host`, MariaDB and
php-fpm would listen directly on the host and NGINX would no longer be the
only way in, which is why the subject forbids it.

### Docker Volumes vs Bind Mounts

| | Named volume | Bind mount |
|---|---|---|
| Declared as | An object managed by Docker, with a name | A host path written in the service definition |
| Lifecycle | `docker volume ls`, `inspect`, `rm` | Not tracked by Docker |
| Portability | The service only refers to a name | The service depends on a host path |
| First use | Docker can pre-populate it from the image | The host directory hides the image content |

The subject asks for named volumes whose data ends up in
`/home/dabuchhe/data`. The two volumes, `mariadb_data` and `wordpress_data`,
are therefore declared in the top-level `volumes:` section with the `local`
driver and the options `type: none`, `o: bind`, `device: <host path>`. The
services refer to them by name only, Docker lists and manages them as
volumes, and their content is stored in the requested host directory.

## Instructions

Requirements: a Linux virtual machine with Docker Engine, the Docker Compose
plugin, `make` and `sudo` rights.

1. Create `srcs/.env` and the four files of `secrets/`. Neither is in the
   repository; their content is described in [DEV_DOC.md](DEV_DOC.md).
2. Point the domain name to the local machine:
   ```sh
   echo "127.0.0.1 dabuchhe.42.fr" | sudo tee -a /etc/hosts
   ```
3. Build and start everything:
   ```sh
   make
   ```
4. Open `https://dabuchhe.42.fr` and accept the self-signed certificate.

| Command       | Effect                                                              |
|---------------|---------------------------------------------------------------------|
| `make`        | Create the data directories, build the images, start the containers |
| `make down`   | Stop and remove the containers and the network; data is kept        |
| `make ps`     | Show the state of the containers                                    |
| `make logs`   | Follow the logs of the three services                               |
| `make clean`  | `down`, plus remove the images and the Docker volumes               |
| `make fclean` | `clean`, plus delete `/home/dabuchhe/data` (all site data is lost)  |
| `make re`     | `fclean` then `make`                                                |

## Resources

### References

- [Docker documentation](https://docs.docker.com/), in particular the
  [Dockerfile reference](https://docs.docker.com/reference/dockerfile/) and
  the [best practices for writing Dockerfiles](https://docs.docker.com/build/building/best-practices/)
- [Compose file reference](https://docs.docker.com/reference/compose-file/)
- [Secrets in Docker Compose](https://docs.docker.com/compose/how-tos/use-secrets/)
- [Docker volumes](https://docs.docker.com/engine/storage/volumes/) and
  [bind mounts](https://docs.docker.com/engine/storage/bind-mounts/)
- [Docker networking](https://docs.docker.com/engine/network/)
- [NGINX documentation](https://nginx.org/en/docs/), in particular
  [ngx_http_ssl_module](https://nginx.org/en/docs/http/ngx_http_ssl_module.html)
  and [ngx_http_fastcgi_module](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html)
- [MariaDB knowledge base](https://mariadb.com/kb/en/documentation/), in
  particular [mariadb-install-db](https://mariadb.com/kb/en/mariadb-install-db/)
- [PHP-FPM configuration](https://www.php.net/manual/en/install.fpm.configuration.php)
- [WP-CLI commands](https://developer.wordpress.org/cli/commands/)
- [OpenSSL `req` manual](https://docs.openssl.org/master/man1/openssl-req/)

### Use of AI

An AI assistant (Claude) was used for the following tasks:

- **Learning, before starting the project**: Claude was used as a tutor, in
  the style of a structured online course. It first produced a learning
  roadmap covering the notions the project relies on, then gave a lesson on
  each chapter. Every chapter ended with an exercise subject that the author
  had to complete independently to validate the notion before moving on. This
  concerns the preparation phase only, not a specific part of the repository.
- **Project planning**: once the notions were acquired, Claude was used to
  draw up a roadmap of the project, breaking it down into ordered steps.
- **Clarification during development**: Claude was consulted again whenever
  a notion needed to be explored further or a doubt had to be resolved.
- **Documentation**: Claude assisted the author in writing `README.md`,
  `USER_DOC.md` and `DEV_DOC.md`. The content was reviewed and checked against the project by the
  author.
