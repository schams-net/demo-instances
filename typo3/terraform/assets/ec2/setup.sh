#!/bin/bash
# ==============================================================================

TIMER_START=$(date +"%s")
HOSTNAME_SHORT=$(hostname --short)
HOSTNAME_LONG=$(hostname --long)
CURRENT_DATE=$(date +"%Y%m%d")
TIMESTAMP=$(date +"%s")
PROCESS="$$"
STAGE=$1
PUBLIC_IP=$(ec2metadata --public-ip)

# Random password length
LENGTH=16

# Generate a random password
RANDOM_PASSWORD=$(openssl rand -base64 48 | sed 's/[^a-zA-Z0-9]//g' | cut -c 1-${LENGTH})

BE_ADMIN_USERNAME=admin
BE_ADMIN_PASSWORD=${RANDOM_PASSWORD}
BE_EDITOR_USERNAME=editor
BE_EDITOR_PASSWORD=${RANDOM_PASSWORD}
BE_EDITOR_USERGROUPS="1,2,3"

# Initial database access details
DATABASE_DBNAME=typo3demo
DATABASE_USERNAME=typo3demo
DATABASE_PASSWORD=123456

WWW_DIRECTORY=/var/www

TYPO3_CONSOLE="${WWW_DIRECTORY}/site/bin/typo3cms"
TYPO3_CLI_PARAMETERS="--no-ansi --no-interaction"

#export LC_CTYPE=en_US.UTF-8
#export LC_ALL=en_US.UTF-8
export DEBIAN_FRONTEND=noninteractive

output(){
	OUTPUT_TIMESTAMP=$(date +"%d/%b/%Y %H:%M:%S %Z")
	echo "[${OUTPUT_TIMESTAMP}] $1" | tee --append /tmp/setup.log
}

convertsecs(){
	((h=${1}/3600))
	((m=(${1}%3600)/60))
	((s=${1}%60))
	TIME_ELAPSED=$(printf "%02d hrs %02d mins %02d secs" $h $m $s)
}

# ------------------------------------------------------------------------------
# Stage 1
# ------------------------------------------------------------------------------

if [ "${STAGE}" = "" -o "${STAGE}" = "stage1" ]; then
	output "Stage 1: re-start script in the background"
	$0 "stage2" &
	exit 0
fi

# ------------------------------------------------------------------------------
# Stage 2
# ------------------------------------------------------------------------------

if [ "${STAGE}" = "stage2" ]; then
	output "Stage 2: waiting for cloud-config to finish"
	TEMP=""
	COUNT=1
	while [ "${TEMP}" = "" ]; do
		TEMP=$(tail -10 /var/log/cloud-init-output.log | egrep '^Cloud\-init.*finished.*seconds$')
		if [ "${TEMP}" = "" ]; then
			output "Still waiting... ${COUNT}"
			let COUNT=COUNT+1
			sleep 2
		else
			output "cloud-config finished"
			STAGE="stage3"
		fi
	done
fi

# ------------------------------------------------------------------------------
# Stage 3
# ------------------------------------------------------------------------------

output "Stage 3: basic system setup"

output "Configuring locales"
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen --purge en_US.UTF-8 > /dev/null
OUTPUT=$(dpkg-reconfigure --frontend=noninteractive locales 2>&1 > /dev/null)
update-locale LANG=en_US.UTF-8

output "Enabling \"contrib\" and \"non-free\" Debian packages"
sed -i -e 's/ main$/ main contrib non-free/g' /etc/apt/sources.list
apt-get --yes -qq update

output "Removing Debian package \"nano\""
apt-get --yes -qq remove nano > /dev/null

# Command-line YAML/XML processor
# https://kislyuk.github.io/yq/
output "Installing yq"
pip3 install yq

output "Adding files to /etc/skel/"
cat <<EOF > /etc/skel/.vimrc
"set mouse="
EOF

cat <<EOF > /etc/skel/.bash_aliases
# Alias definitions.
alias ll='ls -Al --color'
alias ..='cd .. ; pwd'
EOF

echo "content-disposition = on" >> /etc/wgetrc

