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

THIS_MAKEFILE_PATH:=$(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST))
THIS_DIR:=$(shell cd $(dir $(THIS_MAKEFILE_PATH));pwd)
THIS_MAKEFILE:=$(notdir $(THIS_MAKEFILE_PATH))

usage:
> @grep -E '(^[a-zA-Z_-]+:\s*?##.*$$)|(^##)' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.?## "}; {printf "\033[32m %-30s\033[0m%s\n", $$1, $$2}' | sed -e 's/\[32m ## /[33m/'
.PHONY: usage
.SILENT: usage

vars: ## Display Current Variables Set
vars:
> @$(foreach V,$(sort $(.VARIABLES)), $(if $(filter-out environment% default automatic, $(origin $V)),$(warning $V = $(value $V))))
.PHONY: vars
.SILENT: vars

require-root:
> [ "$$(id -u)" == "0" ] || { echo "This command must be run as root. Please retry with sudo."; exit 1; }
.PHONY: require-root
.SILENT: require-root

require-docker:
> command -v "docker" >/dev/null 2>&1 || { echo >&2 "Docker client required for command not found (PATH: \"$${PATH}\")."; exit 1; }
> docker info >/dev/null 2>&1 || { echo >&2 "Docker daemon unavailable. Perhaps retry as root/sudo?"; exit 1; }
> command -v "docker-compose" >/dev/null 2>&1 || { echo >&2 "Docker Compose required for command not found (PATH: \"$${PATH}\")."; exit 1; }
.PHONY: require-docker
.SILENT: require-docker

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
install-docker: require-root
> command -v "docker" >/dev/null 2>&1 && { echo >&2 "Docker already installed. Installation cancelled."; exit 1; } || true
> apt-get remove -y docker docker-engine docker.io containerd runc || true
> apt-get update -y
> apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
> curl -fsSL "https://download.docker.com/linux/ubuntu/gpg" | sudo gpg --dearmor -o "/usr/share/keyrings/docker-archive-keyring.gpg"
> echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
> apt update -y
> apt-get install -y docker-ce docker-ce-cli containerd.io
> command -v "docker-compose" >/dev/null 2>&1 && { echo ""; echo >&2 "Compose already installed. Docker installed, but Compose installation cancelled."; exit 1; } || true
# The following command installs v2.2.3 because I can't figure out a way to detect the latest version. Check for that at:
# https://github.com/docker/compose/releases/latest
> export COMPOSE_VERSION="2.2.3"
> curl -L "https://github.com/docker/compose/releases/download/$${COMPOSE_VERSION}/docker-compose-$$(uname -s)-$$(uname -m)" -o "/usr/local/bin/docker-compose"
> chmod +x /usr/local/bin/docker-compose
.PHONY: install-docker
.SILENT: install-docker

install-letsencrypt: ## Installs Let's Encrypt client on Ubuntu
install-letsencrypt: require-root
> command -v "letsencrypt" >/dev/null 2>&1 && { echo >&2 "Let's Encrypt already installed. Installation cancelled."; exit 1; } || true
> command -v "certbot" >/dev/null 2>&1 && { echo >&2 "Let's Encrypt already installed. Installation cancelled."; exit 1; } || true
> snap refresh core
> snap install --classic certbot
> ln -s "/snap/bin/certbot" "/usr/local/bin/certbot"
.PHONY: install-letsencrypt
.SILENT: install-letsencrypt

## Building

fetch-wordpress: ## Fetch the latest version of WordPress
fetch-wordpress:
> mkdir -p "$(THIS_DIR)/build"
> ls "$(THIS_DIR)/build/wordpress.tar.gz" >/dev/null 2>&1 && { \
    echo "Previous installation failed; remove \"$(THIS_DIR)/build/wordpress.tar.gz\" to try again."; \
    exit 1; \
} || { \
    curl -L "https://wordpress.org/latest.tar.gz" -o "$(THIS_DIR)/build/wordpress.tar.gz"; \
}
> (cd "$(THIS_DIR)/build"; tar xzf "wordpress.tar.gz")
> rm -rf "$(THIS_DIR)/public/wp-admin" "$(THIS_DIR)/public/wp-includes"
> rsync --archive --whole-file --one-file-system "$(THIS_DIR)/build/wordpress/" "$(THIS_DIR)/public/"
> rm -rf "$(THIS_DIR)/build/wordpress" "$(THIS_DIR)/build/wordpress.tar.gz"
.PHONY: fetch-wordpress
.SILENT: fetch-wordpress

