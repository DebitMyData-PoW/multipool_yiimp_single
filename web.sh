#!/usr/bin/env bash
#####################################################
# The website: YiiMP's web files, its nginx site (HTTP, then HTTPS with Let's Encrypt), the
# admin portal's password, the settings (serverconfig.php, keys.php), the folders' permissions
# and the jobs that run the pool (main, loop2, blocks).
#
# Source https://mailinabox.email/ https://github.com/mail-in-a-box/mailinabox
# Updated by cryptopool.builders for crypto use, and by DebitMyData for its pool.
#####################################################

source /etc/functions.sh
source /etc/multipool.conf
source "$STORAGE_ROOT/yiimp/.yiimp.conf"

YIIMP_SRC="$STORAGE_ROOT/yiimp/yiimp_setup/yiimp"
INSTALL_DIR="$HOME/multipool/yiimp_single"
# SITE, WEB_ROOT, SERVER_NAMES and nginx_conf
source "$INSTALL_DIR/nginx_site.sh"

echo -e " Copying the website...$COL_RESET"
sudo cp -r "$YIIMP_SRC/web" "$SITE/"
sudo cp -r "$YIIMP_SRC/bin/." /bin/
sudo mkdir -p "/var/www/${DomainName}/html" /etc/yiimp "$SITE/backup"
sudo sed -i "s|ROOTDIR=/data/yiimp|ROOTDIR=${SITE}|g" /bin/yiimp
# The jobs' entry points find serverconfig.php in configuration/ (index.php and the cron
# controller already name it in full).
for file in runconsole.php run.php yaamp/yiic.php; do
	sudo sed -i "s|'serverconfig.php'|'${SITE}/configuration/serverconfig.php'|" "$SITE/web/$file"
done

echo -e " Creating the nginx site...$COL_RESET"
echo 'map $http_user_agent $blockedagent {
	default 0;
	~*malicious 1;
	~*bot 1;
	~*backdoor 1;
	~*crawler 1;
	~*bandit 1;
}' | sudo tee /etc/nginx/blockuseragents.rules >/dev/null

sudo mkdir -p /etc/nginx/snippets
nginx_conf yiimp_site.conf | sudo tee /etc/nginx/snippets/yiimp-site.conf >/dev/null
nginx_conf site_http.conf | sudo tee "/etc/nginx/sites-available/${DomainName}.conf" >/dev/null
sudo ln -sfn "/etc/nginx/sites-available/${DomainName}.conf" "/etc/nginx/sites-enabled/${DomainName}.conf"
sudo ln -sfn "$SITE/web" "$WEB_ROOT"

# The admin portal's password (the website's own IP checks let everyone in).
echo -e " Setting the admin portal's password...$COL_RESET"
printf '%s:%s\n' "$AdminUser" "$(printf '%s\n' "$AdminPassword" | openssl passwd -apr1 -stdin)" |
	sudo tee /etc/nginx/.pma_pass_panel >/dev/null
sudo chown root:www-data /etc/nginx/.pma_pass_panel
sudo chmod 640 /etc/nginx/.pma_pass_panel

# Behind Cloudflare, nginx and the website see Cloudflare's servers: take the visitor's IP from
# CF-Connecting-IP, only on requests that come from Cloudflare's addresses.
if [[ "$BehindCloudflare" == "yes" ]]; then
	echo -e " Taking the visitors' real IPs from Cloudflare...$COL_RESET"
	CF_RANGES="$(curl -fsS --max-time 20 https://www.cloudflare.com/ips-v4; echo; curl -fsS --max-time 20 https://www.cloudflare.com/ips-v6)"
	if [ "$(echo "$CF_RANGES" | grep -c /)" -ge 10 ]; then
		{
			echo "# Visitors' real IPs from Cloudflare (https://www.cloudflare.com/ips/), $(date -u +%Y-%m-%d)"
			echo "$CF_RANGES" | grep / | sed 's/^/set_real_ip_from /; s/$/;/'
			echo "real_ip_header CF-Connecting-IP;"
		} | sudo tee /etc/nginx/conf.d/cloudflare-real-ip.conf >/dev/null
	else
		echo -e "$YELLOW Cloudflare's address list could not be downloaded: see the README (Cloudflare) to add it later.$COL_RESET"
	fi
fi

hide_output sudo nginx -t
restart_service nginx
restart_service "php${PHP_VERSION}-fpm"

if [[ "$InstallSSL" == "yes" ]]; then
	source "$INSTALL_DIR/https.sh"
fi

echo -e " Creating the YiiMP settings files...$COL_RESET"

# The website's secrets: the database backup's login, and the exchanges' keys (unused: this
# pool does not trade). Only what has no default (yaamp/defaultconfig.php): PHP 8 stops a job
# that defines a constant twice.
{
	echo "<?php"
	echo "// The website's secrets, written by the installer (multipool_yiimp_single/web.sh)."
	printf "define('YIIMP_MYSQLDUMP_USER', 'panel');\n"
	printf "define('YIIMP_MYSQLDUMP_PASS', '%s');\n" "${PanelUserDBPassword}"
	echo "// Exchanges' secret keys: unused, this pool does not trade"
	for name in BITTREX_SECRET BITSTAMP_SECRET BINANCE_SECRET BLEUTRADE_SECRET BTER_SECRET \
		CCEX_SECRET CEXIO_SECRET COINMARKETS_PASS CRYPTOPIA_SECRET EMPOEX_SECKEY HITBTC_SECRET \
		KRAKEN_SECRET KUCOIN_SECRET LIVECOIN_SECRET NOVA_SECRET POLONIEX_SECRET \
		STOCKSEXCHANGE_SECRET YOBIT_SECRET; do
		printf "define('EXCH_%s', '');\n" "$name"
	done
} | sudo tee /etc/yiimp/keys.php >/dev/null

