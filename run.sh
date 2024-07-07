#!/bin/bash

# Variables
SSL_DIR="ssl"
DOMAIN="localhost"
CERT_DAYS=365
MYSQL_ROOT_PASSWORD="rootpassword"
MYSQL_DATABASE="racktables"
MYSQL_USER="racktables"
MYSQL_PASSWORD="racktablespassword"

# Create a directory to store the SSL certificates
mkdir -p $SSL_DIR

# Generate the private key
openssl genpkey -algorithm RSA -out $SSL_DIR/apache.key

# Generate the certificate signing request (CSR)
openssl req -new -key $SSL_DIR/apache.key -out $SSL_DIR/apache.csr -subj "/C=US/ST=State/L=City/O=Organization/OU=Department/CN=$DOMAIN"

# Generate the self-signed certificate
openssl x509 -req -days $CERT_DAYS -in $SSL_DIR/apache.csr -signkey $SSL_DIR/apache.key -out $SSL_DIR/apache.crt

# Create Dockerfile
cat <<EOF > Dockerfile
# Use the official PHP image as a base
FROM php:7.4-apache

# Install required PHP extensions and other dependencies
RUN apt-get update && apt-get install -y \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libldap2-dev \
    zlib1g-dev \
    libicu-dev \
    g++ \
    libmcrypt-dev \
    libxml2-dev \
    libxslt1-dev \
    libzip-dev \
    unzip \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j\$(nproc) gd \
    && docker-php-ext-install mysqli \
    && docker-php-ext-install pdo_mysql \
    && docker-php-ext-install zip \
    && docker-php-ext-install ldap \
    && docker-php-ext-install opcache \
    && docker-php-ext-install intl \
    && docker-php-ext-install xsl \
    && a2enmod ssl \
    && a2enmod rewrite \
    && a2enmod headers

# Download RackTables and extract it to the web server's root directory
RUN curl -L https://github.com/RackTables/racktables/releases/download/RackTables-0.21.0/RackTables-0.21.0.tar.gz | tar zx -C /var/www/html --strip-components=1

# Set proper permissions for the web server
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html

# Copy SSL certificates and config
COPY $SSL_DIR/apache.crt /etc/ssl/certs/apache.crt
COPY $SSL_DIR/apache.key /etc/ssl/private/apache.key
COPY ssl/default-ssl.conf /etc/apache2/sites-available/default-ssl.conf

# Enable the SSL site
RUN a2ensite default-ssl

# Expose port 443 for HTTPS
EXPOSE 443

# Start the Apache server
CMD ["apache2-foreground"]
EOF

# Create default-ssl.conf for Apache
cat <<EOF > ssl/default-ssl.conf
<IfModule mod_ssl.c>
    <VirtualHost _default_:443>
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/html

        SSLEngine on
        SSLCertificateFile /etc/ssl/certs/apache.crt
        SSLCertificateKeyFile /etc/ssl/private/apache.key

        <FilesMatch "\.(cgi|shtml|phtml|php)$">
            SSLOptions +StdEnvVars
        </FilesMatch>
        <Directory /usr/lib/cgi-bin>
            SSLOptions +StdEnvVars
        </Directory>

        BrowserMatch "MSIE [2-6]" \\
            nokeepalive ssl-unclean-shutdown \\
            downgrade-1.0 force-response-1.0
        BrowserMatch "MSIE [17-9]" ssl-unclean-shutdown

    </VirtualHost>
</IfModule>
EOF

# Create docker-compose.yml
cat <<EOF > docker-compose.yml
version: '3.7'

services:
  db:
    image: mysql:5.7
    container_name: racktables-db
    volumes:
      - db_data:/var/lib/mysql
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: $MYSQL_ROOT_PASSWORD
      MYSQL_DATABASE: $MYSQL_DATABASE
      MYSQL_USER: $MYSQL_USER
      MYSQL_PASSWORD: $MYSQL_PASSWORD

  racktables:
    build: .
    container_name: racktables-app
    ports:
      - "443:443"
    depends_on:
      - db
    restart: always
    environment:
      DB_HOST: db
      DB_NAME: $MYSQL_DATABASE
      DB_USER: $MYSQL_USER
      DB_PASSWORD: $MYSQL_PASSWORD
    volumes:
      - ./ssl:/etc/ssl

volumes:
  db_data:
EOF

# Build and run Docker containers
docker-compose up --build -d