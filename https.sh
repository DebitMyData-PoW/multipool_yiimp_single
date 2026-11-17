#!/usr/bin/env bash
#####################################################
# HTTPS for the website: Let's Encrypt's certificate (certbot, through the website's folder),
# then the HTTPS nginx site, and nginx reloads after each renewal. web.sh runs it during the
# install. If Let's Encrypt refused then (the domain did not point to this server yet), run it
# again once it does:
#
#   bash ~/multipool/yiimp_single/https.sh
#
# By DebitMyData for its pool.
#####################################################

source /etc/functions.sh
source /etc/multipool.conf
source "$STORAGE_ROOT/yiimp/.yiimp.conf"
source "$HOME/multipool/yiimp_single/nginx_site.sh"

if [ -z "${AdminEmail}" ]; then
	echo "Let's Encrypt needs an email address: put it in $STORAGE_ROOT/yiimp/.yiimp.conf"
	echo "(AdminEmail=you@example.com), then run this again."
	exit 1
fi

echo -e " Getting the HTTPS certificate from Let's Encrypt...$COL_RESET"
CERT_NAMES=(-d "${DomainName}")
if [[ "$UsingSubDomain" != "yes" ]]; then
	CERT_NAMES+=(-d "www.${DomainName}")
fi
CERTBOT_LOG=$(mktemp)
# shellcheck disable=SC2024  # the log is this user's own file
if sudo certbot certonly --webroot -w "$SITE/web" --non-interactive --agree-tos --no-eff-email \
	-m "${AdminEmail}" "${CERT_NAMES[@]}" >"$CERTBOT_LOG" 2>&1; then
	nginx_conf site_https.conf | sudo tee "/etc/nginx/sites-available/${DomainName}.conf" >/dev/null
	# After each renewal (certbot's timer), nginx loads the new certificate.
	sudo mkdir -p /etc/letsencrypt/renewal-hooks/deploy
	printf '#!/bin/sh\n# The website uses the renewed certificate.\nservice nginx reload\n' |
		sudo tee /etc/letsencrypt/renewal-hooks/deploy/reload-nginx >/dev/null
	sudo chmod 755 /etc/letsencrypt/renewal-hooks/deploy/reload-nginx
	hide_output sudo nginx -t
	restart_service nginx
	InstallSSL=yes
	echo -e "$GREEN HTTPS is on: https://${DomainName}$COL_RESET"
else
	echo -e "$RED Let's Encrypt refused the certificate: the website stays on HTTP for now.$COL_RESET"
	tail -n 15 "$CERTBOT_LOG"
	echo
	echo "Once ${DomainName} points to this server, run: bash ~/multipool/yiimp_single/https.sh"
	InstallSSL=no
	sleep 10
fi
rm -f "$CERTBOT_LOG"
# (sed -i writes next to the file, in a folder of root's; the file stays this user's only)
sudo sed -i "s/^InstallSSL=.*/InstallSSL=${InstallSSL}/" "$STORAGE_ROOT/yiimp/.yiimp.conf"
sudo chown "$(id -un):$(id -gn)" "$STORAGE_ROOT/yiimp/.yiimp.conf"
sudo chmod 600 "$STORAGE_ROOT/yiimp/.yiimp.conf"
