# TPB WordPress Setup w/ Docker

Better documentation coming soon, but here are some basic commands to get running:

**IMPORTANT!** These instructions were written with Ubuntu Linux in mind. I don't know how to use
Windows or macOS so you're on your own if you use those operating systems.

## Production

Read the [documentation](./docs/) included in this repository.

## Development

Create an additional file called `.env` in the project directory with the following contents:

```dotenv
DOMAIN=transpridebrighton.local
WEB_PORT=8080
SSL_PORT=8083
```

> A lot of the `make` commands are designed to be run on a production machine, rather
> than development. Use the equivalent `docker-compose` commands instead.

1. Install [Git](https://git-scm.com/), [Make](https://www.gnu.org/software/make/),
   [MkCert](https://mkcert.dev/), [Docker](https://docs.docker.com/get-docker/) +
   [Docker Compose](https://docs.docker.com/compose/install/), and
   [OpenSSL](https://www.openssl.org/).
2. `mkcert -install`
3. `git clone git@github.com:tpbrighton/docker-wordpress.git ./path/you/choose`
4. `cd ./path/you/choose`
5. `docker-compose build --pull`
6. `make fetch-wordpress`
7. `make mock-https`
8. Add the line `127.0.0.1 transpridebrighton.local www.transpridebrighton.local` at the bottom of the file `/etc/hosts`
   - On Windows this file is called `C:\Windows\System32\Drivers\etc\hosts`
9. `docker-compose up -d`
10. Visit [`https://transpridebrighton.local:8083/`](https://transpridebrighton.local:8083/)

#### Timezone

The default timezone of the server may not be correct according to the charity, run the following command to make sure:

```
sudo timedatectl set-timezone 'Europe/London'
```
