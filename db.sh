#####################################################
# The database: Ubuntu 24.04's MariaDB (10.11), the yiimpfrontend database with its two users
# (panel for the website, stratum for the stratum), then YiiMP's tables and DebitMyData's
# changes, in the order they must run.
#
# MariaDB's root user stays as Ubuntu sets it up: only the system's root logs in (sudo mysql),
# with no password to keep or to leak.
#
# Created by cryptopool.builders for crypto use. Updated by DebitMyData for its pool.
#####################################################

source /etc/functions.sh
source /etc/multipool.conf
source "$STORAGE_ROOT/yiimp/.yiimp.conf"

echo -e " Installing MariaDB...$COL_RESET"
apt_install mariadb-server mariadb-client
sudo service mariadb start >/dev/null 2>&1
echo -e "$GREEN MariaDB installed...$COL_RESET"

echo -e " Creating the database and its users...$COL_RESET"
# (on standard input: the passwords stay out of the process list)
hide_output sudo mysql <<SQL
CREATE DATABASE IF NOT EXISTS yiimpfrontend;
CREATE USER IF NOT EXISTS 'panel'@'localhost' IDENTIFIED BY '${PanelUserDBPassword}';
ALTER USER 'panel'@'localhost' IDENTIFIED BY '${PanelUserDBPassword}';
CREATE USER IF NOT EXISTS 'stratum'@'localhost' IDENTIFIED BY '${StratumUserDBPassword}';
ALTER USER 'stratum'@'localhost' IDENTIFIED BY '${StratumUserDBPassword}';
GRANT ALL ON yiimpfrontend.* TO 'panel'@'localhost';
GRANT ALL ON yiimpfrontend.* TO 'stratum'@'localhost';
FLUSH PRIVILEGES;
SQL
echo -e "$GREEN Database created...$COL_RESET"

# The two users' logins, for tools (mysql --defaults-file=... --defaults-group-suffix=host1)
printf '%s\n' \
	'[clienthost1]' 'user=panel' "password=${PanelUserDBPassword}" 'database=yiimpfrontend' 'host=localhost' \
	'[clienthost2]' 'user=stratum' "password=${StratumUserDBPassword}" 'database=yiimpfrontend' 'host=localhost' |
	sudo tee "$STORAGE_ROOT/yiimp/.my.cnf" >/dev/null
sudo chown "$(id -un):$(id -gn)" "$STORAGE_ROOT/yiimp/.my.cnf"
sudo chmod 600 "$STORAGE_ROOT/yiimp/.my.cnf"

TABLES=$(sudo mysql -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='yiimpfrontend'")
if [ "$TABLES" != "0" ]; then
	# The install runs again on a pool that has its data: the database stays as it is.
	echo -e "$YELLOW The database already has its tables: kept as it is.$COL_RESET"
else
	echo -e " Importing YiiMP's tables...$COL_RESET"
	cd "$STORAGE_ROOT/yiimp/yiimp_setup/yiimp/sql" || exit 1
	if ! zcat 2016-04-03-yaamp.sql.gz | sudo mysql yiimpfrontend; then
		echo "FAILED: importing YiiMP's tables (sql/2016-04-03-yaamp.sql.gz)"
		exit 1
	fi
	# YiiMP's updates since: some only add what the first file already has (--force goes on)
	for update in \
		2016-04-24-market_history.sql 2016-04-27-settings.sql 2016-05-11-coins.sql \
		2016-05-15-benchmarks.sql 2016-05-23-bookmarks.sql 2016-06-01-notifications.sql \
		2016-06-04-bench_chips.sql 2016-11-23-coins.sql 2017-02-05-benchmarks.sql \
		2017-03-31-earnings_index.sql 2017-05-accounts_case_swaptime.sql \
		2017-06-payouts_coinid_memo.sql 2017-09-notifications.sql 2017-10-bookmarks.sql \
		2017-11-segwit.sql 2018-01-stratums_ports.sql 2018-02-coins_getinfo.sql \
		2019-03-coins_thepool_life.sql 2023-01-23-workers.sql 2023-02-08-mweb-segwit.sql; do
		sudo mysql --force yiimpfrontend < "$update" >/dev/null 2>&1
	done
	# DebitMyData's: PPLNS in the coinbase, then the notifications. In this order: the second file
	# makes the table that the third one changes. These must all work.
	for update in 2026-11-12-pplns-coinbase.sql 2026-11-13-push.sql 2026-11-12-push-test.sql; do
		hide_output sudo mysql yiimpfrontend < "$update"
	done
	echo -e "$GREEN Database import complete...$COL_RESET"

fi

restart_service mariadb
echo
echo -e "$GREEN Database build complete...$COL_RESET"
cd "$HOME/multipool/yiimp_single" || exit 1
