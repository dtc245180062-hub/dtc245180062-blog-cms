# Đề 7 – Hệ thống Blog/CMS (WordPress + MySQL + phpMyAdmin + Nginx)

- Sinh viên: <HỌ TÊN> – MSSV: DTC245180062 – Lớp: <LỚP>
- Môn: Triển khai và Quản trị Hệ thống Phần mềm
- Stack: WordPress (php-fpm) · MySQL 8 · phpMyAdmin · Nginx reverse proxy (HTTPS tự ký)

## Yêu cầu
Docker Engine ≥ 24, Docker Compose v2, openssl, git. (Ubuntu 22.04/24.04 hoặc Docker Desktop.)

## Chạy hệ thống
```bash
git clone https://github.com/<user>/dtc245180062-blog-cms.git
cd dtc245180062-blog-cms
./scripts/gen-env.sh            # sinh .env với mật khẩu mạnh
./scripts/gen-cert.sh localhost # chứng chỉ tự ký + .htpasswd (hoặc truyền IP máy chủ)
docker compose up -d
docker compose ps
```

## Truy cập
| Thành phần | URL | Ghi chú |
|---|---|---|
| Website WordPress | https://localhost | Lần đầu: màn hình cài đặt WordPress |
| Trang quản trị | https://localhost/wp-admin | Tài khoản tạo lúc cài đặt |
| phpMyAdmin | https://localhost:9443 | Basic Auth (xem `.env`), sau đó đăng nhập MySQL bằng `wp_user` |
| Grafana | http://localhost:3000 | `GRAFANA_ADMIN_USER` / `GRAFANA_ADMIN_PASSWORD` trong `.env` |
| Prometheus | http://localhost:9090 | Chỉ truy cập từ chính máy chủ (bind 127.0.0.1) |

Trình duyệt sẽ cảnh báo chứng chỉ tự ký: chọn *Advanced → Proceed*.

## Cấu trúc
```
docker-compose.yml
nginx/            nginx.conf, conf.d/, certs/ (tự sinh)
mysql/init/       tạo user giám sát quyền tối thiểu
monitoring/       prometheus/, grafana/ (datasource + dashboard provisioning)
scripts/          gen-env.sh, gen-cert.sh
```

## Giám sát (Prometheus + Grafana)
- Prometheus thu thập: **cAdvisor** (container), **nginx-exporter** (web server), **mysqld-exporter** (database), **node-exporter** (máy chủ).
- Kiểm tra targets: http://localhost:9090/targets (tất cả phải `UP`).
- Grafana → Dashboards → *Blog CMS* → **Blog CMS - Tổng quan hệ thống** (đã provisioning sẵn).
- Nếu DB đã được tạo từ trước (volume cũ) thì tạo user giám sát bằng tay:
  `docker compose exec db bash /docker-entrypoint-initdb.d/02-exporter-user.sh`

## Dừng / xóa
```bash
docker compose down        # giữ dữ liệu
docker compose down -v     # xóa cả dữ liệu
```
