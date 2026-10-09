FROM debian:bookworm

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        mariadb-server \
        mariadb-client \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /run/mysqld \
    && chown mysql:mysql /run/mysqld

CMD ["mariadbd", "--user=mysql", "--bind-address=0.0.0.0"]