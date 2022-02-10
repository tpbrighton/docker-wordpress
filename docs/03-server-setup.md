# Setting up the server

## Logging In to the Server

You will need:
- The IP address of the EC2 instance [you've just created](./03-ec2-instance.md)
  (this will be the elastic IP if you assigned one to the instance), and
- The path to the private key file you downloaded earlier when making a key pair.

```shell
ssh "ubuntu@<IP_ADDRESS>" -i "<KEY_FILE>"
```

For example, in my case this would be:

```shell
ssh "ubuntu@35.177.199.22" -i "~/.ssh/AWSLondonDefault.pem"
```

> Once the EC2 instance (server) is set up, you can add additional (eg, your
> own) public key to `~/.ssh/authorized_keys`

## Required Software

### Update Existing Software

This could take up to 10 minutes, ish.

```shell
sudo apt update
sudo apt dist-upgrade -y
```

### Packaged Software

Once logged into the server, run the following command to install the required
software (`git`, `make`, `openssl` and `ssh`) to download and setup the website:

```shell
sudo apt install -y git make openssl ssh
```

### Timezone

The default timezone of the server may not be correct according to the charity,
run the following command to make sure:

```
sudo timedatectl set-timezone 'Europe/London'
```

## Installing the (Website) Project

### Create SSH Keypair

Some repositories (such as the WordPress theme) are private, so we must be able
to identify the server as trusted. Create a new SSH keypair with the command:

```
ssh-keygen -t ed25519 -C "EC2 Production Server Deploy Key"
```

Don't enter a password. The contents of the newly created file
`~/.ssh/id_ed25519.pub` will be required later on.

### Setup Website Project on Server

Back on the server:

> If a command asks you to retry as the root user or with the sudo command, try
> the command again but add the word `sudo` at the beginning.

1. Create a directory to hold the project, industry best practices suggest using
   `/srv` because this server will be serving a website: `sudo mkdir /srv`
2. Make sure that the current user owns it: `sudo chown -R "$(whoami):$(whoami)" /srv`
3. Clone the project from GitHub into the directory we just made:
   `git clone "git@github.com:tpbrighton/docker-wordpress.git" /srv`
4. The rest of the instructions have been scripted into the project, so change
   into the project directory: `cd /srv`
5. Install Docker (which is what will "contain" the website software that runs
   WordPress): `sudo make install-docker`
6. Install Let's Encrypt (software for generating SSL certificates):
   `sudo make install-letsencrypt`
7. Make sure that the project-specific variables at the top of the `/srv/Makefile`
   are correct, especially the `DOMAIN` variable. The rest are sensible defaults,
   but also check that the email addresses to notify on error are also correct.
8. Build the individual containers (PHP, Database, etc); _this may take a while_:
   `sudo make build-images`
9. Fetch a fresh installation of WordPress itself: `make fetch-wordpress`
10. Get Let's Encrypt to generate SSL certificates for the website:
    `sudo make enable-https`
    - This assumes that the specified domain (eg, `transpridebrighton.org`) is
      already pointing to the server, do not run this command if you're trying
      to transfer the website from one server to another without any downtime.
      Rsync the contents of `/etc/letsencrypt` instead.
11. And finally, run the command `sudo make deploy` to start everything up. You
    should run this command instead of using Docker Compose directly (because it
    specifies the correct configuration file; Docker Compose by default will use
    all configuration files for a development environment instead of a specific
    file for a production server).

You now have a blank WordPress installation running on the server. All WordPress
files are located at `/srv/public`.

## Setting Up WordPress

- WordPress themes should be installed by unzipping into the folder:
  `/srv/public/wp-content/themes`.
  - Please see `https://github.com/tpbrighton/maisha-wordpress-theme` repository
    for the original theme currently in use (repository is private because it's
    a paid-for theme, please see Zan Baldwin or Michelle Steele for access). 
- WordPress plugins should be installed by unzipping into the folder:
  `/srv/public/wp-content/plugins`.
  - To make use of AWS' SES service to send emails, install the plugin
    [Offload SES Lite](https://wordpress.org/plugins/wp-ses/).
  - To make use of AWS' S# service to store uploads, install the plugin
    [Offload Media](https://deliciousbrains.com/wp-offload-media/). Currently,
    the website is using a paid version of the plugin, ask Zan for details on
    how to download the plugin and its license.

> The website will not have any content, consider using the `make restore-backup`
> command to install a previous version of the website's content.

Put the following into the `wp-config.php` file:

```php
// Enable auto-authorization for "Offload SES Lite" plugin.
define('WPOSES_AWS_USE_EC2_IAM_ROLE', true);
// Hard-coded configuration settings for "WP Offload Media" plugin.
define('AS3CF_SETTINGS', serialize([
    'provider' => 'aws',
    'use-server-roles' => true,
    'copy-to-s3' => true,
    'remove-local-file' => true,
    'serve-from-s3' => true,
    'enable-object-prefix' => false,
    'force-https' => true,
    // Make sure the following values are correct from setup:
    'bucket' => 'tpbwp',
    'region' => 'eu-west-2',
]));
```

## Maintenance

### Database Backup

The database can be backed up with another Make command (assuming project was
installed to `/srv`). It will make a backup file and attempt to upload it to the
S3 bucket, it that fails it will tell the location of the backup on the server,
so you can copy it manually.

```shell
cd /srv
sudo make database-backup
```

### Renew SSL Certificates

SSL certificates from Let's Encrypt only valid for 3 months, so another Make
command checks to see if they're up for renewal and attempts to automatically
renew the SSL certificate if it is.

```shell
cd /srv
sudo make renew-certs
```

### Check Disk Usage

Although media are not stored on the server itself, disk usage may start to fill
up thanks to various pieces of software caching data (eg, WordPress caches
images that get edited even though they're not stored on the server). This Make
command checks that the disk usage is below 90% otherwise it attempts to send a
warning email to pre-configured email addresses.

```shell
cd /srv
# To change which email addresses get sent a warning email, edit the
# project-specific variables at the top of the Makefile.
sudo make check-disk-usage
```

## Automatic Maintenance

The `database-backup` and `renew-certs`, and `check-disk-usage` commands can be
run automatically, run the following Make command to install an automated CRON
job that will run all of these commands daily.

```shell
cd /srv
# To change which Makefile commands get installed as CRON, edit the
# project-specific variables at the top of the Makefile.
sudo make install-cron
```

> You may need to install the system package `anacron`, check the output of the
> `install-cron` command and if needed, run the command `sudo apt install anacron`.