# The pool's settings. Everything not here keeps its default (web/yaamp/defaultconfig.php).
sudo tee "$SITE/configuration/serverconfig.php" >/dev/null <<PHP
<?php
// The pool's settings, written by the installer (multipool_yiimp_single/web.sh). Readable only
// by the website and the install user: it holds the database password.
ini_set('date.timezone', 'UTC');

define('YAAMP_LOGS', '${SITE}/log');
define('YAAMP_HTDOCS', '${SITE}/web');
define('YAAMP_BIN', '/bin');
// The database backups (the login is in /etc/yiimp/keys.php)
define('YIIMP_MYSQLDUMP_PATH', '${SITE}/backup');

define('YAAMP_DBHOST', 'localhost');
define('YAAMP_DBNAME', 'yiimpfrontend');
define('YAAMP_DBUSER', 'panel');
define('YAAMP_DBPASSWORD', '${PanelUserDBPassword}');

define('YAAMP_PRODUCTION', true);
define('YAAMP_RENTAL', false);
define('YAAMP_LIMIT_ESTIMATE', false);

// The pool's fee, in percent. The same number as fee in the DMD stratum's [PPLNS] section
// (stratum/config/dmd.sha.conf) and \$fee_pool on the home page (yaamp/modules/site/index.php).
define('YAAMP_FEES_MINING', 0.5);
define('YAAMP_FEES_EXCHANGE', 2);
define('YAAMP_FEES_RENTING', 2);
define('YAAMP_TXFEE_RENTING_WD', 0.002);
define('YAAMP_PAYMENTS_FREQ', 1*60*60);
define('YAAMP_PAYMENTS_MINI', 0.0001);

define('YAAMP_ALLOW_EXCHANGE', false);
define('YIIMP_PUBLIC_EXPLORER', true);
define('YIIMP_PUBLIC_BENCHMARK', false);
define('YIIMP_FIAT_ALTERNATIVE', 'USD'); // USD is main

define('YAAMP_USE_NICEHASH_API', false);

define('YAAMP_BTCADDRESS', '');
define('YAAMP_SITE_URL', '${DomainName}');
define('YAAMP_STRATUM_URL', '${StratumURL}');
define('YAAMP_SITE_NAME', 'DebitMyData Pool');
define('YAAMP_ADMIN_EMAIL', '${AdminEmail}');
define('YAAMP_ADMIN_IP', '${PublicIP}'); // samples: "80.236.118.26,90.234.221.11" or "10.0.0.1/8"
define('YAAMP_ADMIN_WEBCONSOLE', true);
define('YAAMP_CREATE_NEW_COINS', false);
define('YAAMP_NOTIFY_NEW_COINS', false);
define('YAAMP_DEFAULT_ALGO', 'sha256');

define('YAAMP_USE_NGINX', true);

// Exchanges' public keys: unused, this pool does not trade
define('EXCH_COINMARKETS_USER', '');
define('EXCH_COINMARKETS_PIN', '');

// Nobody else's wallet takes a share of the pool's balance
\$cold_wallet_table = array();

// Fixed pool fees per algo (YAAMP_FEES_MINING otherwise), as 'sha256' => 0.5
\$configFixedPoolFees = array();

// Custom stratum ports per algo, as 'x11' => 7000
\$configCustomPorts = array();

// mBTC coefficients per algo (default 1.0), as 'x11' => 5.0
\$configAlgoNormCoef = array();
PHP

echo -e " Setting the folders' permissions...$COL_RESET"
whoami=$(whoami)
sudo usermod -aG www-data "$whoami"
sudo usermod -aG crypto-data "$whoami"
sudo usermod -aG crypto-data www-data

sudo find "$SITE/" -type d -exec chmod 775 {} +
sudo find "$SITE/" -type f -exec chmod 664 {} +

sudo chgrp www-data "$STORAGE_ROOT" -R
sudo chmod g+w "$STORAGE_ROOT" -R

# The secrets: the website (www-data) and the install user (in www-data) read them, nobody else.
sudo chown "$whoami:www-data" "$SITE/configuration/serverconfig.php"
sudo chmod 640 "$SITE/configuration/serverconfig.php"
sudo chown root:www-data /etc/yiimp/keys.php
sudo chmod 640 /etc/yiimp/keys.php
for file in .yiimp.conf .my.cnf; do
	sudo chown "$whoami:$(id -gn)" "$STORAGE_ROOT/yiimp/$file"
	sudo chmod 600 "$STORAGE_ROOT/yiimp/$file"
done

cd "$INSTALL_DIR" || exit 1

echo -e " Creating the jobs (main, loop2, blocks)...$COL_RESET"
# job <file> <action> <seconds between runs> <max_execution_time>
function job {
	echo '#!/usr/bin/env bash

PHP_CLI="php -d max_execution_time='"$4"'"

DIR='"${SITE}"'/web/
cd ${DIR}

date
echo started in ${DIR}

while true; do
${PHP_CLI} runconsole.php cronjob/'"$2"'
sleep '"$3"'
done
exec bash' | sudo tee "$SITE/crons/$1" >/dev/null
	sudo chmod +x "$SITE/crons/$1"
}
job main.sh run 90 120
job loop2.sh runLoop2 60 120
job blocks.sh runBlocks 20 60

echo -e "$GREEN Web build complete...$COL_RESET"
cd "$INSTALL_DIR" || exit 1
