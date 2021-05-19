SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
ifeq ($(origin .RECIPEPREFIX), undefined)
  $(error This Make does not support .RECIPEPREFIX; Please use GNU Make 4.0 or later)
endif
.RECIPEPREFIX = >

usage:
> @grep -E '(^[a-zA-Z_-]+:\s*?##.*$$)|(^##)' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.?## "}; {printf "\033[32m %-30s\033[0m%s\n", $$1, $$2}' | sed -e 's/\[32m ## /[33m/'
.PHONY: usage
.SILENT: usage

## Server Setup

console-setup: ## Setup some nice defaults for the terminal (optional)
console-setup:
> ls "$$HOME/.dotfiles" >/dev/null 2>&1 && { echo "Dotfiles Repository has already been downloaded."; exit 1; } || true
> git clone "git://github.com/zanbaldwin/dotfiles.git" "$$HOME/.dotfiles"
> ln -s "$$HOME/.dotfiles/.bash_aliases" "$$HOME/.bash_aliases"
> ln -s "$$HOME/.dotfiles/.bash_prompt" "$$HOME/.bash_prompt"
> echo ""; echo "Type the command the following command to reload the terminal: source ~/.bashrc"
.PHONY: console-setup
.SILENT: console-setup

install-docker: ## Installs Docker on Ubuntu
install-docker:
> command -v "docker" >/dev/null 2>&1 && { echo >&2 "Docker already installed. Installation cancelled."; exit 1; } || true
> sudo apt-get remove docker docker-engine docker.io containerd runc
> sudo apt-get update
> sudo apt-get install apt-transport-https ca-certificates curl gnupg lsb-release
> curl -fsSL "https://download.docker.com/linux/ubuntu/gpg" | sudo gpg --dearmor -o "/usr/share/keyrings/docker-archive-keyring.gpg"
> echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
> sudo apt update
> sudo apt-get install docker-ce docker-ce-cli containerd.io
> command -v "docker-compose" >/dev/null 2>&1 && { echo ""; echo >&2 "Compose already installed. Docker installed, but Compose installation cancelled."; exit 1; } || true
# The following command installs v1.29.0 because I can't figure out a way to detect the latest version. Check for that at:
# https://github.com/docker/compose/releases/latest
> export COMPOSE_VERSION="1.29.0"
> sudo curl -L "https://github.com/docker/compose/releases/download/$${COMPOSE_VERSION}/docker-compose-$$(uname -s)-$$(uname -m)" -o /usr/local/bin/docker-compose
> sudo chmod +x /usr/local/bin/docker-compose
.PHONY: install-docker
.SILENT: install-docker

install-letsencrypt: ## Installs Let's Encrypt client on Ubuntu
install-letsencrypt:
> command -v "letsencrypt" >/dev/null 2>&1 && { echo >&2 "Let's Encrypt already installed. Installation cancelled."; exit 1; } || true
> command -v "certbot" >/dev/null 2>&1 && { echo >&2 "Let's Encrypt already installed. Installation cancelled."; exit 1; } || true
> sudo snap refresh core
> sudo snap install --classic certbot
> sudo ln -s "/snap/bin/certbot" "/usr/local/bin/certbot"
.PHONY: install-letsencrypt
.SILENT: install-letsencrypt

## Building

fetch-wordpress: ## Fetch the latest version of WordPress
fetch-wordpress:
> mkdir -p "./build"
> ls "./build/wordpress.tar.gz" >/dev/null 2>&1 && { echo "Previous installation failed; remove ./build/wordpress.tar.gz to try again."; } || { curl -L "https://wordpress.org/latest.tar.gz" -o "./build/wordpress.tar.gz"; }
> (cd "./build"; tar xzf "wordpress.tar.gz")
> rm -rf "./public/wp-admin" "./public/wp-includes"
> rsync --archive --whole-file --one-file-system "./build/wordpress/" "./public/"
> rm -rf "./build/wordpress" "./build/wordpress.tar.gz"
.PHONY: fetch-wordpress
.SILENT: fetch-wordpress

