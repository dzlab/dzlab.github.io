---
layout: post
comments: true
title: Setup secure database access with SSH Tunnel
excerpt: Tips on how to setup a Postgresql database on GCP and secure access to it via SSH Tunnel.
categories: gcp
tags: [gcp,database,ssh]
toc: true
img_excerpt:
---


<img align="left" src="/assets/logos/icons8-google-cloud.svg" width="240" />
<img align="center" src="/assets/logos/icons8-postgresql.svg" width="200" />
<br/>

This article walks through how to setup a VM on GCP, a Postgres database and SSH tunneling from local machine to the database on the remove VM. 

## Setup VM
Create a new instance with Google Cloud CLI, a machine type `n1-standard-2` is enough but you can try other types like `n1-highmem-4` or `n1-highcpu-4`.
```
$ gcloud compute instances create databases --machine-type n1-standard-2 --zone us-central1-a
```

From the Google Console, Create a Firewall rule that will enable remote access to Postgres port.

<center><img alt="gcp firewall rule" src='https://i.stack.imgur.com/F0MC1.png' width='200' height='200'></center>


Once the VM is running, connect to it via SSH from Google Console and then create a user (e.g. `myadmin` with password `mypass`).
```
$  sudo adduser myadmin
Adding user `myadmin' ...
Adding new group `myadmin' (1002) ...
Adding new user `myadmin' (1001) with group `myadmin' ...
Creating home directory `/home/myadmin' ...
Copying files from `/etc/skel' ...
New password: 
Retype new password: 
passwd: password updated successfully
Changing the user information for myadmin
Enter the new value, or press ENTER for the default
        Full Name []: 
        Room Number []: 
        Work Phone []: 
        Home Phone []: 
        Other []: 
Is the information correct? [Y/n] 
```

For the user to be able to connect via SSH either manually upload a public key of this user or enabling connection with password by setting `PasswordAuthentication to yes` in `/etc/ssh/sshd_config`:
```
$ sudo vi /etc/ssh/sshd_config
PasswordAuthentication yes
$ sudo systemctl restart sshd
```

You can test the connection establishment from local machine with user `myadmin` with password `mypass`
```
$ ssh myadmin@external-ip
myadmin@external-ip's password: 
```

## Setup Postgres
First, install Postgres with `apt-get`

```
user@databases:~$ sudo apt-get -y install postgresql
user@databases:~$ sudo pg_ctlcluster 11 main start
user@databases:~$ sudo -u postgres psql -c "SELECT version();"
                                                     version                                                      
------------------------------------------------------------------------------------------------------------------
 PostgreSQL 11.14 (Debian 11.14-0+deb10u1) on x86_64-pc-linux-gnu, compiled by gcc (Debian 8.3.0-6) 8.3.0, 64-bit
(1 row)
```

After installing postgres an admin user `postgres` should be created, you can confirm with the following
```
user@databases:~$ sudo su - postgres
postgres@databases:~$ psql
psql (11.14 (Debian 11.14-0+deb10u1))
Type "help" for help.

postgres=# \q
postgres@databases:~$ exit
logout
```

We should not be using this admin user but instead create another user and give configure its privilege. For instance, create a user with admin privilege on a specific databse
```
user@databases:~$ sudo su - postgres -c "createuser myadmin"
user@databases:~$ sudo su - postgres -c "createdb database01"
user@databases:~$ sudo -u postgres psql
psql (11.14 (Debian 11.14-0+deb10u1))
Type "help" for help.

postgres=# GRANT ALL PRIVILEGES ON DATABASE database01 TO myadmin;
GRANT
postgres=# ALTER USER c3admin WITH PASSWORD 'mypass';
ALTER ROLE
```

We need to allow new user to authenticate to Postgres with a password by editing `pg_hba.conf`
```
user@databases:~$ sudo cat 'local   all             myadmin                                 md5' >> /etc/postgresql/11/main/pg_hba.conf 
sudo service postgresql restart
user@databases:~$ psql --port=5432 --username=myadmin --dbname=database01 --password 
Password: 
psql (11.14 (Debian 11.14-0+deb10u1))
Type "help" for help.
database01=> \q
```

Now we need to make Postgres accept connections from local machine, and also optionally from remote ones. The former, can be done by adding `listen_addresses = '*'` to `postgresql.conf` then restarting the service:
```
$ sudo vi /etc/postgresql/11/main/postgresql.conf 
$ sudo /etc/init.d/postgresql restart
[ ok ] Restarting postgresql (via systemctl): postgresql.service.
```
We also edit `pg_hba.conf` file
```
$ sudo vi /etc/postgresql/11/main/pg_hba.conf 
```
Add `host all all 0.0.0.0/0 md5` to `pg_hba.conf` to allow access to all databases for all users with an encrypted password:
```
# TYPE DATABASE USER CIDR-ADDRESS  METHOD
host  all  all 0.0.0.0/0 md5
```
After that restart service with `service postgresql restart`



## SSH Tunneling
Before anything check that the VM is reachble on the external IP and the SSH port accessible
```
$ nc -zv external-ip 22  
Connection to external-ip port 22 [tcp/ssh] succeeded!
```


From local machine establish tunnel with user `myadmin` and password `mypass`
```
$ ssh -L 63333:localhost:5432 myadmin@external-ip -N
myadmin@external-ip's password: 
```

Connect to the database from a different shell tab with user `myadmin` with password `mypass`
```
$ psql -h localhost -p 63333 --username=myadmin --dbname=database01 --password 
Password: 
psql (14.0, server 11.14 (Debian 11.14-0+deb10u1))
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
Type "help" for help.

database01=> \q
```

> Note: how we are connecting to the database using 'localhost' as if the database is running locally thanks to the established SSH Tunnel.