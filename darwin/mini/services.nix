# darwin/mini/services.nix
# Docker Compose service definitions for Mac Mini media server
{ config, pkgs, lib, ... }:

let
  mediaVolume = "/Volumes/4tb";
  configDir = "${config.home.homeDirectory}/.config/media-server";
in
{
  # Immich - Photo management
  home.file."${configDir}/immich/docker-compose.yml".text = ''
    name: immich

    services:
      immich-server:
        container_name: immich_server
        image: ghcr.io/immich-app/immich-server:release
        volumes:
          - ${mediaVolume}/immich/library/upload:/usr/src/app/upload
          - /etc/localtime:/etc/localtime:ro
        env_file:
          - .env
        ports:
          - "2283:2283"
        depends_on:
          - redis
          - database
        restart: unless-stopped
        healthcheck:
          disable: false

      immich-machine-learning:
        container_name: immich_machine_learning
        image: ghcr.io/immich-app/immich-machine-learning:release
        volumes:
          - model-cache:/cache
        env_file:
          - .env
        restart: unless-stopped

      redis:
        container_name: immich_redis
        image: redis:6.2-alpine
        healthcheck:
          test: redis-cli ping || exit 1
        restart: unless-stopped

      database:
        container_name: immich_postgres
        image: tensorchord/pgvecto-rs:pg14-v0.2.0
        env_file:
          - .env
        environment:
          POSTGRES_PASSWORD: ''${DB_PASSWORD}
          POSTGRES_USER: ''${DB_USERNAME}
          POSTGRES_DB: ''${DB_DATABASE_NAME}
          POSTGRES_INITDB_ARGS: '--data-checksums'
        volumes:
          - ${mediaVolume}/immich/postgres:/var/lib/postgresql/data
        healthcheck:
          test: pg_isready --dbname=''${DB_DATABASE_NAME} --username=''${DB_USERNAME} || exit 1
          interval: 10s
          timeout: 5s
          retries: 5
        restart: unless-stopped

    volumes:
      model-cache:
  '';

  # Immich environment file template
  # Secrets should be injected from 1Password before starting
  home.file."${configDir}/immich/.env.template".text = ''
    # Database Configuration
    DB_HOSTNAME=immich_postgres
    DB_USERNAME=postgres
    DB_PASSWORD=__IMMICH_DB_PASSWORD__
    DB_DATABASE_NAME=immich

    # Redis
    REDIS_HOSTNAME=immich_redis

    # Machine Learning
    IMMICH_MACHINE_LEARNING_URL=http://immich-machine-learning:3003
  '';

  # Jellyfin - Media streaming
  home.file."${configDir}/jellyfin/docker-compose.yml".text = ''
    name: jellyfin

    services:
      jellyfin:
        container_name: jellyfin
        image: jellyfin/jellyfin:latest
        user: "501:20"
        volumes:
          - ${mediaVolume}/jellyfin/config:/config
          - ${mediaVolume}/jellyfin/cache:/cache
          - ${mediaVolume}/jellyfin/jellyfin-library:/media/library:ro
          - ${mediaVolume}/jellyfin/jellyfin-books:/media/books:ro
        ports:
          - "8096:8096"
          - "8920:8920"   # HTTPS
          - "7359:7359/udp"  # Discovery
        restart: unless-stopped
        environment:
          - TZ=Europe/Berlin
          - JELLYFIN_PublishedServerUrl=http://mini.local:8096
        healthcheck:
          test: curl -f http://localhost:8096/health || exit 1
          interval: 30s
          timeout: 10s
          retries: 3
  '';

  # Paperless-ngx - Document management
  home.file."${configDir}/paperless/docker-compose.yml".text = ''
    name: paperless

    services:
      broker:
        container_name: paperless_broker
        image: redis:7
        restart: unless-stopped
        volumes:
          - redisdata:/data

      paperless:
        container_name: paperless
        image: ghcr.io/paperless-ngx/paperless-ngx:latest
        restart: unless-stopped
        depends_on:
          - broker
        ports:
          - "8000:8000"
        volumes:
          - ${mediaVolume}/paperless/data:/usr/src/paperless/data
          - ${mediaVolume}/paperless/media:/usr/src/paperless/media
          - ${mediaVolume}/paperless/export:/usr/src/paperless/export
          - ${mediaVolume}/paperless/consume:/usr/src/paperless/consume
        env_file:
          - .env
        environment:
          PAPERLESS_REDIS: redis://broker:6379
          PAPERLESS_TIME_ZONE: Europe/Berlin
          USERMAP_UID: 501
          USERMAP_GID: 20
        healthcheck:
          test: ["CMD", "curl", "-f", "http://localhost:8000"]
          interval: 30s
          timeout: 10s
          retries: 5

    volumes:
      redisdata:
  '';

  # Paperless environment file template
  home.file."${configDir}/paperless/.env.template".text = ''
    # Paperless secret key (generate with: openssl rand -hex 32)
    PAPERLESS_SECRET_KEY=__PAPERLESS_SECRET_KEY__

    # Optional: Admin user (created on first run)
    # PAPERLESS_ADMIN_USER=admin
    # PAPERLESS_ADMIN_PASSWORD=__PAPERLESS_ADMIN_PASSWORD__

    # OCR settings
    PAPERLESS_OCR_LANGUAGE=eng+deu
  '';

  # Borgmatic - Backup service
  home.file."${configDir}/borgmatic/docker-compose.yml".text = ''
    name: borgmatic

    services:
      borgmatic:
        build:
          context: .
          dockerfile: Dockerfile
        container_name: borgmatic
        restart: unless-stopped
        environment:
          TZ: Europe/Berlin
          BORG_RSH: "ssh -i /ssh/id_rsa -p 23 -o IdentitiesOnly=yes -o ServerAliveInterval=60 -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/ssh/known_hosts"
        volumes:
          - ./config.d:/etc/borgmatic/config.d:ro
          - ./ssh:/ssh:ro
          - ./logs:/var/log/borgmatic
          - ${mediaVolume}/immich/library/upload:/sources/immich:ro
          - ${mediaVolume}/jellyfin:/sources/jellyfin:ro
          - ${mediaVolume}/paperless:/sources/paperless:ro
  '';

  # Borgmatic Dockerfile
  home.file."${configDir}/borgmatic/Dockerfile".text = ''
    FROM ghcr.io/borgmatic-collective/borgmatic:latest

    # Keep container running for manual backup execution
    CMD ["sleep", "infinity"]
  '';
}
