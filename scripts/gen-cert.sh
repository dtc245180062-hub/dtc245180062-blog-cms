#!/usr/bin/env bash
# Tạo chứng chỉ HTTPS tự ký (365 ngày) và file .htpasswd cho phpMyAdmin.
# Dùng: ./scripts/gen-cert.sh [HOSTNAME_hoac_IP]   (mặc định: localhost)
set -euo pipefail
cd "$(dirname "$0")/.."

HOST="${1:-localhost}"
mkdir -p nginx/certs

# SAN: nếu là IP thì dùng IP:, ngược lại DNS:
if [[ "$HOST" == "localhost" ]]; then SAN="DNS:localhost,IP:127.0.0.1"
elif [[ "$HOST" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then SAN="IP:$HOST,DNS:localhost"
else SAN="DNS:$HOST,DNS:localhost"; fi

openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
  -keyout nginx/certs/server.key -out nginx/certs/server.crt \
  -subj "/C=VN/O=ICTU/CN=$HOST" \
  -addext "subjectAltName=$SAN"
chmod 644 nginx/certs/server.crt
# Container nginx chạy uid 101 nên cần đọc được key (mount read-only)
chmod 644 nginx/certs/server.key
echo "Đã tạo nginx/certs/server.crt và server.key (SAN: $SAN)"

# .htpasswd cho phpMyAdmin (đọc từ .env)
if [ -f .env ]; then
  set -a; . ./.env; set +a
  HASH="$(openssl passwd -apr1 "$PMA_BASIC_PASSWORD")"
  printf '%s:%s\n' "$PMA_BASIC_USER" "$HASH" > nginx/.htpasswd
  chmod 644 nginx/.htpasswd
  echo "Đã tạo nginx/.htpasswd cho user $PMA_BASIC_USER"
else
  echo "Chưa có .env -> chạy ./scripts/gen-env.sh trước rồi chạy lại script này." >&2
  exit 1
fi
