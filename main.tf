terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.13.0"
    }
  }
}

provider "docker" {}

# volumes
variable "volumes_path" {}
# mariadb
variable "mariadb_db" {}
variable "mariadb_host" {}
variable "mariadb_port" {}
variable "mariadb_rpw" {}
variable "mariadb_user" {}
variable "mariadb_upw" {}
# redis
variable "redis_host" {}
variable "redis_port" {}
# nginx
variable "nginx_host" {}
variable "nginx_port" {}
# application
variable "app_be_git_repo" {}
variable "app_fe_git_repo" {}
variable "app_version" {}
variable "app_port" {}

# pull the code from github
resource "null_resource" "clone_repos" {
  provisioner "local-exec" {
    command = "sh ${abspath("./scripts/fetch-build-be.sh")}"
    environment = {
      BE_REPO     = var.app_be_git_repo
      USER        = "elsa"
      USER_GROUP  = "elsa"
      APP_VERSION = var.app_version
    }
  }
  provisioner "local-exec" {
    command = "sh ${abspath("./scripts/fetch-build-fe.sh")}"
    environment = {
      FE_REPO = var.app_fe_git_repo
    }
  }
}

# network
resource "docker_network" "private_network" {
  name = "elsa_network"
}

# mariadb
resource "docker_container" "db" {
  name     = "db"
  hostname = var.mariadb_host
  image    = "mariadb:latest"
  restart  = "always"

  env = [
    "MARIADB_DATABASE=${var.mariadb_db}",
    "MARIADB_USER=${var.mariadb_user}",
    "MARIADB_PASSWORD=${var.mariadb_upw}",
    "MARIADB_ROOT_PASSWORD=${var.mariadb_rpw}"
  ]

  volumes {
    host_path      = abspath("${var.volumes_path}/mariadb")
    container_path = "/var/lib/mysql"
  }

  ports {
    internal = "3306"
    external = var.mariadb_port
  }

  networks_advanced {
    name    = docker_network.private_network.name
    aliases = ["db"]
  }
}

# redis
resource "docker_container" "redis" {
  name     = "redis"
  hostname = var.redis_host
  image    = "redis:alpine"
  command  = ["redis-server", "--appendonly", "yes"]
  restart  = "always"

  volumes {
    host_path      = abspath("${var.volumes_path}/redis")
    container_path = "/data"
  }

  ports {
    internal = "6379"
    external = var.redis_port
  }

  networks_advanced {
    name    = docker_network.private_network.name
    aliases = ["redis"]
  }
}

# app
resource "docker_container" "app" {
  count = 2

  name     = "elsaapp-${count.index}"
  hostname = "elsaapp-${count.index}"
  image    = "elsaapp:${var.app_version}"
  restart  = "always"

  env = [
    "MARIADB_USER=${var.mariadb_user}",
    "MARIADB_PASSWORD=${var.mariadb_upw}",
    "MARIADB_DB=${var.mariadb_db}",
    "REDIS_HOST=${var.redis_host}",
    "REDIS_PORT=${var.redis_port}",
    "PORT=${parseint("${var.app_port}", 10) + count.index}"
  ]

  ports {
    internal = parseint("${var.app_port}", 10) + count.index
    external = parseint("${var.app_port}", 10) + count.index
  }

  networks_advanced {
    name    = docker_network.private_network.name
    aliases = ["elsaapp-${count.index}"]
  }

  depends_on = [
    null_resource.clone_repos,
    docker_container.db,
    docker_container.redis
  ]
}

# nginx
resource "docker_container" "nginx" {
  name     = "nginx"
  hostname = var.nginx_host
  image    = "nginx:alpine"
  restart  = "always"

  env = [
    "NGINX_PORT=${var.nginx_port}",
  ]

  volumes {
    host_path      = abspath("./nginx/nginx.conf")
    container_path = "/etc/nginx/nginx.conf"
  }

  volumes {
    host_path      = abspath("./pixiemagic/dist")
    container_path = "/usr/share/nginx/html"
  }

  ports {
    internal = var.nginx_port
    external = var.nginx_port
  }

  networks_advanced {
    name    = docker_network.private_network.name
    aliases = ["nginx"]
  }

  depends_on = [
    docker_container.app,
  ]
}