build-images: ## Build Website Images ready for Deployment
build-images: require-docker
> docker-compose -f "$(THIS_DIR)/docker-compose.yaml" build --pull
.PHONY: build-images
.SILENT: build-images

enable-https: ## Installs an SSL Certificate for the Domain
enable-https: require-root require-docker
> docker-compose -f "$(THIS_DIR)/docker-compose.yaml" down
> mkdir -p "/etc/letsencrypt/challenges"
> docker-compose -f "$(THIS_DIR)/docker-compose.yaml" run -d --name "acme" server nginx -c "/etc/nginx/acme.conf"
> certbot certonly --webroot \
    --webroot-path="/etc/letsencrypt/challenges" \
    --cert-name="transpridebrighton.org" \
    -d "transpridebrighton.org" \
    -d "www.transpridebrighton.org"
> openssl dhparam -out "/etc/letsencrypt/dhparam.pem" 4096
> docker-compose -f "$(THIS_DIR)/docker-compose.yaml" down
.PHONY: enable-https
.SILENT: enable-https

mock-https: ## Mocks an SSL Certificate for Development
mock-https:
> command -v "mkcert" >/dev/null 2>&1 || { echo >&2 "Please install MkCert for Development."; exit 1; }
> export $$(echo "$$(cat "$(THIS_DIR)/.env" | sed 's/#.*//g'| xargs)")
> [ -z "$${DOMAIN}" ] && { echo >&2 "Could not determine domain from environment file."; exit 1; }
> mkdir -p "$(THIS_DIR)/build/ssl/challenges"
> mkdir -p "$(THIS_DIR)/build/ssl/live/$${DOMAIN}"
> (cd "$(THIS_DIR)/build/ssl"; mkcert "localhost" "$${DOMAIN}" "127.0.0.1")
> mv "$(THIS_DIR)/build/ssl/localhost+2.pem" "$(THIS_DIR)/build/ssl/live/$${DOMAIN}/fullchain.pem"
> cp "$(THIS_DIR)/build/ssl/live/$${DOMAIN}/fullchain.pem" "$(THIS_DIR)/build/ssl/live/$${DOMAIN}/chain.pem"
> mv "$(THIS_DIR)/build/ssl/localhost+2-key.pem" "$(THIS_DIR)/build/ssl/live/$${DOMAIN}/privkey.pem"
> openssl dhparam -out "$(THIS_DIR)/build/ssl/dhparam.pem" 1024
.PHONY: mock-https
.SILENT: mock-https

password: ## Generates a secure, random password for the database
password:
> mkdir -p "$(THIS_DIR)/build/.secrets"
> [ ! -f "$(THIS_DIR)/build/.secrets/dbpass" ] || { \
    echo >&2 "$$(tput setaf 1)A password has already been created. Remove the file \"$(THIS_DIR)/build/.secrets/dbpass\" to try again.$$(tput sgr0)"; \
    echo >&2 "$$(tput setaf 1)Double check that you're NOT REMOVING THE ONLY COPY OF YOUR EXISTING PASSWORD.$$(tput sgr0)"; \
    exit 1; \
}
> touch "$(THIS_DIR)/build/.secrets/dbpass"
> echo "$$(date "+%s.%N" | sha256sum | base64 | head -c 40)" > "$(THIS_DIR)/build/.secrets/dbpass"
> echo >&2 "$$(tput setaf 2)Database password generated and placed in file \"$(THIS_DIR)/build/.secrets/dbpass\".$$(tput sgr0)"
.PHONY: password
.SILENT: password

deploy: ## Once everything is built, run the web server (for production).
deploy: require-root require-docker
> mkdir -p "/opt/mysql"
> docker-compose -f "$(THIS_DIR)/docker-compose.yaml" up -d
.PHONY: deploy
.SILENT: deploy

## Maintenance