if [ -r /tmp/assets/etc/init.d/system-start-stop ]; then
	output "Enabling system start/stop notifications"
	cp /tmp/assets/etc/init.d/system-start-stop /etc/init.d/system-start-stop
	chmod 755 /etc/init.d/system-start-stop
	update-rc.d system-start-stop defaults
fi

if [ -r /tmp/assets/etc/init.d/system-updates ]; then
	output "Enabling system updates on every instance start"
	cp /tmp/assets/etc/init.d/system-updates /etc/init.d/system-updates
	chmod 755 /etc/init.d/system-updates
	update-rc.d system-updates defaults
fi

VERSION_DEBIAN=$(cat /etc/debian_version)
SYSTEM_UNAME=$(uname -a)
SYSTEM_LSB_DESCRIPTION=$(lsb_release --short --description)

output "Copying files from /etc/skel/ to /home/admin/"
cp --recursive --preserve=all /etc/skel/. /home/admin/

output "Extending .bash_aliases for user \"admin\""
echo "alias apt-update='TODAY=\$(date +\"%d/%b/%Y %H:%M:%S\") ; clear ; echo \"Updating repository...\" ; sudo apt -qq update ; sudo apt -uV upgrade ; echo ; echo \"Last update: \${TODAY}\" ; echo'" >> /home/admin/.bash_aliases
chown -R admin: /home/admin

output "Configuring log rotation"
cat /etc/logrotate.d/rsyslog | grep -v "mail.log" | tee /etc/logrotate.d/rsyslog.new > /dev/null
# diff /etc/logrotate.d/rsyslog /etc/logrotate.d/rsyslog.new
mv /etc/logrotate.d/rsyslog.new /etc/logrotate.d/rsyslog

cat <<EOF | tee /etc/logrotate.d/mail > /dev/null
/var/log/mail.log
{
    rotate 9999
    daily
    dateext
    missingok
    notifempty
    compress
}

/var/log/procmail.log
{
    rotate 9999
    daily
    dateext
    missingok
    notifempty
    compress
}
EOF

#dpkg-reconfigure apt-listchanges
cat <<EOF | sudo debconf-set-selections
apt-listchanges	apt-listchanges/email-format	select	text
apt-listchanges	apt-listchanges/email-address	string	root
apt-listchanges	apt-listchanges/save-seen	boolean	true
apt-listchanges	apt-listchanges/frontend	select	mail
apt-listchanges	apt-listchanges/confirm	boolean	false
apt-listchanges	apt-listchanges/which	select	both
apt-listchanges	apt-listchanges/reverse	boolean	false
apt-listchanges	apt-listchanges/headers	boolean	false
apt-listchanges	apt-listchanges/no-network	boolean	false
EOF

#dpkg-reconfigure unattended-upgrades
cat <<EOF | sudo debconf-set-selections
unattended-upgrades	unattended-upgrades/enable_auto_updates	boolean	true
EOF

#vi /etc/apt/apt.conf.d/50unattended-upgrades
#
#> uncomment the following line:
#> Unattended-Upgrade::Mail "root";

# Clean-up
output "Cleaning up Debian repository and downloaded packages"
apt-get --yes autoremove 2>&1 > /dev/null
apt-get --yes purge 2>&1 > /dev/null
apt-get --yes clean 2>&1 > /dev/null
apt-get --yes autoclean 2>&1 > /dev/null

# ------------------------------------------------------------------------------
# Stage 4
# ------------------------------------------------------------------------------

output "Stage 4: configuring web environment and database"

curl -sL https://raw.githubusercontent.com/nvm-sh/nvm/v0.34.0/install.sh | bash

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

output "Downloading/installing Yarn"
curl --silent -o yarnpkg.gpg.pub https://dl.yarnpkg.com/debian/pubkey.gpg
apt-key --keyring /etc/apt/trusted.gpg.d/yarnpkg.gpg add yarnpkg.gpg.pub
echo "deb https://dl.yarnpkg.com/debian/ stable main" >> /etc/apt/sources.list.d/yarn.list
apt-get update
TERM=xterm-256color DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends yarn

