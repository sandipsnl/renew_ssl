#!/bin/bash

# -----------------------
# LiteSpeed SSL Renewal Script (Webroot, Non-Interactive)
# Usage: ./renew_ssl.sh yourdomain.com
# -----------------------

set -e

# --- Check argument ---
if [ -z "$1" ]; then
    echo "Usage: $0 <domain>"
    exit 1
fi

DOMAIN="$1"
WEBROOT="/home/$DOMAIN/public_html"
VHOST_CONF="/usr/local/lsws/conf/vhosts/$DOMAIN/vhost.conf"

# --- Validate domain format ---
if [[ ! "$DOMAIN" =~ ^([a-zA-Z0-9][-a-zA-Z0-9]{0,62}\.)+[a-zA-Z]{2,}$ ]]; then
    echo "❌ Invalid domain: $DOMAIN"
    exit 1
fi

echo "✅ Domain is valid: $DOMAIN"

# --- Check existing SSL certificate ---
SSL_OK=0
if openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" </dev/null 2>/dev/null | openssl x509 -noout -dates &>/dev/null; then
    EXPIRY=$(openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" </dev/null 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)
    EXPIRY_TS=$(date -d "$EXPIRY" +%s)
    NOW_TS=$(date +%s)
    if (( EXPIRY_TS - NOW_TS > 86400 )); then
        echo "✔ SSL certificate already valid (expires on $EXPIRY), skipping renewal."
        SSL_OK=1
    fi
fi

# If SSL is valid, exit
if [ $SSL_OK -eq 1 ]; then
    exit 0
fi

# --- Ensure webroot exists ---
if [ ! -d "$WEBROOT" ]; then
    echo "❌ Webroot not found: $WEBROOT"
    exit 1
fi

# --- Ensure .well-known/acme-challenge exists ---
ACME_DIR="$WEBROOT/.well-known/acme-challenge"
if [ ! -d "$ACME_DIR" ]; then
    echo "Creating ACME challenge directory: $ACME_DIR"
    mkdir -p "$ACME_DIR"
    chown -R $(stat -c '%U:%G' "$WEBROOT") "$ACME_DIR"
    chmod 755 "$ACME_DIR"
    # Create a test file
    echo "SSL test file" > "$ACME_DIR/test.txt"
fi

# --- Fix vhost context if not pointing to public_html ---
if [ -f "$VHOST_CONF" ]; then
    if ! grep -q "$WEBROOT" "$VHOST_CONF"; then
        echo "Updating vhost context to point to public_html"
        sed -i "s|location\s\+.*\.well-known/acme-challenge|location $WEBROOT/.well-known/acme-challenge|g" "$VHOST_CONF"
    fi
else
    echo "❌ Vhost config not found: $VHOST_CONF"
    exit 1
fi

# --- Run Certbot in webroot mode ---
echo "➤ Running Certbot (webroot, non-interactive)..."
certbot certonly --webroot -w "$WEBROOT" -d "$DOMAIN" --non-interactive --agree-tos -m admin@"$DOMAIN" --force-renewal

# --- Detect latest certificate folder ---
CERT_DIR=$(ls -dt /etc/letsencrypt/live/$DOMAIN* | head -1)
if [ ! -d "$CERT_DIR" ]; then
    echo "❌ Could not detect certificate folder."
    exit 1
fi
echo "✔ Using certificate folder: $CERT_DIR"

# --- Update vhost SSL paths ---
sed -i "s|sslKeyFile\s\+.*|sslKeyFile                $CERT_DIR/privkey.pem|g" "$VHOST_CONF"
sed -i "s|sslCertFile\s\+.*|sslCertFile               $CERT_DIR/fullchain.pem|g" "$VHOST_CONF"
sed -i "s|sslCACertFile\s\+.*|sslCACertFile            $CERT_DIR/chain.pem|g" "$VHOST_CONF"

# --- Reload LiteSpeed ---
echo "➤ Reloading LiteSpeed..."
systemctl reload lsws

# --- Verify SSL ---
echo "➤ Verifying SSL certificate..."
openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" </dev/null 2>/dev/null | openssl x509 -noout -dates -subject -issuer

echo "✅ SSL renewed and assigned successfully for $DOMAIN"
