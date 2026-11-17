#####################################################
# The system: time zone, updates, Ubuntu 24.04's own PHP and the build tools, the firewall,
# then the pool's code (DebitMyData's YiiMP).
#
# Source https://mailinabox.email/ https://github.com/mail-in-a-box/mailinabox
# Updated by cryptopool.builders for crypto use, and by DebitMyData for its pool.
#####################################################

clear
source /etc/functions.sh
source /etc/multipool.conf

# The pool's folders, open to the install user and the website first: on Ubuntu 24.04 a new
# user's home folder (/home/crypto-data) is closed to everyone else.
sudo chmod 755 /home/crypto-data >/dev/null 2>&1
sudo chmod 755 "$STORAGE_ROOT" "$STORAGE_ROOT/yiimp" >/dev/null 2>&1
source "$STORAGE_ROOT/yiimp/.yiimp.conf"

echo -e " Setting the time zone to UTC...$COL_RESET"
sudo ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime
echo "Etc/UTC" | sudo tee /etc/timezone >/dev/null
echo -e "$GREEN Done...$COL_RESET"

echo -e " Updating the system packages (can be long)...$COL_RESET"
apt_get_quiet update
apt_get_quiet upgrade
apt_get_quiet dist-upgrade
apt_get_quiet autoremove
echo -e "$GREEN Done...$COL_RESET"

echo -e " Installing the base system packages...$COL_RESET"
apt_install python3 wget curl git sudo coreutils bc acl unzip \
	unattended-upgrades cron chrony fail2ban screen
echo -e "$GREEN Done...$COL_RESET"

if [ -z "$DISABLE_FIREWALL" ]; then
	# Install `ufw` which provides a simple firewall configuration.
	echo -e " Installing the firewall (UFW)...$COL_RESET"
	apt_install ufw

	# Allow incoming connections. Behind Cloudflare, only Cloudflare's addresses reach the
	# website (cloudflare.sh, from web.sh).
	ufw_allow ssh
	if [[ "$SSLMode" != "cloudflare" ]]; then
		ufw_allow http
		ufw_allow https
	fi

	# ssh might be running on an alternate port. Use sshd -T to dump sshd's
	# settings, find the port it is supposedly running on, and open that port too.
	SSH_PORT=$(sudo sshd -T 2>/dev/null | grep "^port " | sed "s/port //")
	if [ -n "$SSH_PORT" ] && [ "$SSH_PORT" != "22" ]; then
		echo "Opening alternate SSH port $SSH_PORT."
		ufw_allow "$SSH_PORT"
	fi

	sudo ufw --force enable
	echo -e "$GREEN Done...$COL_RESET"
fi

echo -e " Installing the web server, PHP ${PHP_VERSION} and the build tools...$COL_RESET"
if [ -f /usr/sbin/apache2 ]; then
	echo "Removing apache..."
	apt_get_quiet purge apache2 'apache2-*'
	apt_get_quiet --purge autoremove
fi

# The website: nginx, PHP-FPM and memcached (Ubuntu 24.04's own packages)
apt_install nginx certbot memcached imagemagick pwgen \
	php${PHP_VERSION}-fpm php${PHP_VERSION}-cli php${PHP_VERSION}-common php${PHP_VERSION}-opcache \
	php${PHP_VERSION}-mysql php${PHP_VERSION}-curl php${PHP_VERSION}-gd php${PHP_VERSION}-intl \
	php${PHP_VERSION}-mbstring php${PHP_VERSION}-xml php${PHP_VERSION}-zip php${PHP_VERSION}-imap \
	php${PHP_VERSION}-sqlite3 php${PHP_VERSION}-tidy php${PHP_VERSION}-pspell php${PHP_VERSION}-cgi \
	php${PHP_VERSION}-memcache php${PHP_VERSION}-memcached php${PHP_VERSION}-imagick php-pear

# The stratum and blocknotify: a C++ build linked with MySQL's client and curl (statically
# listed, hence curl's own libraries)
apt_install build-essential pkg-config libtool autotools-dev automake cmake bsdmainutils \
	libssl-dev libmysqlclient-dev libcurl4-gnutls-dev libgmp-dev libsodium-dev libevent-dev \
	libbrotli-dev libzstd-dev zlib1g-dev libssh-dev libssh2-1-dev libkrb5-dev libldap2-dev \
	libidn11-dev libidn2-dev libgnutls28-dev librtmp-dev libpsl-dev libnghttp2-dev
echo -e "$GREEN Done...$COL_RESET"

echo -e " Downloading the pool's code (${YiiMPRepo}, ${YiiMPBranch})...$COL_RESET"
sudo rm -rf "$STORAGE_ROOT/yiimp/yiimp_setup/yiimp"
hide_output sudo git clone --depth 1 -b "${YiiMPBranch}" "${YiiMPRepo}" "$STORAGE_ROOT/yiimp/yiimp_setup/yiimp"
echo -e "$GREEN System files installed...$COL_RESET"
cd "$HOME/multipool/yiimp_single" || exit 1