VERSION_APACHE=$(dpkg-query --show --showformat '${Package}|${Version}\n' apache2 | tee --append /tmp/versions | cut -f 2 -d '|')
output "Apache version: ${VERSION_APACHE}"

VERSION_PHP=$(dpkg-query --show --showformat '${Package}|${Version}\n' php | tee --append /tmp/versions | cut -f 2 -d '|')
output "PHP version: ${VERSION_PHP}"

VERSION_MARIADB=$(dpkg-query --show --showformat '${Package}|${Version}\n' mariadb-server | tee --append /tmp/versions | cut -f 2 -d '|')
output "MariaDB version: ${VERSION_MARIADB}"

output "Adjusting Apache security settings"
cat /etc/apache2/conf-available/security.conf | sed "s/^ServerTokens\(.*\)$/#ServerTokens\1\nServerTokens Prod/g" | egrep -v '#ServerTokens.*' | sed "s/^ServerSignature\(.*\)$/#ServerSignature\1\nServerSignature Off/g" | egrep -v '#ServerSignature.*' > /etc/apache2/conf-available/security.conf.new
mv /etc/apache2/conf-available/security.conf.new /etc/apache2/conf-available/security.conf

#output "Updating SUexec configuration"
#sed -i -e 's/^\/var\//\/srv\//' /etc/apache2/suexec/www-data

output "Enabling Apache modules"
#a2enmod rewrite headers expires actions > /dev/null
a2enmod rewrite headers expires fcgid suexec actions > /dev/null

output "Installing PHP Composer"
wget --quiet -O /tmp/composer https://getcomposer.org/installer
SIZE=$(stat --printf "%s" /tmp/composer)
output "/tmp/composer exists (${SIZE} bytes)"
export COMPOSER_HOME="/root"
export COMPOSER_PARAMETERS="--no-ansi --no-interaction --no-progress"
export COMPOSER_ALLOW_SUPERUSER="1"
php /tmp/composer --quiet --no-ansi --install-dir=/usr/local/bin --filename=composer
rm /tmp/composer

#VERSION_COMPOSER=$(export COMPOSER_ALLOW_SUPERUSER=1 ; echo "composer|"$(composer --no-ansi --no-interaction --version | cut -f 3 -d ' ') | tee --append /tmp/versions | cut -f 2 -d '|')
VERSION_COMPOSER=$(echo "composer|"$(composer --version | cut -f 3 -d ' ') | tee --append /tmp/versions | cut -f 2 -d '|')
output "Composer version: ${VERSION_COMPOSER}"

output "Creating web environment at \"${WWW_DIRECTORY}/\""
cd ${WWW_DIRECTORY}
mkdir cgi-bin etc log

# ...
cat /etc/php/7.4/cgi/php.ini | sed "s/^expose_php\(.*\)$/expose_php = Off/g" | sed "s/^max_execution_time\(.*\)$/max_execution_time = 240/g" | sed "s/^\(;max_input_vars.*\)$/\1\nmax_input_vars = 1500/g" | sed 's/^post_max_size\(.*\)$/post_max_size = 10M/g' | sed 's/^upload_max_filesize\(.*\)$/upload_max_filesize = 10M/g' | sed 's/^\(.*\)always_populate_raw_post_data\(.*\)$/always_populate_raw_post_data = -1/g' > etc/php.ini

#echo '#!/bin/sh' > /tmp/php.fcgi ; echo -e "export PHP_FCGI_CHILDREN=4\nexport PHP_FCGI_MAX_REQUESTS=200\nexport PHPRC=\"/srv/www/${CONTAINER_DOMAIN}/etc/php.ini\"\nexec /usr/bin/php-cgi" >> /tmp/php.fcgi

output "Creating FastCGI server script cgi-bin/php.fcgi"
cat <<EOF > cgi-bin/php.fcgi
#!/bin/sh
export PHP_FCGI_CHILDREN=4
export PHP_FCGI_MAX_REQUESTS=200
export PHPRC="/srv/www/etc/php.ini"
exec /usr/bin/php-cgi
EOF

