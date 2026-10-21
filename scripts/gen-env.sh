#!/usr/bin/env bash
# Sinh file .env với mật khẩu mạnh ngẫu nhiên (24 ký tự, chữ + số).
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -f .env ]; then
  echo ".env đã tồn tại. Xóa nó nếu muốn sinh lại (CẢNH BÁO: DB cũ sẽ không đăng nhập được)." >&2
  exit 1
fi

pw() { openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 24; }

cat > .env <<EOF
WP_DB_NAME=wordpress
WP_DB_USER=wp_user
WP_DB_PASSWORD=$(pw)
MYSQL_ROOT_PASSWORD=$(pw)

PMA_BASIC_USER=admin
PMA_BASIC_PASSWORD=$(pw)

GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=$(pw)
EXPORTER_DB_PASSWORD=$(pw)
EOF
chmod 600 .env
echo "Đã tạo .env (quyền 600). Xem mật khẩu bằng: cat .env"