renew-certs: ## Re-installs SSL Certificates that near expiry and due for renewal
renew-certs: require-root require-docker
# CRON by default does not set any useful environment variables, Docker Compose
# is installed to a non-standard location so we have to specify that.
> export PATH="$${PATH:-"/bin:/usr/bin"}:/usr/local/bin"
> certbot renew
# Nginx has to be restarted in order to use the new certificates.
> docker-compose -f "$(THIS_DIR)/docker-compose.yaml" restart server
.PHONY: renew-certs
.SILENT: renew-certs

database-backup: ## Create a backup of the database and upload to S3
database-backup: require-docker
# CRON by default does not set any useful environment variables, Docker Compose
# is installed to a non-standard location so we have to specify that.
> export PATH="$${PATH:-"/bin:/usr/bin"}:/usr/local/bin"
# Database backup is meant to be run by CRON and output saved to a log file. Use ANSI only (no colours).
> export DB_NAME="transpridebrighton"
> export DB_SERVICE="database"
> export DB_DUMP_FILENAME="tpb-database-$$(date -u '+%Y%m%dT%H%m%SZ').sql"
> export S3_BUCKET="tpbdb"
> command -v bzip2 >/dev/null 2>&1 || { echo >&2 "Command \"bzip2\" not found in \$$PATH. Make sure CRON has the correct environment variables set."; exit 1; }
> docker-compose -f "$(THIS_DIR)/docker-compose.yaml" up -d "database" || { echo >&2 "Could not bring up Docker service \"database\"."; exit 2; }
> sleep 10
> docker-compose -f "$(THIS_DIR)/docker-compose.yaml" exec -T -e "MYSQL_PWD=$$(cat '$(THIS_DIR)/build/.secrets/dbpass' | tr -d '\n\r')" "database" mysqldump -u"root" \
    --add-locks --add-drop-table  --add-drop-trigger \
    --comments  --disable-keys    --complete-insert \
    --hex-blob  --insert-ignore   --quote-names \
    --tz-utc    --triggers        --single-transaction \
    --skip-extended-insert \
    "$${DB_NAME}" > "/tmp/$${DB_DUMP_FILENAME}" || { echo >&2 "Docker could not export database to filesystem dump."; exit 3; }
> export DB_DUMP_COMPRESSED="$${DB_DUMP_FILENAME}.bz2"
> bzip2 --compress --best --stdout < "/tmp/$${DB_DUMP_FILENAME}" > "/tmp/$${DB_DUMP_COMPRESSED}" && { \
    rm "/tmp/$${DB_DUMP_FILENAME}" || true; \
} || { \
    echo >&2 "Could not compress database dump, continuing to upload uncompressed file to S3."; \
    export DB_DUMP_COMPRESSED="$${DB_DUMP_FILENAME}"; \
}
> docker run --rm --volume "/tmp:/tmp:ro" amazon/aws-cli s3 cp "/tmp/$${DB_DUMP_COMPRESSED}" "s3://$${S3_BUCKET}/$${DB_DUMP_COMPRESSED}" >/dev/null && { \
    echo >&2 "Database has been backup and uploaded to \"s3://$${S3_BUCKET}/$${DB_DUMP_COMPRESSED}\"."; \
} || { \
    echo >&2 "Could not upload database backup to S3 bucket \"$${S3_BUCKET}\"."; \
    echo >&2 "Backup file is located at \"/tmp/$${DB_DUMP_COMPRESSED}\" for manual saving."; \
    exit 4; \
}
> rm "/tmp/$${DB_DUMP_COMPRESSED}"
.PHONY: database-backup
.SILENT: database-backup

