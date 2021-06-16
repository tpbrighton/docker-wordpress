# TPB WordPress Setup w/ Docker

Better documentation coming soon, but here are some basic commands to get running:

**IMPORTANT!** These instructions were written with Ubuntu Linux in mind. I don't know how to use
Windows or macOS so you're on your own if you use those operating systems.

## Development

Create an additional file called `.env` in the project directory with the following contents:

```dotenv
DOMAIN=localhost
WEB_PORT=8080
SSL_PORT=8083
```

> A lot of the `make` commands are designed to be run on a production machine, rather
> than development. Use the equivalent `docker-compose` commands instead.

1. Install [Git](https://git-scm.com/), [Make](https://www.gnu.org/software/make/),
   [MkCert](https://mkcert.dev/), and [OpenSSL](https://www.openssl.org/).
2. `mkcert -install`
3. `git clone git@github.com:tpbrighton/docker-wordpress.git ./path/you/choose`
4. `cd ./path/you/choose`
5. `make build-images`
6. `make fetch-wordpress`
7. `make mock-https`
8. Add the line `127.0.0.1 transpridebrighton.local www.transpridebrighton.local` to the file `/etc/hosts`
   - On Windows this file is called `C:\Windows\System32\Drivers\etc\hosts`
9. `docker-compose up -d`
10. Visit [`https://transpridebrighton.local:8083/`](https://transpridebrighton.local:8083/)

## Production

1. `sudo apt update`
2. `sudo apt install git make openssl`
3. `git clone git@github.com:tpbrighton/docker-wordpress.git /srv`
4. `cd /srv`
5. `make console-setup` (optional)
6. `make install-docker`
7. `make install-letsencrypt`
8. `make build-images`
9. `make fetch-wordpress`
10. `make enable-https` (assuming that the domain `transpridebrighton.org` points to the server)
11. `make deploy`

### Other Production Settings

#### Timezone

`sudo timedatectl set-timezone 'Europe/London'`

#### CRON

`VISUAL="$(which nano)" sudo -E -- crontab -e`

Add the following lines to the bottom of the file:

```
# At 4am every Wednesday, try to renew the HTTPS certificates.
0  4 * * 3  make -f /srv/Makefile renew-certs >>/var/log/cron-renew-certs.log 2>&1
# At 3:30am every morning, make a database backup and upload to S3
30 3 * * *  make -f /srv/Makefile database-backup >>/var/log/cron-db-backup.log 2>&1
```

Create the log files that CRON output will save to:

`sudo mkdir -p "/var/log" && sudo touch "/var/log/cron-renew-certs.log" "/var/log/cron-db-backup.log"`
