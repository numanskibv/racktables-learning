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
    && docker-php-ext-install -j$(nproc) gd \
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
COPY ssl/apache.crt /etc/ssl/certs/apache.crt
COPY ssl/apache.key /etc/ssl/private/apache.key
COPY ssl/default-ssl.conf /etc/apache2/sites-available/default-ssl.conf

# Enable the SSL site
RUN a2ensite default-ssl

# Expose port 443 for HTTPS
EXPOSE 443

# Start the Apache server
CMD ["apache2-foreground"]