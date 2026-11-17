#####################################################
# The website's nginx values, and nginx_conf <file>: nginx_confs/<file> with them in place of
# the __PLACEHOLDERS__. Sourced by web.sh and https.sh, after .yiimp.conf.
# By DebitMyData for its pool.
#####################################################

SITE="$STORAGE_ROOT/yiimp/site"
WEB_ROOT="/var/www/${DomainName}/html/web"
PHP_SOCKET="/run/php/php${PHP_VERSION}-fpm.sock"
NGINX_CONFS="$HOME/multipool/yiimp_single/nginx_confs"
if [[ "$UsingSubDomain" == "yes" ]]; then
	SERVER_NAMES="${DomainName}"
else
	SERVER_NAMES="${DomainName} www.${DomainName}"
fi
# The HTTPS certificate: Cloudflare's origin certificate, or Let's Encrypt's
if [[ "$SSLMode" == "cloudflare" ]]; then
	SSL_CERT="/etc/ssl/cloudflare/${DomainName}.pem"
	SSL_KEY="/etc/ssl/cloudflare/${DomainName}.key"
else
	SSL_CERT="/etc/letsencrypt/live/${DomainName}/fullchain.pem"
	SSL_KEY="/etc/letsencrypt/live/${DomainName}/privkey.pem"
fi

# (without the IPv6 listen lines on a server whose kernel has no IPv6: nginx would not start)
function nginx_conf {
	sed -e "s|__DOMAIN__|${DomainName}|g" -e "s|__SERVER_NAMES__|${SERVER_NAMES}|g" \
		-e "s|__WEB_ROOT__|${WEB_ROOT}|g" -e "s|__LOG_DIR__|${SITE}/log|g" \
		-e "s|__PHP_SOCKET__|${PHP_SOCKET}|g" -e "s|__SSL_CERT__|${SSL_CERT}|g" \
		-e "s|__SSL_KEY__|${SSL_KEY}|g" "$NGINX_CONFS/$1" |
		if [ -e /proc/net/if_inet6 ]; then cat; else sed '/listen \[::\]/d'; fi
}
