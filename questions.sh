#####################################################
# The install's questions. The answers go to $STORAGE_ROOT/yiimp/.yiimp.conf, which the other
# steps and the pool's commands read. It holds the passwords: only the install user can read it.
#
# Source https://mailinabox.email/ https://github.com/mail-in-a-box/mailinabox
# Updated by cryptopool.builders for crypto use, and by DebitMyData for its pool.
#####################################################

source /etc/functions.sh
source /etc/multipool.conf

# The pool's code: DebitMyData's YiiMP, from its main branch (the tested code; work goes on in
# next). YIIMP_REF picks another branch or tag.
YiiMPRepo='https://github.com/DebitMyData-PoW/debitmydata-yiimp.git'
YiiMPBranch="${YIIMP_REF:-main}"
# Ubuntu 24.04's own PHP
PHP_VERSION='8.3'

# ask VARIABLE "title" "prompt" "default" "regex" "what an answer must look like"
# Asks again until the answer matches; Esc or Cancel stops the install.
function ask {
	local name=$1 title=$2 prompt=$3 default=$4 regex=$5 rule=$6 value
	while true; do
		input_box "$title" "$prompt" "$default" value
		if [ "$value_EXITCODE" != 0 ]; then
			clear
			echo "Install cancelled."
			exit 1
		fi
		if [[ $value =~ $regex ]]; then
			printf -v "$name" '%s' "$value"
			return
		fi
		message_box "$title" "$rule"
		default=$value
	done
}

# yes_no VARIABLE "title" "question": yes or no; Esc stops the install.
function yes_no {
	local name=$1
	dialog --title "$2" --yesno "$3" 8 64
	case $? in
		0) printf -v "$name" '%s' yes ;;
		1) printf -v "$name" '%s' no ;;
		*)
			clear
			echo "Install cancelled."
			exit 1
			;;
	esac
}

DOMAIN_RE='^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$'
DOMAIN_RULE='Letters, digits, dots and dashes only, like pool.example.com (or the server IP).'
# The database passwords go in PHP and in the stratum's config files as they are.
DB_PASSWORD_RE='^[A-Za-z0-9._-]{16,}$'
DB_PASSWORD_RULE='At least 16 characters: letters, digits, dot, dash and underscore only.'

message_box "DebitMyData pool installer" \
	"This installs the DebitMyData pool (YiiMP) on this server: the website, the database and the stratum.
\n\nPoint the domain names you will use (the website, the stratum) to this server's IP before you continue.
\n\nThe questions come first, then the install runs by itself (about 20 minutes).
\n\nNOTE: with less than 4 GB of RAM the server may be slow."

yes_no UsingSubDomain "Using Sub-Domain" \
	"Is the website on a sub-domain, like pool.example.com? (No: example.com, and www.example.com too.)"

# How visitors reach the website, and its HTTPS certificate
SSLMode=$(dialog --stdout --title "Website and HTTPS" --default-item cloudflare \
	--menu "How do visitors reach the website?" 14 76 3 \
	cloudflare "Through Cloudflare (proxied): Cloudflare origin certificate" \
	letsencrypt "Directly (DNS only): Let's Encrypt certificate" \
	none "Directly, HTTP only (the server's IP, no domain)")
case "$SSLMode" in
	cloudflare | letsencrypt | none) ;;
	*)
		clear
		echo "Install cancelled."
		exit 1
		;;
esac
# (the older answers, which the other steps and tools read)
InstallSSL=$([[ "$SSLMode" == "none" ]] && echo no || echo yes)
BehindCloudflare=$([[ "$SSLMode" == "cloudflare" ]] && echo yes || echo no)

while [ -z "${DomainName}" ]; do
	ask DomainName "Domain Name" \
		"The website's domain. On a sub-domain, the full name, like pool.example.com.
\n\nNo www. in front.
\n\nIf you only use the server IP, enter the IP.
\n\nDomain Name:" \
		"$(get_publicip_from_web_service 4 || get_default_privateip 4)" \
		"$DOMAIN_RE" "$DOMAIN_RULE"
	# a certificate is for a name, not an IP
	if [[ "$SSLMode" != "none" && "$DomainName" =~ ^[0-9.]+$ ]]; then
		message_box "Domain Name" "HTTPS needs the website's name, like pool.example.com, not an IP. (For the IP only, go back and choose HTTP only.)"
		DomainName=""
	fi
done