output "Setting permissions on file cgi-bin/php.fcgi"
chmod 755 cgi-bin/php.fcgi
output "Result: $?"

output "Adding user \"admin\" to group \"www-data\""
adduser www-data admin

if [ -r /tmp/assets/etc/apache2/sites-available/typo3demo.conf ]; then
	output "Copying Apache configuration file"
	cp /tmp/assets/etc/apache2/sites-available/typo3demo.conf /etc/apache2/sites-available/
	chmod 755 /etc/apache2/sites-available/typo3demo.conf
fi

# ------------------------------------------------------------------------------

output "Creating database"
mysql -e "DROP DATABASE IF EXISTS ${DATABASE_DBNAME} ; CREATE DATABASE IF NOT EXISTS ${DATABASE_DBNAME}"
mysql -e "CREATE USER '${DATABASE_USERNAME}'@'%' IDENTIFIED BY '${DATABASE_PASSWORD}'"
mysql -e "GRANT ALL PRIVILEGES ON ${DATABASE_DBNAME}.* TO '${DATABASE_USERNAME}'@'%'"
mysql -e "FLUSH PRIVILEGES"

# ------------------------------------------------------------------------------
# Stage 5
# ------------------------------------------------------------------------------

output "Stage 5: downloading/installing TYPO3 demo site"

cd ${WWW_DIRECTORY}
git clone https://gitlab.typo3.org/services/demo.typo3.org/site.git
cd site/
composer install

#composer require helhum/typo3-console

PASSWORD=$(php -r 'echo password_hash("password", PASSWORD_ARGON2I, ["memory_cost" => 128000, "time_cost" => 30, "threads" => 4]);' | sed 's/\$/\\$/g')
ENCRYPTION_KEY=$(openssl rand -hex 64)

cat <<EOF > .env
#TYPO3_CONTEXT="Development"
TYPO3_INSTALLER_PASSWORD="${PASSWORD}"
TYPO3_ENCRYPTION_KEY="${ENCRYPTION_KEY}"
TYPO3_DB_DATABASE="${DATABASE_DBNAME}"
TYPO3_DB_HOST="localhost"
TYPO3_DB_PASSWORD="${DATABASE_PASSWORD}"
TYPO3_DB_SOCKET=""
TYPO3_DB_USERNAME="${DATABASE_USERNAME}"
EOF

#touch web/typo3conf/ENABLE_INSTALL_TOOL

cd ${WWW_DIRECTORY}
if [ -d htdocs -o -h htdocs ]; then rm -rf htdocs ; fi
ln -s site/web htdocs
systemctl restart apache2

cat site/config/sites/main/config.yaml | yq | jq 'del(.routes,.baseVariants)' | yq -y | sed 's/https/http/g' | sed 's/^base:.*/base: \//g' > /tmp/config.yaml
mv /tmp/config.yaml site/config/sites/main/config.yaml

#./site/bin/typo3cms install:setup
./site/bin/typo3cms ${TYPO3_CLI_PARAMETERS} database:updateschema *.add
./site/bin/typo3cms ${TYPO3_CLI_PARAMETERS} backend:createadmin admin password
./site/bin/typo3 ${TYPO3_CLI_PARAMETERS} extension:deactivate content_sync
./site/bin/typo3 ${TYPO3_CLI_PARAMETERS} extension:deactivate demologin

output "Downloading database dump"
cd /tmp/
wget --quiet -O site.zip "https://gitlab.typo3.org/services/demo.typo3.org/site/-/package_files/5/download"
if [ -r site.zip ]; then
	SIZE=$(stat --printf "%s" /tmp/site.zip)
	output "Database dump file size: ${SIZE} bytes"
	output "Extracting database dump"
	unzip -q site.zip
	mv dump/fileadmin ${WWW_DIRECTORY}/site/web/

	output "Importing database dump"
	. ${WWW_DIRECTORY}/site/.env
	zcat dump/dump.sql.gz | sed 's/https:\/\/demo\.typo3\.org\/typo3\//\/typo3/g' | mysql --user ${TYPO3_DB_USERNAME} -p${TYPO3_DB_PASSWORD} ${TYPO3_DB_DATABASE}
