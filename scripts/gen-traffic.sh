#!/usr/bin/env bash
# Tạo traffic mẫu (bao gồm 404, 401, 403) để có dữ liệu cho Grafana/LogQL.
# Dùng: ./scripts/gen-traffic.sh [số_vòng=50]
N="${1:-50}"
for i in $(seq 1 "$N"); do
  curl -sk -o /dev/null https://localhost/
  curl -sk -o /dev/null "https://localhost/?s=test$i"
  curl -sk -o /dev/null https://localhost/khong-ton-tai-$i           # 404
  curl -sk -o /dev/null https://localhost/xmlrpc.php                  # 403 (bị chặn)
  curl -sk -o /dev/null https://localhost:9443/                       # 401 (thiếu Basic Auth)
  curl -sk -o /dev/null -X POST -d "log=admin&pwd=sai" https://localhost/wp-login.php
done
echo "Đã gửi $((N*6)) request."
