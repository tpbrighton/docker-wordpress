# Setting up an EC2 Instance

Log in to the [AWS Management Console](https://console.aws.amazon.com).

In the top right (next to "support") is the **region** (eg, _London_ or _Frankfurt_). Make sure that this region is
correctly set - Trans Pride Brighton is a UK charity so unless there has been a management decision to change this, the
region should be set to **London** (`eu-west-2`).

## S3 (Simple Storage Service)

Head to [S3](https://s3.console.aws.amazon.com "Simple Storage Service") by finding it in the services dropdown or by
searching for it.

### Media Bucket

This bucket will hold all media for the website (everything that gets uploaded to the website; images, documents, etc).

1. Click [**Create Bucket**](https://s3.console.aws.amazon.com/s3/bucket/create).
2. Enter a name; this must be unique. The default name for this bucket is `tpbwp` and will be referenced as such for the
   rest of this documentation.
3. We want visitors to the website to view the media we upload, so:
   - Untick the **Block _all_ public access** checkbox, and
   - Tick the checkbox in the warning dialogue that appears.
4. Leave all other options as their default settings, and
5. Click **Create bucket** to confirm creation.

### Database Bucket

This bucket will hold daily database backups.

1. Click [**Create Bucket**](https://s3.console.aws.amazon.com/s3/bucket/create).
2. Enter a name; this must be unique. The default name for this bucket is `tpbdb` and will be referenced as such for the
   rest of this documentation.
3. Database backups are private and we want to prevent unauthorized access; ensure that the **Block _all_ public
   access** remains ticked.
4. Under **Bucket Versioning**, tick the _Enable_ option.
5. Leave all other options as their default settings, and
6. Click **Create bucket** to confirm creation.

Now the bucket is created, some extra settings need altering.

1. From the [S3 homepage](https://s3.console.aws.amazon.com), click the name of the
   [`tbpdb`](https://s3.console.aws.amazon.com/s3/buckets/tpbdb) bucket.
2. Click on the [Management tab](https://s3.console.aws.amazon.com/s3/buckets/tpbdb?tab=management).
3. Under the **Lifecycle rules** section, [create lifecycle
   rule](https://s3.console.aws.amazon.com/s3/management/tpbdb/lifecycle/create).
   - Give the rule a name, eg `KeepBackupsForNinetyDays`.
   - The _rule scope_ should **apply to _all_ objects in the bucket**.
   - Under _Lifecycle rule actions_, select:
     - **Expire _current_ versions of objects**, and
     - **Permanently delete _previous_ versions of objects**.
   - Under _Expire current versions of objects_ enter `90` for the number of days after object creation.
   - Under _Permanently delete previous versions of objects_ enter `90` for the Number of days after objects become
     previous versions.
   - Click **Create rule**.

## SES (Simple Email Service)

The default email sending capabilities of WordPress are, quite frankly, a more expressive word for _unsatisfactory_. By
enabling SES, we can send emails from any `@transpridebrighton.org` email address that are both reliable and verified
(less likely to be sent to spam or marked as suspicious).

Head to SES by finding it in the services dropdown or by searching for it.

### Verify Domain

1. Go to the **Domains** section in the sidebar.
2. Click the **Verify a New Domain** button.
3. For the domain, enter `transpridebrighton.org` and tick the **Generate DKIM Settings** before clicking the **Verify
   This Domain** button.
4. A popup should appear with DNS settings you'll have to set for the domain `transpridebrighton.org`.
   - These settings can be viewed again after being dismissed by selecting the domain and clicking the **View Details**
     button.
5. The domain's DNS settings are currently managed by Cloudflare. Log in to the [Cloudflare
   dashboard](https://dash.cloudflare.com), select the [`transpridebrighton.org`
   domain](https://dash.cloudflare.com/fe1d1486459c4a8a006f2f46f1446acc/transpridebrighton.org), and select the [DNS
   tab](https://dash.cloudflare.com/fe1d1486459c4a8a006f2f46f1446acc/transpridebrighton.org/dns).
   - Create a new `TXT` record as instructed by SES (the record name will likely be `_amazonses.transpridebrighton.org`).
   - Enter the 3 `CNAME` records as instructed by SES (make sure you enter all 3 as the third one is usually hidden, so
     you'll have to scroll to view it).

### Request Production Access

By default, SES is put into sandbox mode which means you can send a maximum of zero emails to people outside your
organization (your organization means people with a `@transpridebrighton.org` email address). We need to request a limit
increase by submitting a support case.

1. Head to the [AWS Support Center](https://console.aws.amazon.com/support/home).
2. Click the button to **Create case**.
3. Select **Service limit increase**.
4. Under _Case details_, select **SES Sending Limits** from the dropdown.
5. Under _Mail Type_, select **Transactional** from the dropdown.
6. Under _Website URL_, enter `https://transpridebrighton.org` (this is assuming the website is already up and running;
   if setting up the website for the first time get the server up and running before requesting a limit increase as a
   proven purpose for usage helps the case get approval).
7. Under _Describe, in detail, how you will only send to recipients who have specifically requested your mail_, enter
   **Will only send confirmation and invoice/receipt emails to users that have used the online shop.**
8. Under _Describe, in detail, the process that you will follow when you receive bounce and complaint notifications_,
   enter **By following GDPR, removing the personally-identifying information (emails) that have expired their original
   purpose.**
9. Under _Will you will comply with AWS Service Terms and AUP_, enter **Yes**.
10. Under the _Requests_ section, select:
    - The _Region_ decided by management, which this documentation assumes to be **EU (London)**.
    - The _Limit_ to be **Desired Daily Sending Quota**.
    - The _New limit value_ to be around 3 or 4 times the number of emails you expect to send in a day. For example,
      this value is currently set to `250` (we'll run into supply problems long before that limit needs increasing
      again).
11. Set the _Case description_ to something simple and direct such as **We have a web shop. We need to send purchase
    confirmations and receipts.**
12. **Submit** the support case.

AWS support will likely deal with the support case within a few days. They do not send notifications that they have
dealt with the support case, so you'll have to log in to the AWS Support Center periodically to check the status of the
support case.

## IAM (Identity and Access Management)

IAM defines the authorisation of who can access what services.

### Policies

Go to the **Policies** section in the sidebar. This will contain hundreds of AWS-managed policies (indicated by an
orange-yellow icon by the policy name).

#### Media Policy

The media policy will permit read and write access to the media S3 bucket (including knowing which region the bucket is
in, modifying whether the public are allowed to view media files, creating the bucket if it does not already exist, etc).

1. Click **Create policy** button.
2. Switch to the **JSON** tab.
3. Copy and paste the content below into the editor, replacing the default contents.
4. Click **Next: Tags**.
5. Click **Next: Review** (we don't want to add any tags).
6. For the policy _Name_, enter a unique name (the rest of the documentation will assume you entered
   `S3WordPressMediaBucket`).
7. Click **Create policy**.

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "BucketLevel",
            "Effect": "Allow",
            "Action": [
                "s3:GetBucketPublicAccessBlock",
                "s3:PutBucketPublicAccessBlock",
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": "arn:aws:s3:::tpbwp"
        },
        {
            "Sid": "ObjectLevel",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject",
                "s3:PutObjectAcl"
            ],
            "Resource": "arn:aws:s3:::tpbwp/*"
        },
        {
            "Sid": "S3Level",
            "Effect": "Allow",
            "Action": "s3:ListAllMyBuckets",
            "Resource": "*"
        }
    ]
}
```

> If you chose a name other than `tpbwp`, update the policy JSON code to match the name you chose.

#### Database Policy

The database policy will permit read and write access to the database S3 bucket. It will allow the uploading of database
backups, the reading of those database backups to perform restores, but it will not allow deleting of existing backups.
If you remember when creating the database bucket, versioning was enabled - this means that if a database backup is
uploaded with the same name as a previous backup, a new _version_ of that file is created instead of _replacing_ that
file.

1. Click **Create policy** button.
2. Switch to the **JSON** tab.
3. Copy and paste the content below into the editor, replacing the default contents.
4. Click **Next: Tags**.
5. Click **Next: Review** (we don't want to add any tags).
6. For the policy _Name_, enter a unique name (the rest of the documentation will assume you entered
   `S3WordPressDatabaseBucket`).
7. Click **Create policy**.

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "BucketLevel",
            "Effect": "Allow",
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::tpbdb"
        },
        {
            "Sid": "ObjectLevel",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject"
            ],
            "Resource": "arn:aws:s3:::tpbdb/*"
        }
    ]
}
```

> If you chose a name other than `tpbdb`, update the policy JSON code to match the name you chose.

### Roles

Policies can be attached to _identities_ (a user, a group, or a role). A role can be attached to various services,
including an EC2 instance (server) that we will be using.

Go to the **Roles** section in the sidebar. This will contain hundreds of AWS-managed policies (indicated by an
orange-yellow icon by the policy name).

1. Click **Create role**.
2. Select the _type of trusted entity_ to be an **AWS service**.
3. Select the _use case_ to be **EC2**.
4. Click **Next: Permissions**.
5. Attach the policies that we need:
   - Both of the policies that we created:
     - **S3WordPressMediaBucket**, and
     - **S3WordPressDatabaseBucket**.
   - An AWS-managed policy called **AmazonSESFullAccess**.
6. Click **Next: Tags**.
7. Click **Next: Review** (we don't want to add any tags).
8. For the _Role name_, enter a unique name (the rest of the documentation will assume you entered `WordPressOnEC2`).
9. Click **Create role**.

## EC2 (Elastic Compute Cloud)

EC2 is the core of AWS. EC2 instances are servers.

Head to EC2 by finding it in the services dropdown or by searching for it.

### Key Pair

1. Head to **Key Pairs** (under **Network & Security**) in the sidebar.
2. Click **Create key pair**.
3. Give the key pair a name. For example, I called mine `AWSLondonDefault` since it would be the default keypair used
   when setting up EC2 instances in the London (`eu-west-2`) region.
4. Select the `pem` file format, as this documentation assumes you'll be using a *nix-based operating system such as
   Linux or macOS. `ppk` file format is for Windows which is not supported by this documentation (because I have no idea
   how to use it).
5. Click **Create key pair**.
6. This will automatically start a download for a file called `AWSLondonDefault.pem` - this is a private key. **DO NOT
   LOSE THIS FILE. YOU WILL NOT BE ABLE TO DOWNLOAD IT AGAIN.**

### Security Groups

Head to **Security Groups** (under **Network & Security**) in the sidebar.

#### Default Security Group

There will be a security group that already exists with the _Security group name_ as `default`. This default security
group cannot be deleted. It allows all traffic in or out, which is not ideal.

1. Hover over the security group _Name_ (which should just be a dash) to show the edit button. Enter **Internet Access**
   as the name and click **Save**.
2. With the security group selected, click the **Actions** dropdown menu and select **Edit inbound rules**. Delete the
   existing rule and click **Save rules**.
3. With the security group selected, click the **Actions** dropdown menu and select **Edit outbound rules**. Change the
   _Destination_ from **Custom** to **Anywhere** and click **Save rules**.

#### Additional Security Groups

Now we want to create some of our own security groups.

The following two sections (**Web Traffic** and **SSH Access**) contain the information needed to create a security
group. Follow the instructions, substituting this information when necessary.

1. Click **Create security group**.
2. Enter an appropriate _Security group name_, ideally the section title (either **Web Traffic** or **SSH Access**).
3. A _Description_ is required, just enter the _Security group name_ again.
4. For each row in the table, create a new _Inbound rule_:
    - Enter the _Port range_ from the table,
    - Change the _Source_ from **Custom** to **Anywhere**, and
    - Enter the _Description_.
5. Delete any _Inbound rules_ (as outbound rules are covered by the default security group).
6. Click **Create security group**.
7. Hover over the security group _Name_ (which should just be a dash) to show the edit button. Enter the section title
   as the name and click **Save**. This will make it easier later on when referencing security groups from other parts
   of the management console.

##### Web Traffic

| Port Range | Inbound Rule Description |
|------------|--------------------------|
| `80`       | Unsecured Web Traffic    |
| `443`      | Secured Web Traffic      |

##### SSH Access

| Port Range | Inbound Rule Description |
|------------|--------------------------|
| `22`       | Secure Shell             |

### Elastic IP

Each EC2 instance has its own IP address. If you start a new server it will have a different IP address.
Elastic IP addresses are IP addresses that you "reserve". Once you have reserved an IP address, you can allocate it to
an EC2 instance. If you want to change your server you can reallocate your reserved IP address to that new server.

1. Head to **Security Groups** (under **Network & Security**) in the sidebar.
2. Click **Allocate Elastic IP address**.
3. Leave all settings as they are, click **Allocate**.
4. Back in Elastic IPs overview page, hover over the _Name_ of the Elastic IP you just allocated (should just be a dash)
   to show the edit button. Enter the domain (`transpridebrighton.org`).

> You are only changed for an Elastic IP if you are not using it (not attached to an EC2 instance). This is to prevent
> people from hogging IP addresses.

### Instances

We're now ready to start up a server!

1. Head to **Instances** (under **Instances**) in the sidebar.
2. Click **Launch Instances**.
3. Choosing an Amazon Machine Image:
   - By default, the latest Ubuntu Server should be near the top. Select that one, making sure **x86** is checked.
   - Otherwise, you'll want to make sure you have:
     - The latest [LTS release](https://wiki.ubuntu.com/Releases) of **Ubuntu Server** (currently that's **20.04**).
     - 64-bit architecture
       - Look for **AMD**, or **amd64**, or **x86**.
       - Do **NOT** pick ARM, or arm64.
4. Choosing an Instance Type:
   - Short answer: choose a **`t3a.small`**.
   - Long answer: the **t**-series is well suited for hosting a website, and higher the generation number (`t2`, `t3`,
     etc) the better. But be aware that some generations (like the `t4g`) use ARM-based architecture instead of
     AMD-based architecture which are incompatible with the server software we wish to use. See [AWS Instance
     Types](https://aws.amazon.com/ec2/instance-types/) for more information.
   - Click **Next: Configure Instance Details**
5. Configuring Instance Details:
   - Tick the **Protect against accidental termination** checkbox.
   - Click **Next: Add Storage**.
6. Adding Storage:
   - Change the _Size (GiB)_ to `12`.
   - Untick **Delete on Termination** checkbox.
   - Click **Next: Add Tags**.
7. Click **Next: Configure Security Groups** (we don't want to add tags).
8. Configuring Security Groups:
   - Instead of creating a new security group, choose **Select an _existing_ security group**
   - Select the security groups we created earlier: **Web Traffic**, **SSH Access**, and **default**.
   - Click **Review and Launch**.
9. Click **Launch**, then **View Instances**.
10. Now back in the Instances overview page, hover over the _Name_ of the instance you just created to show the edit
    button. Enter an appropriate name for the instance (I recommend the domain of the website the server will be serving
    so for this instance `transpridebrighton.org`) and click **Save**.

The server will now be booting up and will be ready momentarily. In the meantime:

1. Select the instance and click the **Actions** dropdown menu.
   - Go to **Security → Modify IAM role**.
   - Select the **WordPressOnEC2** role from the dropdown list.
   - Click **Save**.
2. Head to **Elastic IPs** (under **Network & Security**) in the sidebar.
   - Select the Elastic IP we allocated earlier.
   - Click the **Actions** dropdown menu, and select **Associate Elastic IP address**.
   - Select the _Instance_ (it should be the only one that comes up).
   - Click **Associate**.

### Logging In

You will need:
- The IP address of the EC2 instance you've just created (this will be the elastic IP if you assigned one to the
  instance), and
- The path to the private key file you downloaded earlier when making a key pair.

```shell
ssh "ubuntu@<IP_ADDRESS>" -i "<KEY_FILE>"
```

For example, in my case this would be:

```shell
ssh "ubuntu@35.177.199.22" -i "~/.ssh/AWSLondonDefault.pem"
```

> Once the EC2 instance (server) is set up, you can add additional (eg, your own) public key to `~/.ssh/authorized_keys`

### Reserved Instances

Reserved instances allow for cost savings by committing to using an EC2 instance for a minimum contracted time instead
of "on-demand". A reserved instance does not create an EC2 instance - instead, once purchased, is used as "credit"
towards currently running instances.

- You cannot change the instance type you intend to run once purchased.
- You cannot change the contract length once purchased.
- There is no (practical) way to get a refund for a purchase order (you are saving money because you are guaranteeing
  use of AWS' services, refunds would defeat the purpose of those guarantees).

Basically, purchase orders are a cost-saving plan to research _thoroughly_ once everything else is done. They are
**not** something to play around with. I learnt the hard way that accidentally selecting the wrong option by mistake is
an easy way to waste a lot of money very quickly.

## Domain

### Pointing the Domain at the EC2 Instance

> This assumes you are setting up a new server, and the domain you want to use does not currently point to a working
> website.

### Domain Pointing to Old Version of Website?

If the domain is already pointing to an existing version of the website (you are moving servers) then things become more
tricky - you want to have the website setup on the new server before you switch the domain over, otherwise people won't
be able to access the website while you're setting up the new server. But you can't request a new SSL certificate
without the domain pointing to the new server.

However, this will make obtaining a valid SSL certificate tricky. One work-around is to copy the contents of the
directory `/etc/letsencrypt` from the old server to the new server. It's generally ill-advised, but it works.

> The following instructions are **dangerous** as you'll be granting access to the `root` user. Proceed with caution.

> The IP address of the old server can be found with:
> - `curl "http://169.254.169.254/latest/meta-data/public-ipv4"` if the old server is an AWS EC2 instance.
> - Otherwise you'd have to look it up in the DNS configuration (if using Cloudflare the IP of the server may be
>   different to the IP that the domain resolves to).

- On the _new_ server, create an SSH keypair: `sudo ssh-keygen -t ed25519 -f "/root/.ssh/id_ed25519"`
- On the _new_ server, copy the contents of `/root/.ssh/id_ed25519.pub`
- On the _old_ server, paste that into a new line in `/root/.ssh/authorized_keys`
- On the _old_ server, ensure that `PermitRootLogin` is either commented out or not set to `no`, in `/etc/ssh/sshd_config`
- On the _new_ server, install `rsync` if it isn't already: `sudo apt install -y rsync`
- On the _new_ server, switch to the `root` user: `sudo su`
- On the _new_ server, synchronise SSL certificates from the old server to the new server:<br>
  `rsync --archive --whole-file --one-file-system "root@<old-server-ip-addr>:/etc/letsencrypt" /etc/letsencrypt`
- On the _old_ server, delete the line in `/root/.ssh/authorized_keys` that you added

This method could also be used to synchronise the WordPress installation on the old server to the new server, by
replacing `/etc/letsencrypt` by `/srv/public` (assuming that's where it's installed).
