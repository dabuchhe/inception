# User documentation

This document explains how to use and administer the Inception stack once it
is installed. To install it from scratch, see [DEV_DOC.md](DEV_DOC.md).

All `make` commands are run from the root of the repository.

## Services provided

The stack provides one WordPress website, served over HTTPS.

| Service     | What it does for you                                                    |
|-------------|-------------------------------------------------------------------------|
| `nginx`     | The web server. It is the only service reachable from outside, on port 443, over HTTPS only. |
| `wordpress` | The website itself and its administration panel.                        |
| `mariadb`   | The database that stores the posts, pages, users and settings.          |

The site content survives restarts: it is stored on the host in
`/home/dabuchhe/data`, not inside the containers.

## Start and stop the project

| Action                          | Command     |
|---------------------------------|-------------|
| Start (builds what is missing)  | `make`      |
| Stop, keeping all data          | `make down` |
| Start again                     | `make`      |

The first start takes a few minutes, because the images are built and
WordPress is downloaded and installed. Later starts take a few seconds.

The containers restart on their own if a service crashes. They stay stopped
after `make down`.

Two more commands delete things and should be used with care:

| Command       | What is removed                                                        |
|---------------|------------------------------------------------------------------------|
| `make clean`  | Containers, images and Docker volumes. The files in `/home/dabuchhe/data` are kept, so the site is back after `make`. |
| `make fclean` | Everything above and `/home/dabuchhe/data`. The website and its database are permanently lost. |

## Access the website and the administration panel

| Page                 | Address                               |
|----------------------|---------------------------------------|
| Website              | `https://dabuchhe.42.fr`              |
| Administration panel | `https://dabuchhe.42.fr/wp-admin`     |

- The certificate is self-signed, so the browser shows a security warning on
  the first visit. Accept it to continue.
- Only HTTPS works. `http://dabuchhe.42.fr` (port 80) is not served.
- If the address is not found, check that `/etc/hosts` contains the line
  `127.0.0.1 dabuchhe.42.fr`.

Two WordPress accounts exist:

| Account       | Role          | Can do                                         |
|---------------|---------------|------------------------------------------------|
| Administrator | Administrator | Everything: settings, themes, plugins, users   |
| Second user   | Author        | Write and publish their own posts              |

## Locate and manage credentials

Nothing confidential is stored in the git repository. The credentials are in
two places on the machine that runs the stack.

User names and e-mail addresses are in `srcs/.env`:

| Variable         | Meaning                          |
|------------------|----------------------------------|
| `WP_ADMIN_USER`  | WordPress administrator login    |
| `WP_USER`        | WordPress second user login      |
| `MYSQL_USER`     | Database user used by WordPress  |
| `MYSQL_DATABASE` | Name of the WordPress database   |

Passwords are in the `secrets/` directory, one password per file:

| File                            | Password of                         |
|---------------------------------|-------------------------------------|
| `secrets/wp_admin_password.txt` | WordPress administrator             |
| `secrets/wp_user_password.txt`  | WordPress second user               |
| `secrets/db_user_password.txt`       | Database user `MYSQL_USER`          |
| `secrets/db_root_password.txt`  | Database `root` account             |

To read a password:

```sh
cat secrets/wp_admin_password.txt
```

### Changing a password

These files are read **only once**, when the site is installed for the first
time. Editing a file afterwards does not change the password of an existing
site.

- **WordPress accounts**: change the password in the administration panel
  (Users, then Profile), or from the command line:
  ```sh
  docker exec wordpress wp user update <login> --user_pass='<new password>' --allow-root
  ```
  Then update the matching file in `secrets/` so it stays accurate.
- **Database passwords**: the simplest way is to edit the files in `secrets/`
  and reinstall with `make re`. This erases the website. To change them
  without losing data, see [DEV_DOC.md](DEV_DOC.md).

## Check that the services are running

1. List the containers:
   ```sh
   make ps
   ```
   The three containers `mariadb`, `wordpress` and `nginx` must be listed with
   the status `Up`, and `mariadb` must show `(healthy)`.

2. Check that the website answers:
   ```sh
   curl -kI https://dabuchhe.42.fr
   ```
   The first line of the answer must be `HTTP/1.1 200 OK`.

3. Check that the database answers:
   ```sh
   docker inspect --format '{{.State.Health.Status}}' mariadb
   ```
   The answer must be `healthy`.

4. If something is wrong, read the logs:
   ```sh
   make logs
   ```
   Press `Ctrl+C` to stop following them. The services keep running.

Common problems:

| Symptom                                   | Likely cause                                                        |
|-------------------------------------------|---------------------------------------------------------------------|
| `wordpress` restarts in a loop            | A variable is missing in `srcs/.env`. The logs name it.             |
| `make` stops on a secret file             | A file in `secrets/` is empty. Write its password in it.            |
| The browser cannot find the site          | The `/etc/hosts` line is missing.                                   |
| "Error establishing a database connection"| `mariadb` is not healthy, or `secrets/db_user_password.txt` was changed after installation. |
| `make` fails on port 443                  | Another program on the host already uses port 443.                  |