fi

cat <<EOF | mysql --user ${TYPO3_DB_USERNAME} -p${TYPO3_DB_PASSWORD} ${TYPO3_DB_DATABASE}
TRUNCATE TABLE tx_scheduler_task;
EOF

# TODO: remove "server reset note" from site_t3demo

cd ${WWW_DIRECTORY}/site/src/webpack/
nvm install v14.16.0
nvm use

yarn install
yarn build-prod

cd ${WWW_DIRECTORY}/site/web/

#wget -O .htaccess https://git.typo3.org/Packages/TYPO3.CMS.git/blob_plain/HEAD:/typo3/sysext/install/Resources/Private/FolderStructureTemplateFiles/root-htaccess
wget -O .htaccess https://git.typo3.org/Packages/TYPO3.CMS.git/blob_plain/refs/heads/10.4:/typo3/sysext/install/Resources/Private/FolderStructureTemplateFiles/root-htaccess

# ------------------------------------------------------------------------------
# Stage 6
# ------------------------------------------------------------------------------

output "Stage 6: customizing TYPO3 instance"

cd ${WWW_DIRECTORY}/site

if [ -r /tmp/assets/patches/site_t3demo.patch ]; then
	output "Applying patch \"site_t3demo.patch\""
	patch -p1 -i /tmp/assets/patches/site_t3demo.patch
fi

