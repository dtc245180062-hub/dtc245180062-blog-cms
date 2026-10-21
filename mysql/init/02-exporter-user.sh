#!/bin/bash
# Tạo user giám sát với quyền TỐI THIỂU (không đọc dữ liệu bài viết).
# Chạy tự động khi DB khởi tạo lần đầu; nếu DB đã có dữ liệu thì chạy tay:
#   docker compose exec db bash /docker-entrypoint-initdb.d/02-exporter-user.sh
set -e
mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" <<SQL
CREATE USER IF NOT EXISTS 'exporter'@'%' IDENTIFIED BY '${EXPORTER_DB_PASSWORD}' WITH MAX_USER_CONNECTIONS 3;
ALTER USER 'exporter'@'%' IDENTIFIED BY '${EXPORTER_DB_PASSWORD}';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'%';
FLUSH PRIVILEGES;
SQL
echo "Exporter user ready"
