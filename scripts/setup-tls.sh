#!/bin/bash
# GGS Werewolf — TLS Certificate Setup
# Generates self-signed cert for dev or uses certbot for production
# ═══════════════════════════════════════════════════════════

set -euo pipefail

CERT_DIR="./nginx/certs"
DOMAIN="${DOMAIN:-localhost}"

mkdir -p "$CERT_DIR"

if [ "${ENV:-dev}" = "production" ]; then
    echo "▶ Production mode: Using Let's Encrypt (certbot)"
    echo "  Ensure port 80 is accessible and DOMAIN is set."
    echo ""
    echo "  Run:"
    echo "    certbot certonly --standalone -d $DOMAIN"
    echo "    cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem $CERT_DIR/"
    echo "    cp /etc/letsencrypt/live/$DOMAIN/privkey.pem $CERT_DIR/"
    echo ""
    echo "  Auto-renewal:"
    echo "    certbot renew --deploy-hook 'docker restart ggs-nginx'"
else
    echo "▶ Development mode: Generating self-signed certificate"
    openssl req -x509 -nodes -days 365 \
        -newkey rsa:2048 \
        -keyout "$CERT_DIR/privkey.pem" \
        -out "$CERT_DIR/fullchain.pem" \
        -subj "/CN=$DOMAIN/O=GGS Dev/C=ID"
    
    echo "  ✅ Self-signed cert generated:"
    echo "     $CERT_DIR/fullchain.pem"
    echo "     $CERT_DIR/privkey.pem"
    echo ""
    echo "  ⚠ For production, set ENV=production and use Let's Encrypt"
fi
