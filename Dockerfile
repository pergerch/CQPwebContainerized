FROM ubuntu:jammy

RUN apt-get update && apt-get upgrade -y

RUN mv /etc/lsb-release /etc/lsb-releaseA

ENV TZ=Europe/Vienna
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# INSTALL & CONFIGURE Apache, PHP, MySQL, R
RUN apt-get install lsb-core apache2 mysql-server r-base -y

RUN apt-get install php php-bz2 php-intl php-gd php-mbstring php-mysql php-zip php-mysqli -y

RUN	cp /etc/php/8.1/apache2/php.ini /etc/php/8.1/apache2/php.ini.bak && \
	sed -i 's,^upload_max_filesize =.*$,upload_max_filesize = 25M,' /etc/php/8.1/apache2/php.ini && \
	sed -i 's,^post_max_size =.*$,post_max_size = 25M,' /etc/php/8.1/apache2/php.ini && \
	sed -i 's,^memory_limit =.*$,memory_limit = 512M,' /etc/php/8.1/apache2/php.ini && \
	sed -i 's,^max_execution_time =.*$,max_execution_time = 90,' /etc/php/8.1/apache2/php.ini && \
	sed -i 's,^;mysqli.allow_local_infile =.*$,mysqli.allow_local_infile = On,' /etc/php/8.1/apache2/php.ini

WORKDIR /var/www/html

RUN rm index.html

RUN mkdir /cwb && \
	mkdir /cqpweb && \
	mkdir /cqpweb/tempdir && \
	mkdir /cqpweb/uploaddir && \
	mkdir /cqpweb/datadir && \
	mkdir /cqpweb/registry && \
	chmod -R 777 /cwb && \
	chmod -R 777 /cqpweb && \
	chmod -R 777 /var/www/html

WORKDIR /cwb

RUN apt-get install subversion -y

RUN svn checkout -r 1871 https://svn.code.sf.net/p/cwb/code/cwb/release/3.5.0/ .

RUN ./install-scripts/install-linux

# obsolete: ENV PATH "$PATH:/usr/local/bin"
RUN echo PATH="$PATH" >> /etc/apache2/envvars

WORKDIR /var/www/html

RUN svn checkout -r 1871 https://svn.code.sf.net/p/cwb/code/gui/cqpweb/branches/3.2-latest/ .

RUN echo "<?php" > ./lib/config.inc.php
RUN echo "\$superuser_username = 'bob';" >> ./lib/config.inc.php

RUN echo "\$mysql_webuser = 'cqpweb';" >> ./lib/config.inc.php
RUN echo "\$mysql_webpass = 'cqpweb';" >> ./lib/config.inc.php
RUN echo "\$mysql_schema = 'cqpwebdb';" >> ./lib/config.inc.php
RUN echo "\$mysql_server = '127.0.0.1:3306';" >> ./lib/config.inc.php

RUN echo "\$cqpweb_tempdir = '/cqpweb/tempdir';" >> ./lib/config.inc.php
RUN echo "\$cqpweb_uploaddir = '/cqpweb/uploaddir';" >> ./lib/config.inc.php
RUN echo "\$cwb_datadir = '/cqpweb/datadir';" >> ./lib/config.inc.php
RUN echo "\$cwb_registry = '/cqpweb/registry';" >> ./lib/config.inc.php

WORKDIR /var/www/html/bin

RUN usermod -d /var/lib/mysql/ mysql

RUN chown -R mysql:mysql /var/lib/mysql && \
    service mysql start && \
	mysql -e "create database cqpwebdb default charset utf8mb4;" && \
	mysql -e "create user cqpweb identified by 'cqpweb';" && \
	mysql -e "grant all on cqpwebdb.* to cqpweb;" && \
	mysql -e "grant file on *.* to cqpweb;" && \
	printf "bob\nY\n" | php autosetup.php

# Copy and rename wrapper script
RUN apt-get install dos2unix -y
COPY wrapper.sh /wrapper.sh
RUN chmod +x /wrapper.sh
WORKDIR /
RUN dos2unix wrapper.sh

EXPOSE 80 3306

ENTRYPOINT ["/wrapper.sh"]