build-images: ## Build Website Images ready for Deployment
build-images:
> sudo docker-compose -f "docker-compose.yaml" build --pull
.PHONY: build-images
.SILENT: build-images

enable-https: ## Installs an SSL Certificate for the Domain
enable-https:
> sudo docker-compose -f "docker-compose.yaml" down
> sudo mkdir -p "/etc/letsencrypt/challenges"
> sudo docker-compose -f "docker-compose.yaml" run -d server nginx -c "/etc/nginx/acme.conf"
> sudo letsencrypt certonly --webroot --webroot-path="/etc/letsencrypt/challenges" --cert-name="transpridebrighton.org" -d "transpridebrighton.org" -d "www.transpridebrighton.org"
> sudo openssl dhparam -out "/etc/letsencrypt/dhparam.pem" 4096
> sudo docker-compose -f "docker-compose.yaml" down
.PHONY: enable-https
.SILENT: enable-https

mock-https: ## Mocks an SSL Certificate for Development
mock-https:
> command -v "mkcert" >/dev/null 2>&1 || { echo >&2 "Please install MkCert for Development."; exit 1; }
> mkdir -p "./build/ssl/challenges"
> mkdir -p "./build/ssl/live/transpridebrighton.org"
> (cd "./build/ssl"; mkcert "transpridebrighton.local" "www.transpridebrighton.local")
> mv "./build/ssl/transpridebrighton.local+1.pem" "./build/ssl/live/transpridebrighton.org/fullchain.pem"
> cp "./build/ssl/live/transpridebrighton.org/fullchain.pem" "./build/ssl/live/transpridebrighton.org/chain.pem"
> mv "./build/ssl/transpridebrighton.local+1-key.pem" "./build/ssl/live/transpridebrighton.org/privkey.pem"
> openssl dhparam -out "./build/ssl/dhparam.pem" 1024
.PHONY: mock-https
.SILENT: mock-https

password: ## Generates a secure, random password for the database
password:
> mkdir -p "./.secrets"
> echo "Your randomly generated password is:"
> echo
> echo "$$(date "+%s.%N" | sha256sum | base64 | head -c 32)"
> echo
> echo "Please create the file '.secrets/dbpass' and put the password as the sole contents of that file."
> echo "If that file already exists and is not empty, it's likely already in use. If so:"
> echo "DO NOT REMOVE YOUR ONLY COPY OF THE EXISTING PASSWORD."
.PHONY: password
.SILENT: password

deploy: ## Once everything is built, run the web server
deploy:
> sudo mkdir "/var/run/mysql"
> sudo docker-compose -f "docker-compose.yaml" up -d
.PHONY: deploy
.SILENT: deploy

## Maintenance

renew-certs: ## Re-installs SSL Certificates that near expiry and due for renewal
renew-certs:
> sudo letsencrypt renew
# Nginx has to be restarted in order to use the new certificates.
> sudo docker-compose -f "docker-compose.yaml" restart server
.PHONY: renew-certs
.SILENT: renew-certs

database-backup: ## Create a backup of the current database
database-backup:
> sudo docker-compose -f "docker-compose.yaml" up -d database >/dev/null 2>&1
> export DB_DUMP_FILENAME="tpb-database-$$(date -u '+%Y%m%dT%H%m%SZ').sql"
> export DB_NAME="transpridebrighton"
> sudo docker-compose -f "docker-compose.yaml" exec -e "MYSQL_PWD=$$(cat './.secrets/dbpass' | tr -d '\n\r')" database mysqldump -u"root" --add-drop-table --add-drop-trigger --add-locks --comments --complete-insert --disable-keys --hex-blob --insert-ignore --quote-names --single-transaction --triggers --tz-utc "$${DB_NAME}" 2>/dev/null | bzip2 --compress --best --stdout > "/tmp/$${DB_DUMP_FILENAME}.bz2" 2>/dev/null
> echo "/tmp/$${DB_DUMP_FILENAME}.bz2"
.PHONY: database-backup
.SILENT: database-backup
