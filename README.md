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

Trình duyệt sẽ cảnh báo chứng chỉ tự ký: chọn *Advanced → Proceed*.

## Cấu trúc
```
docker-compose.yml
nginx/            nginx.conf, conf.d/, certs/ (tự sinh)
scripts/          gen-env.sh, gen-cert.sh
```

## Dừng / xóa
```bash
docker compose down        # giữ dữ liệu
docker compose down -v     # xóa cả dữ liệu
```
