# TPB WordPress Setup w/ Docker

Better documentation coming soon, but here are some basic commands to get running:

#### Production

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

#### Development

Create an additional file called `.env` in the project directory with the following contents:

```dotenv
WEB_PORT=8080
SSL_PORT=8083
```

1. Install [Git](https://git-scm.com/), [Make](https://www.gnu.org/software/make/), and [MkCert](https://mkcert.dev/).
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
