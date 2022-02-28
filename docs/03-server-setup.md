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

# For example, in my case this would be:
ssh "ubuntu@35.177.199.22" -i "~/.ssh/AWSLondonDefault.pem"
```

> Once the EC2 instance (server) is set up, you can add additional (eg, your
> own) public key to `~/.ssh/authorized_keys`
 
All the instructions in the rest of this document are intended to be performed
_on the webserver_. You should remain logged in via SSH when executing commands.

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

### SSH Keypair

The repository that holds a backup of the themes and plugins is private (because
it contains commercial code that we have licensed), so we must be able to
identify the server as trusted by generating a keypair. The following command
will create an SSH keypair of type ED25519 (modern and secure) in the default
location, without a passphrase (so it can be used automatically without user
input), with a comment describing its usage.

```shell
ssh-keygen -q -t "ed25519" -f "${HOME}/.ssh/id_ed25519" -N"" -C "EC2 Production Server Backup Key"
```

Copy the contents of the newly-created file `~/.ssh/id_ed25519.pub` and add it
as a [new Deploy Key for the `wordpress-content` GitHub
project](https://github.com/tpbrighton/wordpress-content/settings/keys/new) (make
sure _Allow write access_ is **enabled**).

> **Note:** the `cat` command will print out the contents of a file (eg,
> `cat ~/.ssh/id_ed25519.pub`).

### Setup Website Project on Server

> If a command asks you to retry as the root user or with the sudo command, try
> the command again but add the word `sudo` at the beginning.

1. Create a directory to hold the project, industry best practices suggest using
   `/srv` because this server will be serving a website: `sudo mkdir /srv`
2. Make sure that the current user owns it: `sudo chown -R "$(whoami):$(whoami)" /srv`
3. Clone the project from GitHub into the directory we just made:
   `git clone "git://github.com/tpbrighton/docker-wordpress.git" /srv`
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

git clone --no-checkout --no-hardlinks "git@github.com:tpbrighton/wordpress-content.git" "/tmp/wordpress-content"
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

### Backup Themes and Plugins

Records any changes or additions to themes and plugins (eg, upgrades), and
uploads those changes to the [`tpbrighton/wordpress-content` GitHub
repository](https://github.com/tpbrighton/wordpress-content).

**Note:** this command is _expected_ to fail if there have not been any changes
since the last backup.

```shell
cd /srv
# This assumes that the `tpbrighton/wordpress-content` GitHub repository has
# been cloned locally to `/srv/public/wp-content`, and that an SSH keypair has
# been generated and added as a writable Deploy key for that GitHub repository.
make backup-plugins-and-themes
```

## Automatic Maintenance

The `database-backup`, `renew-certs`, `check-disk-usage`, and
`backup-plugins-and-themes` commands can be run automatically, run the following
Make command to install an automated CRON job that will run all of these
commands daily.

```shell
cd /srv
# To change which Makefile commands get installed as CRON, edit the
# project-specific variables at the top of the Makefile.
sudo make install-cron
```

> You may need to install the system package `anacron`, check the output of the
> `install-cron` command and if needed, run the command `sudo apt install anacron`.