restore-backup: ## Restore the Database from a Backup File
restore-backup: require-docker
> whiptail --title="WARNING" --yesno --defaultno "THIS WILL COMPLETELY DELETE YOUR EXISTING DATABASE! Are you sure?" 8 60 || { exit 1; }
> whiptail --title "Location" --yesno --yes-button "Local Filesystem" --no-button "S3 Bucket" "Does the backup exist on the local filesystem, or is it stored in the Amazon S3 bucket?" 8 60 && { \
    export BACKUP_FILE=$$(whiptail --inputbox "Please enter the full path to the backup file that is located on the local filesystem:" 8 60 3>&1 1>&2 2>&3); \
    [ -f "$${BACKUP_FILE}" ] || { echo >&2 "$$(tput setaf 1)Backup file \"$${BACKUP_FILE}\" does not exist.$$(tput sgr0)"; exit 1; }; \
} || { \
    export S3_FILE=$$(whiptail --inputbox "Please enter the name/path of the file from the \"tpbdb\" S3 bucket you'd like to use." 8 60  3>&1 1>&2 2>&3); \
    export BACKUP_FILE="$$(mktemp)"; \
    docker run --rm -it --user="$$(id -u 2>/dev/null)" --volume "/tmp:/tmp" "amazon/aws-cli" s3 cp "s3://tpbdb/$${S3_FILE}" "$${BACKUP_FILE}" || { \
        echo >&2 "$$(tput setaf 1)Could not download database backup file \"$${S3_FILE}\" from S3 bucket \"tpbdb\".$$(tput sgr0)"; \
        rm "$${BACKUP_FILE}" || true; \
        exit 2; \
    }; \
}
> export TEMP_FILE="$$(mktemp)"
> export BACKUP_FILE_IMPORT="$${TEMP_FILE}"
> bzip2 --decompress --stdout < "$${BACKUP_FILE}" > "$${BACKUP_FILE_IMPORT}" || { \
    echo >&2 "Could not decompress backup file, continuing with the assumption it is not compressed."; \
    export BACKUP_FILE_IMPORT="$${BACKUP_FILE}"; \
    rm "$${TEMP_FILE}" || true; \
}
> docker-compose -f "$(THIS_DIR)/docker-compose.yaml" exec -e "MYSQL_PWD=$$(cat '$(THIS_DIR)/build/.secrets/dbpass' | tr -d '\n\r')" "database" mysql -u"root" -e "DROP DATABASE IF EXISTS transpridebrighton; CREATE DATABASE IF NOT EXISTS transpridebrighton;"
> docker-compose -f "$(THIS_DIR)/docker-compose.yaml" exec -T -e "MYSQL_PWD=$$(cat '$(THIS_DIR)/build/.secrets/dbpass' | tr -d '\n\r')" "database" mysql -u"root" "transpridebrighton" < "$${BACKUP_FILE_IMPORT}" || { \
    echo >&2 "$$(tput setaf 1)Could not import database backup file.$$(tput sgr0)"; \
    echo >&2 "$$(tput setaf 1)You now have no database! Go find a working backup quickly!$$(tput sgr0)"; \
    rm "$${TEMP_FILE}" || true; \
    exit 1; \
}
> rm "$${TEMP_FILE}" || true
> echo >&2 "$$(tput setaf 2)Database has been restored from backup, double check that it's working!$$(tput sgr0)"
.PHONY: restore-backup
.SILENT: restore-backup

install-cron: ## Install a CRON job file to automate: renew-certs, database-backup
install-cron: require-root
> export CRONTAB="/etc/cron.daily/tpb"
> export COMMANDS="renew-certs database-backup"
> rm -f "$${CRONTAB}" || true
> touch "$${CRONTAB}"
> echo "#!/bin/sh" > "$${CRONTAB}"
> echo "mkdir -p \"$(THIS_DIR)/var/log\"" >> "$${CRONTAB}"
> for COMMAND in $${COMMANDS}; do
>     echo "(cd \"$(THIS_DIR)\"; date; make -f \"$(THIS_DIR)/$(THIS_MAKEFILE)\" \"$${COMMAND}\"; echo \"\") >>\"$(THIS_DIR)/var/log/cron-tpb-$${COMMAND}.log\" 2>&1" >> "$${CRONTAB}"
> done
> chmod +x "$${CRONTAB}"
> echo "CRON job installed for commands \"$${COMMANDS}\" to \"$${CRONTAB}\"."
> echo "Please make sure this file will be loaded and run by the system CRON (perhaps check \"/etc/crontab\")."
> echo "Depending on system setup, you may be required to install the system package \"anacron\" (periodic command scheduling for CRON without assuming that the system is running continuously)."
.PHONY: install-cron
.SILENT: install-cron
