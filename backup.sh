#!/usr/bin/env bash

PROJECT_DIRECTORY="${PROJECT_DIRECTORY:-"/srv"}"
DB_NAME="transpridebrighton"
DB_SERVICE="database"
DB_DUMP_FILENAME="tpb-database-$(date -u '+%Y%m%dT%H%m%SZ').sql"
S3_BUCKET="tpbdb"

[ "$(id -u 2>/dev/null)" == "0" ] || {
    echo >&2 "$(tput setaf 1)This script is designed to be run as a CRON job and must be run as root.$(tput sgr0)";
    exit 1;
}

[ -d "${PROJECT_DIRECTORY}" ] || {
    echo >&2 "$(tput setaf 1)Project directory does not exist. Make sure it's installed to \"${PROJECT_DIRECTORY}\".$(tput sgr0)";
    exit 1;
}

# Check for Docker Permissions
DOCKER="${DOCKER:-"docker"}"
command -v "${DOCKER}" >/dev/null 2>&1 || {
    echo >&2 "$(tput setaf 1)Docker Client \"${DOCKER}\" not available on \$PATH.$(tput sgr0)";
    exit 2;
}
"${DOCKER}" info >/dev/null 2>&1 || {
    echo >&2 "$(tput setaf 1)Docker Daemon unavailable.$(tput sgr0)";
    [ "$(id -u 2>/dev/null)" -ne "0" ] || { echo >&2 "$(tput setaf 1)Perhaps retry as root?$(tput sgr0)"; }
    exit 2;
}
COMPOSE="${COMPOSE:-"docker-compose"}"
command -v "${COMPOSE}" >/dev/null 2>&1 || {
    echo >&2 "$(tput setaf 1)Docker Compose \"${COMPOSE}\" not available on \$PATH.$(tput sgr0)";
    exit 2;
}

"${COMPOSE}" --project-directory="${PROJECT_DIRECTORY}" -f "docker-compose.yaml" up -d "${DB_SERVICE}" || {
    echo >&2 "$(tput setaf 1)Could not bring up database service \"${DB_SERVICE}\".$(tput sgr0)";
    exit 3;
}
sleep 15

"${COMPOSE}" --project-directory="${PROJECT_DIRECTORY}" -f "docker-compose.yaml" exec -e "MYSQL_PWD=$(cat './build/.secrets/dbpass' | tr -d '\n\r')" "${DB_SERVICE}" \
    mysqldump -u"root" \
    --add-locks --add-drop-table  --add-drop-trigger \
    --comments  --disable-keys    --complete-insert \
    --hex-blob  --insert-ignore   --quote-names \
    --tz-utc    --triggers        --single-transaction \
    "${DB_NAME}" > "/tmp/${DB_DUMP_FILENAME}" || {
        echo >&2 "$(tput setaf 1)Docker could not export database to filesystem dump.$(tput sgr0)";
        exit 4;
    }
DB_DUMP_COMPRESSED="${DB_DUMP_FILENAME}.bz2"
bzip2 --compress --best --stdout < "/tmp/${DB_DUMP_FILENAME}" > "/tmp/${DB_DUMP_COMPRESSED}" && {
    rm "/tmp/${DB_DUMP_FILENAME}" || true;
} || {
    echo >&2 "$(tput setaf 1)Could not compress database dump, continuing to upload uncompressed file to S3.$(tput sgr0)";
    DB_DUMP_COMPRESSED="${DB_DUMP_FILENAME}";
}

"${DOCKER}" run --rm -it --volume "/tmp:/tmp:ro" amazon/aws-cli s3 cp "/tmp/${DB_DUMP_COMPRESSED}" "s3://${S3_BUCKET}/${DB_DUMP_COMPRESSED}" || {
    echo >&2 "$(tput setaf 1)Could not upload database backup to S3 bucket \"${S3_BUCKET}\".$(tput sgr0)";
    echo >&2 "$(tput setaf 1)Does the EC2 instance this script is running on have the correct IAM roles assigned to it?$(tput sgr0)";
    echo >&2;
    echo >&2 "$(tput setaf 1)Backup file is located at \"/tmp/${DB_DUMP_COMPRESSED}\" for manual saving.$(tput sgr0)";
    exit 4;
}

rm "/tmp/${DB_DUMP_COMPRESSED}"
echo