rm -r config/AdditionalConfiguration/*

cat << EOF > config/AdditionalConfiguration/ProductionContext.php
<?php
unset(\$GLOBALS['TYPO3_CONF_VARS']['SYS']['systemMaintainers']);
EOF

# Update Install Tool password
sed -i -e "s/^\(TYPO3_INSTALLER_PASSWORD\)=.*\$/\1=${RANDOM_PASSWORD}/g" ${WWW_DIRECTORY}/site/.env

# Update database access details
sed -i -e "s/^\(TYPO3_DB_PASSWORD\)=.*\$/\1=${RANDOM_PASSWORD}/g" ${WWW_DIRECTORY}/site/.env

# Update TYPO3 encryption key"
sed -i -e "s/^\(TYPO3_ENCRYPTION_KEY\)=.*\$/\1=${ENCRYPTION_KEY}/g" ${WWW_DIRECTORY}/site/.env

# Set new password for MySQL/MariaDB
mysql -e "SET PASSWORD FOR '${TYPO3_DB_USERNAME}'@'%' = PASSWORD('${RANDOM_PASSWORD}')"

# Delete all BE users except "_cli"
mysql ${TYPO3_DB_DATABASE} -e "DELETE FROM be_users WHERE uid > 1"

# Reset auto-increment value
mysql ${TYPO3_DB_DATABASE} -e "ALTER TABLE be_users AUTO_INCREMENT = 2"

# Re-read environment variables
. ${WWW_DIRECTORY}/site/.env

# ...
cat <<EOF > /home/admin/.my.cnf
[client]
user=${TYPO3_DB_USERNAME}
password=${TYPO3_DB_PASSWORD}

[mysql]
database=${TYPO3_DB_DATABASE}
EOF

chown admin: /home/admin/.my.cnf

# Create new TYPO3 admin backend user
${TYPO3_CONSOLE} ${TYPO3_CLI_PARAMETERS} backend:createadmin ${BE_ADMIN_USERNAME} ${BE_ADMIN_PASSWORD}

# Create another admin backend user
${TYPO3_CONSOLE} ${TYPO3_CLI_PARAMETERS} backend:createadmin ${BE_EDITOR_USERNAME} ${BE_EDITOR_PASSWORD}
# Downgrade access privileges
mysql ${TYPO3_DB_DATABASE} -e "UPDATE be_users SET admin = 0, usergroup = '${BE_EDITOR_USERGROUPS}', options = 3 WHERE username = '${BE_EDITOR_USERNAME}'"

# Remove infotext_header and infotext from pages
#mysql ${TYPO3_DB_DATABASE} -e "UPDATE pages SET infotext_header = '', infotext = ''"

# Disable additional file meta data fields
./bin/typo3 extension:deactivate filemetadata

# Configure additional "Site Files" file mount for editors
#mysql ${TYPO3_DB_DATABASE} -e "INSERT INTO sys_filemounts VALUES (5, 0, UNIX_TIMESTAMP(), 0, 0, 128, 'Description', 'Site Files', '/', 1, 0)"
#mysql ${TYPO3_DB_DATABASE} -e "UPDATE be_groups SET file_mountpoints = 5 WHERE uid = 3"

# Remove access permissions to FAQ for editors
# original: mysql ${TYPO3_DB_DATABASE} -e "UPDATE be_groups SET tables_select = 'tx_faqt3demo_faq', tables_modify = 'tx_faqt3demo_faq', groupMods = 'dashboard,web_faq' WHERE uid = 2"
#mysql ${TYPO3_DB_DATABASE} -e "UPDATE be_groups SET groupMods = 'dashboard' WHERE uid = 2"

# original: mysql ${TYPO3_DB_DATABASE} -e "UPDATE be_groups SET tables_select = 'pages,sys_category,sys_collection,sys_file,sys_file_collection,sys_file_metadata,sys_file_reference,sys_file_storage,backend_layout,fe_groups,fe_users,tt_content,tx_faqt3demo_faq' WHERE uid = 3"
#mysql ${TYPO3_DB_DATABASE} -e "UPDATE be_groups SET tables_select = 'pages,sys_category,sys_collection,sys_file,sys_file_collection,sys_file_metadata,sys_file_reference,sys_file_storage,backend_layout,fe_groups,fe_users,tt_content' WHERE uid = 3"

# original: mysql ${TYPO3_DB_DATABASE} -e "UPDATE be_groups SET tables_modify = 'pages,sys_category,sys_collection,sys_file,sys_file_collection,sys_file_metadata,sys_file_reference,sys_file_storage,backend_layout,fe_groups,fe_users,tt_content,tx_faqt3demo_faq' WHERE uid = 3"
#mysql ${TYPO3_DB_DATABASE} -e "UPDATE be_groups SET tables_modify = 'pages,sys_category,sys_collection,sys_file,sys_file_collection,sys_file_metadata,sys_file_reference,sys_file_storage,backend_layout,fe_groups,fe_users,tt_content' WHERE uid = 3"

# original: mysql ${TYPO3_DB_DATABASE} -e "UPDATE be_groups SET groupMods = 'dashboard,web_layout,web_ViewpageView,web_list,web_info,web_faq,file_FilelistList,user_setup,help_AboutAbout,help_cshmanual' WHERE uid = 3"
mysql ${TYPO3_DB_DATABASE} -e "UPDATE be_groups SET groupMods = 'dashboard,web_layout,web_ViewpageView,web_list,web_info,file_FilelistList,user_setup,help_AboutAbout,help_cshmanual' WHERE uid = 3"

# Update reference index
cd ${WWW_DIRECTORY}/site/
./bin/typo3 ${TYPO3_CLI_PARAMETERS} referenceindex:update

# ------------------------------------------------------------------------------

output "..."
find ${WWW_DIRECTORY} -type d -exec chmod 750 {} \;
find ${WWW_DIRECTORY} -type f -exec chmod 640 {} \;
chown -Rh admin: ${WWW_DIRECTORY}

if [ -d ${WWW_DIRECTORY}/html ]; then
	output "Deleting directory \"${WWW_DIRECTORY}/html\""
	rm -r ${WWW_DIRECTORY}/html
fi

output "Enable site in Apache"
a2dissite 000-default > /dev/null
a2ensite typo3demo > /dev/null
systemctl restart apache2

# ------------------------------------------------------------------------------

output "http://${PUBLIC_IP}"
output "TYPO3 backend access details: ${BE_ADMIN_USERNAME} / ${BE_ADMIN_PASSWORD}"
output "Script $0 finished"

# ------------------------------------------------------------------------------
