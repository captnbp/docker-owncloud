# Owncloud AlpineLinux ##
## What is ownCloud?
[ownCloud](http://owncloud.org) is a self-hosted file sync and share server. It provides access to your data through a web interface, sync clients or WebDAV while providing a platform to view, sync and share across devices easily—all under your control. ownCloud’s open architecture is extensible via a simple but powerful API for applications and plugins and it works with any storage.
## How to use this image
###Start ownCloud
You may first need a MySQL database and a Redis server to improve performances :
```bash
docker run -d -v /<mydatalocation>/mariadb/data:/var/lib/mysql --name=mariadb mariadb
docker run -d --name=redis redis
```
Starting the ownCloud instance listening on port 80 is as easy as the following:
```bash
docker run -d -p 80:80 --link=mariadb:mariadb --link=redis:redis --name=owncloud owncloud
```
If you set Redis, you will need to edit the Owncloud config file :
```bash
docker exec -ti owncloud bash
sed -i -e "s/);/'memcache.local' => '\\\\OC\\\\Memcache\\\\Redis', 'memcache.distributed' => '\\\\OC\\\\Memcache\\\\Redis', 'memcache.locking' => '\\\\OC\\\\Memcache\\\\Redis', 'redis' => array('host' => 'redis', 'port' => 6379, ), );/" /usr/share/nginx/html/owncloud/config/config.php
```

###Persistent data
All data is stored within the default volume /var/www/html. With this volume, ownCloud will only be updated when the file version.php is not present.

    -v /<mydatalocation>:/var/www/html

For fine grained data persistence, you can use 3 volumes, as shown below.

    -v /<mydatalocation>/log:/var/log/nginx Nginx logs
    -v /<mydatalocation>/config:/usr/share/nginx/html/owncloud/config local configuration
    -v /<mydatalocation>/data:/usr/share/nginx/html/owncloud/data the actual data of your ownCloud

