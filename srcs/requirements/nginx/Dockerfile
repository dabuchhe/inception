FROM debian:bookworm

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        nginx \
        openssl \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/nginx/ssl \
    && openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
        -keyout /etc/nginx/ssl/inception.key \
        -out /etc/nginx/ssl/inception.crt \
        -subj "/C=FR/L=Lyon/O=42/CN=dabuchhe.42.fr"

RUN rm /etc/nginx/sites-enabled/default \
        /var/www/html/index.nginx-debian.html

COPY conf/nginx.conf /etc/nginx/conf.d/inception.conf

EXPOSE 443

ENTRYPOINT ["nginx", "-g", "daemon off;"]
