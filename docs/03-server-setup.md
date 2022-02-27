# Setting up the server

> **Note:** when the path to a file begins with a tilde `~` it means the current
> user's home directory. Because we will be logging in to the user `ubuntu` this
> means that the tilde is a shortcut to `/home/ubuntu`.

## Logging In to the Server

You will need:
- The IP address of the EC2 instance [you've just created](./02-ec2-instance.md)
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

### SSH Keypairs

Some repositories (such as the WordPress theme) are private, so we must be able
to identify the server as trusted. GitHub has a restriction where we can only
use one keypair per repository, the following is a kinda hacky way where we can
specify which keypair to use for which repository.

#### Deploy Key

First, we need a keypair for deploying the `docker-wordpress` repository, which
contains everything needed to get the server software up and running. First,
create the keypair (this will create two files: `~/.ssh/deploy` and
`~/.ssh/deploy.pub`).

```shell
# Create an SSH keypair called "deploy" in the default SSH directory, of type
# ED25519 (modern and secure), with no password (so it can be used automatically
# without a user typing in the password), with a comment describing its usage.
ssh-keygen -q -t "ed25519" -f "${HOME}/.ssh/deploy" -N"" -C "EC2 Production Server Deploy Key"
```

Add the following to the bottom of `~/.ssh/config` (create the file if it does
not exist).

```
Host github-tpb-deploy
    Hostname github.com
    IdentityFile=/home/ubuntu/.ssh/deploy.pub
```

And finally, copy the contents of `~/.ssh/deploy.pub` and add it as a [new
Deploy Key for the `docker-wordpress` GitHub
project](https://github.com/tpbrighton/docker-wordpress/settings/keys/new) (leave
the _Allow write access_ tick box **unchecked**).

#### Backup Key

First, we need a keypair for backing up plugins and themes to the
`wordpress-content` repository. First, create the keypair (this will create two
files: `~/.ssh/backup` and `~/.ssh/backup.pub`).

```shell
# Create an SSH keypair called "backup" in the default SSH directory, of type
# ED25519 (modern and secure), with no password (so it can be used automatically
# without a user typing in the password), with a comment describing its usage.
ssh-keygen -q -t "ed25519" -f "${HOME}/.ssh/backup" -N"" -C "EC2 Production Server Backup Key"
```

Add the following to the bottom of `~/.ssh/config`.

```
Host github-tpb-backup
    Hostname github.com
    IdentityFile=/home/ubuntu/.ssh/backup.pub
```

And finally, copy the contents of `~/.ssh/backup.pub` and add it as a [new
Deploy Key for the `wordpress-content` GitHub
project](https://github.com/tpbrighton/wordpress-content/settings/keys/new) (make
sure _Allow write access_ is **enabled**).

### Setup Website Project on Server

Back on the server:

> If a command asks you to retry as the root user or with the sudo command, try
> the command again but add the word `sudo` at the beginning.

1. Create a directory to hold the project, industry best practices suggest using
   `/srv` because this server will be serving a website: `sudo mkdir /srv`
2. Make sure that the current user owns it: `sudo chown -R "$(whoami):$(whoami)" /srv`
3. Clone the project from GitHub into the directory we just made:
   `git clone "git@github-tpb-deploy:tpbrighton/docker-wordpress.git" /srv`
   - Here we are specifying the hostname to be `github-tpb-deploy` which
     according to the config we made above means "fetch from `github.com` but
     use the deploy keypair for authentication".
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

To set up the website we need to restore both the _database_ and _themes and
plugins_ from backup.

### Themes and Plugins

Clone the [`wordpress-content`](https://github.com/tpbrighton/wordpress-content)
repository into WordPress' content directory. According to this documentation
that should be `/srv/public/wp-content`.

```shell
# The following is a work-around to clone a Git repository into a non-empty
# directory without affecting existing content.

# Here we are specifying the hostname to be "github-tpb-backup" which according
# to the config we made above means "fetch from github.com but use the backup
# keypair for authentication".
git clone --no-checkout --no-hardlinks "git@github-tpb-backup:tpbrighton/wordpress-content.git" "/tmp/wordpress-content"
mv "/tmp/wordpress-content/.git" "/srv/public/wp-content/.git"
rm -rf "/tmp/wordpress-content"
git -C "/srv/public/wp-content" reset --hard HEAD
```

> **Note:** the WordPress plugin for storing media in an S3 bucket is [Offload
> Media](https://deliciousbrains.com/wp-offload-media/); currently the website
> is using a paid version of the plugin licensed to Zan Baldwin.
> The plugin and license should be included in the backups but if in the future
> it is no longer viable to use this commercial plugin then
> [`humanmade/s3-uploads`](https://github.com/humanmade/s3-uploads) is a free
> (open-source) alternative, but harder to configure.

### PHP Settings

Put the following into the `/srv/public/wp-config.php` file. These settings are
responsible for ensuring that uploaded photos and media are backed up to the
[`tpbwp` S3 media bucket](https://s3.console.aws.amazon.com/s3/buckets/tpbwp).

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

### Database

Restoring a database backup requires you specifying the filename of a backup.
Backup files are stored in the [`tpbdb`](https://s3.console.aws.amazon.com/s3/buckets/tpbdb)
S3 bucket. These files will likely named something like:
`tpb-database-<date>T<time>.sql.bz2`
 
> Usually, you'd take a look through the S3 bucket and use the filename of the
> most recent upload. However, be aware of the size of the file - if the latest
> files are significantly smaller than previous ones it might mean that backup
> process was backing up an empty database without realising. Use your judgement
> to pick a file where the filesize looks appropriate.

Once you have the name of a backup file you'd like to restore, run the following
command and follow the prompts:

```shell
sudo make restore-backup
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
