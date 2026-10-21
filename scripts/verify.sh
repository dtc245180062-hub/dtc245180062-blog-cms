#!/usr/bin/env bash
# Kiểm tra nhanh toàn bộ hệ thống + các biện pháp hardening. Dùng: ./scripts/verify.sh
cd "$(dirname "$0")/.."
ok(){ printf '  [ OK ] %s\n' "$1"; }
ko(){ printf '  [FAIL] %s\n' "$1"; FAILED=1; }
FAILED=0

echo "== 1. Container đang chạy =="
for s in db wordpress phpmyadmin nginx prometheus grafana cadvisor node-exporter nginx-exporter mysqld-exporter loki promtail; do
  st=$(docker inspect -f '{{.State.Status}}' blogcms-$s 2>/dev/null)
  [ "$st" = "running" ] && ok "blogcms-$s" || ko "blogcms-$s ($st)"
done

echo "== 2. Website & Nginx =="
code=$(curl -sk -o /dev/null -w '%{http_code}' https://localhost/); [[ "$code" =~ ^(200|302)$ ]] && ok "HTTPS WordPress ($code)" || ko "HTTPS WordPress ($code)"
code=$(curl -s -o /dev/null -w '%{http_code}' http://localhost/);  [ "$code" = "301" ] && ok "HTTP -> HTTPS redirect (301)" || ko "redirect ($code)"
code=$(curl -sk -o /dev/null -w '%{http_code}' https://localhost:9443/); [ "$code" = "401" ] && ok "phpMyAdmin yêu cầu Basic Auth (401)" || ko "phpMyAdmin ($code)"
code=$(curl -sk -o /dev/null -w '%{http_code}' https://localhost/xmlrpc.php); [ "$code" = "403" ] && ok "xmlrpc.php bị chặn (403)" || ko "xmlrpc ($code)"
hdr=$(curl -skI https://localhost/)
for h in strict-transport-security x-frame-options x-content-type-options referrer-policy; do
  echo "$hdr" | grep -qi "^$h" && ok "header $h" || ko "thiếu header $h"
done
echo "$hdr" | grep -i '^server:' | grep -qE '[0-9]+\.[0-9]+' && ko "Nginx lộ phiên bản" || ok "Nginx ẩn phiên bản (server_tokens off)"

echo "== 3. Hardening =="
for s in nginx wordpress prometheus grafana loki mysqld-exporter node-exporter; do
  u=$(docker exec blogcms-$s id -u 2>/dev/null); [ -n "$u" ] && [ "$u" != "0" ] && ok "$s chạy non-root (uid=$u)" || ko "$s chạy root hoặc không đọc được uid"
done
[ "$(docker network inspect -f '{{.Internal}}' blogcms_database)" = "true" ] && ok "network database là internal" || ko "network database chưa internal"
pub=$(docker port blogcms-db 2>/dev/null); [ -z "$pub" ] && ok "MySQL KHÔNG publish port ra host" || ko "MySQL đang publish: $pub"
pub=$(docker port blogcms-phpmyadmin 2>/dev/null); [ -z "$pub" ] && ok "phpMyAdmin KHÔNG publish port trực tiếp" || ko "phpMyAdmin đang publish: $pub"
set -a; . ./.env; set +a
g=$(docker exec blogcms-db mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -N -e "SHOW GRANTS FOR '$WP_DB_USER'@'%'" 2>/dev/null | tr '\n' ' ')
echo "$g" | grep -q "ON \`$WP_DB_NAME\`" && ! echo "$g" | grep -q "ON \*\.\*" && ok "wp_user chỉ có quyền trên DB $WP_DB_NAME" || ko "quyền wp_user bất thường: $g"
[ "$(stat -c %a .env)" = "600" ] && ok ".env quyền 600" || ko ".env nên là quyền 600"
git check-ignore -q .env && ok ".env nằm trong .gitignore" || ko ".env chưa được ignore"

echo "== 4. Giám sát & Log =="
down=$(curl -s http://localhost:9090/api/v1/targets | python3 -c "import sys,json;t=json.load(sys.stdin)['data']['activeTargets'];print(' '.join(x['labels']['job'] for x in t if x['health']!='up'))" 2>/dev/null)
[ -z "$down" ] && ok "Prometheus: mọi target UP" || ko "target DOWN: $down"
curl -s http://localhost:3000/api/health | grep -q '"database": "ok"' && ok "Grafana health ok" || ko "Grafana chưa sẵn sàng"
docker exec blogcms-grafana wget -qO- http://loki:3100/ready 2>/dev/null | grep -q ready && ok "Loki ready" || ko "Loki chưa ready"

echo; [ $FAILED = 0 ] && echo "TẤT CẢ ĐẠT" || echo "CÓ MỤC FAIL - xem docs/HUONG_DAN.md phần Xử lý lỗi"
exit $FAILED
