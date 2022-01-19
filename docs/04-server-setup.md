# Setting up the server

## Logging In to the Server

You will need:
- The IP address of the EC2 instance [you've just created](./03-ec2-instance.md) (this will be the elastic IP if you
  assigned one to the instance), and
- The path to the private key file you downloaded earlier when making a key pair.

```shell
ssh "ubuntu@<IP_ADDRESS>" -i "<KEY_FILE>"
```

For example, in my case this would be:

```shell
ssh "ubuntu@35.177.199.22" -i "~/.ssh/AWSLondonDefault.pem"
```

> Once the EC2 instance (server) is set up, you can add additional (eg, your own) public key to `~/.ssh/authorized_keys`

## Required Software

### Update Existing Software

This could take up to 10 minutes, ish.

```shell
sudo apt update
sudo apt dist-upgrade -y
```

### Packaged Software

Once logged into the server, run the following command to install the required software (`git`, `make`, `openssl` and
`ssh`) to download and setup the website:

```shell
sudo apt install -y git make openssl ssh
```

## Installing the (Website) Project

### Create SSH Keypair

The TPB Website project is private, so we must be able to identify the server as trusted.

Create a new SSH keypair with the command `ssh-keygen -t ed25519 -C "EC2 Production Server Deploy Key"`. Don't enter a
password. Copy the contents of the file it created: `~/.ssh/id_ed25519.pub`.

Head to the [`tpbrighton/docker-wordpress` GitHub repository](https://github.com/tpbrighton/docker-wordpress), navigate
to _Settings_ → _Deploy Keys_ → [_Add deploy key_](https://github.com/tpbrighton/docker-wordpress/settings/keys/new "Add deploy key").

Paste the contents of `~/.ssh/id_ed25519.pub` into the key contents box, and give it a title. Click _Add key_ to save.

### Setup Website Project on Server

Back on the server:

1. Create a directory to hold the project, industry best practices suggest using `/srv` because this server will be
   serving a website: `sudo mkdir /srv`
2. Make sure that the current user owns it: `sudo chown -R "$(whoami):$(whoami)" /srv`
3. Clone the project from GitHub into the directory we just made: `git clone "git@github.com:tpbrighton/docker-wordpress.git" /srv`
4. The rest of the instructions have been scripted into the project, so change into the project directory: `cd /srv`
5. Install Docker (which is what will "contain" the website software that runs WordPress): `sudo make install-docker`
6. Install Let's Encrypt (software for generating SSL certificates): `sudo make install-letsencrypt`
7. Build the individual containers (PHP, Database, etc); _this may take a while_: `sudo make build-images`
8. Fetch a fresh installation of WordPress itself: `make fetch-wordpress`
9. Get Let's Encrypt to generate SSL certificates for the website: `sudo make enable-https`
   - This assumes that the specified domain (eg, `transpridebrighton.org`) is already pointing to the server, do not run
     this command if you're trying to transfer the website from one server to another without any downtime. Rsync the
     contents of `/etc/letsencrypt` instead.
10. And finally, run the command `sudo make deploy` to start everything up. You should run this command instead of using
    Docker Compose directly (because it specifies the correct configuration file; Docker Compose by default will use all
    configuration files for a development environment instead of a specific file for a production server).

You now have a blank WordPress installation running on the server. All WordPress files are located at `/srv/public`.

## Setting Up WordPress

- WordPress themes should be installed by unzipping into the folder: `/srv/public/wp-content/themes`.
- WordPress plugins should be installed by unzipping into the folder: `/srv/public/wp-content/plugins`.
  - To make use of AWS' SES service to send emails, install the plugin [Offload SES Lite](https://wordpress.org/plugins/wp-ses/).
  - To make use of AWS' S# service to store uploads, install the plugin [Offload Media](https://deliciousbrains.com/wp-offload-media/).
    Currently, the website is using a paid version of the plugin, ask Zan for details on how to download the plugin and
    its license.

> The website will not have any content, consider using the `make restore-backup` command to install a previous version 
> of the website's content.

## Maintenance

There are a few commands for website maintenance:

- `make database-backup` creates a backup of the database and attempts to upload it to S3 for safe keeping (which
  according to life cycle rules on the S3 bucket, will be kept for 90 days), these backups can then be restored if
  needed with the `make restore-backup` command.
- SSL certificates from Let's Encrypt are only valid for 3 months, the `make renew-certs` commands checks to see if the
  SSL certificate is expiring, and attempts to fetch and install a new one if required.

> To enable the `make database-backup` and `make renew-certs` commands to be run automatically every day, run:
> `sudo make install-cron`
