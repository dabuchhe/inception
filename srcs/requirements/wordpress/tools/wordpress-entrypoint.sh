#!/bin/sh

set -eu

# Secrets Docker: mounted in /run/secrets/<name declared in the compose>
DB_USER_PASSWORD=$(cat /run/secrets/db_user_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)

# Download WordPress if not present
[ -f wp-load.php ] || wp core download --allow-root

# Create wp-config.php if not present
[ -f wp-config.php ] || wp config create --allow-root \
    --dbname="$MYSQL_DATABASE" --dbuser="$MYSQL_USER" \
    --dbpass="$DB_USER_PASSWORD" --dbhost=mariadb:3306

# Install the website and create second user, only if not already set
if ! wp core is-installed --allow-root; then
    wp core install --allow-root --skip-email \
        --url="https://$DOMAIN_NAME" --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL"
    wp user create --allow-root "$WP_USER" "$WP_USER_EMAIL" \
        --role=author --user_pass="$WP_USER_PASSWORD"
fi

chown -R www-data:www-data /var/www/html

# -F : php-fpm stay on first plan; exec: make it PID 1
exec php-fpm8.2 -F