# The Cloudflare origin certificate: made in Cloudflare's dashboard, pasted here once.
if [[ "$SSLMode" == "cloudflare" ]]; then
	CF_CERT="/etc/ssl/cloudflare/${DomainName}.pem"
	CF_KEY="/etc/ssl/cloudflare/${DomainName}.key"
	CF_NAMES="${DomainName}"
	[[ "$UsingSubDomain" == "yes" ]] || CF_NAMES="${DomainName} www.${DomainName}"

	# Prints what is wrong with the certificate and its key, or nothing when they are right.
	function cloudflare_cert_problem {
		sudo test -s "$CF_CERT" || { echo "There is no certificate in $CF_CERT."; return; }
		sudo test -s "$CF_KEY" || { echo "There is no private key in $CF_KEY."; return; }
		sudo openssl x509 -in "$CF_CERT" -noout 2>/dev/null || { echo "$CF_CERT is not a certificate (PEM)."; return; }
		sudo openssl pkey -in "$CF_KEY" -noout 2>/dev/null || { echo "$CF_KEY is not a private key (PEM)."; return; }
		[ "$(sudo openssl x509 -in "$CF_CERT" -noout -pubkey)" == "$(sudo openssl pkey -in "$CF_KEY" -pubout)" ] ||
			{ echo "The private key is not the certificate's."; return; }
		sudo openssl x509 -in "$CF_CERT" -noout -checkend 86400 >/dev/null || { echo "The certificate has expired."; return; }
		local name
		for name in $CF_NAMES; do
			sudo openssl x509 -in "$CF_CERT" -noout -checkhost "$name" | grep -q "does match" ||
				{ echo "The certificate is not for $name."; return; }
		done
	}

	sudo mkdir -p /etc/ssl/cloudflare
	sudo chmod 700 /etc/ssl/cloudflare
	CF_PROBLEM=$(cloudflare_cert_problem)
	while [ -n "$CF_PROBLEM" ]; do
		message_box "Cloudflare Origin Certificate" \
			"$CF_PROBLEM
\n\nIn Cloudflare, for your domain: SSL/TLS, Origin Server, Create Certificate. Keep \"Generate private key and CSR with Cloudflare\" (RSA), the host names ${CF_NAMES} (Cloudflare's default, the domain and *.domain, covers them), 15 years, and the PEM format.
\n\nThe editor (nano) then opens twice. First paste the Origin Certificate, then the Private Key, each from -----BEGIN to -----END. Save with Ctrl+O then Enter, and leave with Ctrl+X.
\n\nCloudflare shows the private key only once: keep it in your password manager."
		sudo nano "$CF_CERT"
		sudo nano "$CF_KEY"
		CF_PROBLEM=$(cloudflare_cert_problem)
		if [ -n "$CF_PROBLEM" ]; then
			dialog --title "Cloudflare Origin Certificate" --yesno "$CF_PROBLEM\n\nTry again?" 8 70 || {
				clear
				echo "Install cancelled: the Cloudflare origin certificate is not right yet."
				exit 1
			}
		fi
	done
	# Only root (and nginx's master process, which runs as root) reads the key.
	sudo chown root:root "$CF_CERT" "$CF_KEY"
	sudo chmod 644 "$CF_CERT"
	sudo chmod 600 "$CF_KEY"
fi

if [ -z "${StratumURL}" ]; then
	ask StratumURL "Stratum URL" \
		"The address miners connect to. Another sub-domain is best, like stratum.${DomainName}: it must not go through Cloudflare's proxy (DNS only, the grey cloud).
\n\nIf you only use the server IP, enter the IP.
\n\nStratum URL:" \
		"${DomainName}" "$DOMAIN_RE" "$DOMAIN_RULE"
fi

if [ -z "${PlayAppId+x}" ]; then
	ask PlayAppId "Android App (Google Play)" \
		"If you publish this website as an Android app on Google Play (with Bubblewrap), its package name, like io.example.pool: the website then knows when that app is installed, and does not offer people the browser version too.
