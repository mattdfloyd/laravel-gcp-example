# ============================================
# Stage 1: Composer dependencies
# ============================================
FROM dunglas/frankenphp:php8.4-alpine AS composer

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

RUN install-php-extensions pdo_pgsql redis pcntl

WORKDIR /app

# Copy composer files first for layer caching
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist

# Copy full app, then dump autoloader
COPY . .
RUN composer dump-autoload --optimize

# ============================================
# Stage 2: Frontend assets
# ============================================
FROM node:22-alpine AS assets

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build

# ============================================
# Stage 3: Production image
# ============================================
FROM dunglas/frankenphp:php8.4-alpine

RUN install-php-extensions pdo_pgsql redis pcntl

WORKDIR /app

# Copy app with composer deps from stage 1
COPY --from=composer /app /app

# Copy built frontend assets from stage 2
COPY --from=assets /app/public/build /app/public/build

# Laravel storage setup
RUN mkdir -p storage/framework/{sessions,views,cache} \
    && mkdir -p storage/logs \
    && mkdir -p bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache

# Clear cached config — env vars come from Cloud Run at runtime,
# so we can't cache config/routes at build time
RUN php artisan config:clear \
    && php artisan route:clear \
    && php artisan view:clear

# Default port for Cloud Run
ENV PORT=8080

EXPOSE 8080

ENTRYPOINT ["php", "artisan", "octane:frankenphp", "--port=8080", "--host=0.0.0.0"]