\n\nLeave it empty if you have no Play app. You can add it later (the installer's README says how).
\n\nPackage name:" \
		"" '^([a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+)?$' \
		'Empty, or a package name: lowercase words separated by dots, like io.example.pool.'
fi

if [ -z "${AdminEmail}" ]; then
	# (it goes in the website's settings as it is: no quotes or spaces)
	if [[ "$SSLMode" == "letsencrypt" ]]; then
		email_re='^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
		email_rule="An email address: Let's Encrypt writes to it before the certificate expires."
	else
		email_re='^([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})?$'
		email_rule='An email address, or nothing.'
	fi
	ask AdminEmail "Admin Email" \
		"The pool admin's email address: the website shows it as the admin's (and Let's Encrypt writes to it, with a Let's Encrypt certificate).
\n\nAdmin Email:" \
		"" "$email_re" "$email_rule"
fi

if [ -z "${PublicIP}" ]; then
	ask PublicIP "Your Public IP" \
		"The public IP of the computer you run the admin from (YAAMP_ADMIN_IP), or several separated by commas.
\n\nGuessed from your SSH connection. To check it, open https://icanhazip.com on that computer.
\n\nYour Public IP:" \
		"$(echo "$SSH_CLIENT" | awk '{ print $1 }')" \
		'^[0-9A-Fa-f:.,/]+$' 'IP addresses (IPv4 or IPv6), separated by commas.'
fi

if [ -z "${StratumPort}" ]; then
	ask StratumPort "DMD Stratum Port" \
		"The port miners connect to for DMD (SHA-256). It is opened in the firewall.
\n\nDMD Stratum Port:" \
		"8700" '^[1-9][0-9]{3,4}$' 'A port number, from 1024 to 65535.'
	if [ "$StratumPort" -gt 65535 ]; then
		StratumPort=8700
	fi
fi

if [ -z "${AdminUser}" ]; then
	ask AdminUser "Admin Portal User" \
		"The admin portal (/site/AdminPortal) asks for a user name and a password (nginx).
\n\nAdmin user name:" \
		"pooladmin" '^[a-z][a-z0-9_-]{2,31}$' '3 to 32 characters: lowercase letters, digits, dash and underscore, starting with a letter.'
fi

if [ -z "${AdminPassword}" ]; then
	ask AdminPassword "Admin Portal Password" \
		"The admin portal's password: keep the random one or enter yours. Put it in your password manager.
\n\nAdmin password:" \
		"$(openssl rand -base64 24 | tr -d "=+/")" '^[^[:space:]]{16,}$' 'At least 16 characters, no spaces.'
fi

if [ -z "${PanelUserDBPassword}" ]; then
	ask PanelUserDBPassword "Database Panel Password" \
		"The database password of the website (user panel). Keep the random one.
\n\nPanel database password:" \
		"$(openssl rand -base64 29 | tr -d "=+/")" "$DB_PASSWORD_RE" "$DB_PASSWORD_RULE"
fi

if [ -z "${StratumUserDBPassword}" ]; then
	ask StratumUserDBPassword "Database Stratum Password" \
		"The database password of the stratum (user stratum). Keep the random one.
\n\nStratum database password:" \
		"$(openssl rand -base64 29 | tr -d "=+/")" "$DB_PASSWORD_RE" "$DB_PASSWORD_RULE"
fi

clear

dialog --title "Verify Your Responses" \
	--yesno "Please verify your answers to continue setup:

Using Sub-Domain : ${UsingSubDomain}
HTTPS            : ${SSLMode}
Domain Name      : ${DomainName}
Stratum URL      : ${StratumURL}
Android app      : ${PlayAppId:-none}
Admin Email      : ${AdminEmail}
Your Public IP   : ${PublicIP}
DMD Stratum Port : ${StratumPort}
Admin Portal     : /site/AdminPortal
Admin User       : ${AdminUser}
Admin Password   : ${AdminPassword}" 19 70

# Get exit status
# 0 means user hit [yes] button.
# 1 means user hit [no] button.
# 255 means user hit [Esc] key.
response=$?
case $response in

	0)
		# Save the answers in $STORAGE_ROOT/yiimp/.yiimp.conf so that standalone tools know
		# where to look for data. Only this user may read it: it holds the passwords.
		{
			echo '# The answers of the DebitMyData pool install (multipool_yiimp_single/questions.sh).'
			echo '# It holds passwords: keep it readable only by its owner.'
			printf '%s=%q\n' \
				STORAGE_USER "${STORAGE_USER}" \
				STORAGE_ROOT "${STORAGE_ROOT}" \
				DomainName "${DomainName}" \
				StratumURL "${StratumURL}" \
				PlayAppId "${PlayAppId}" \
				AdminEmail "${AdminEmail}" \
				PublicIP "${PublicIP}" \
				StratumPort "${StratumPort}" \
				AdminPanel AdminPortal \
				AdminUser "${AdminUser}" \
				AdminPassword "${AdminPassword}" \
				PanelUserDBPassword "${PanelUserDBPassword}" \
				StratumUserDBPassword "${StratumUserDBPassword}" \
				UsingSubDomain "${UsingSubDomain}" \
				SSLMode "${SSLMode}" \
				InstallSSL "${InstallSSL}" \
				BehindCloudflare "${BehindCloudflare}" \
				CoinSymbol DMD \
				PHP_VERSION "${PHP_VERSION}" \
				YiiMPRepo "${YiiMPRepo}" \
				YiiMPBranch "${YiiMPBranch}"
		} | sudo tee "$STORAGE_ROOT/yiimp/.yiimp.conf" >/dev/null
		sudo chown "$(id -un):$(id -gn)" "$STORAGE_ROOT/yiimp/.yiimp.conf"
		sudo chmod 600 "$STORAGE_ROOT/yiimp/.yiimp.conf"
		;;

	1)
		clear
		bash "$(basename "$0")" && exit
		;;

	255)
		clear
		echo "User canceled installation"
		exit 0
		;;
esac

cd "$HOME/multipool/yiimp_single" || exit 1
