# HƯỚNG DẪN TỪ A ĐẾN Z – Đề 7: Hệ thống Blog/CMS

Stack: **WordPress (php-fpm) + MySQL 8 + phpMyAdmin + Nginx + Prometheus + Grafana + Loki/Promtail**, tất cả bằng Docker Compose.
Repo này đã có sẵn **3 commit** đúng yêu cầu đề. Việc của bạn: chuẩn bị máy → chạy → chụp ảnh minh chứng → viết báo cáo → push GitHub → demo.

> **Quan trọng:** repo được kiểm tra cú pháp (`docker compose config`, YAML/JSON) nhưng **chưa được chạy thực tế trên máy có Docker daemon**. Bạn phải tự chạy và xử lý lỗi theo phần 10. Đây cũng là phần bạn cần hiểu để trả lời vấn đáp.

---

## MỤC LỤC
1. Chuẩn bị môi trường
2. Tạo GitHub và đưa code lên
3. Bước 1 – Triển khai ứng dụng + DB + Nginx (Commit 1)
4. Bước 2 – Prometheus + Grafana (Commit 2)
5. Bước 3 – Loki + Promtail + LogQL (Commit 3)
6. Bước 4 – Hardening
7. Danh sách ảnh chụp cần có
8. Viết báo cáo
9. Kịch bản demo + câu hỏi vấn đáp
10. Xử lý lỗi thường gặp
11. Checklist nộp bài

---

## 1. Chuẩn bị môi trường

### 1.1 Máy chủ
Khuyến nghị: Ubuntu Server 22.04/24.04 (máy ảo VirtualBox/VMware/WSL2 đều được), tối thiểu **2 CPU, 4 GB RAM, 20 GB ổ đĩa**. (Chạy 12 container, 2 GB sẽ rất chật.)

Lưu ý khi dùng **Docker Desktop trên Windows/macOS**: cAdvisor và node-exporter không đọc được đúng thông tin host → một số panel sẽ trống. Nên dùng Ubuntu (VM hoặc WSL2 có Docker Engine) để demo đầy đủ.

### 1.2 Cài Docker Engine + Compose (Ubuntu)
```bash
sudo apt update && sudo apt install -y ca-certificates curl git openssl
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
newgrp docker            # hoặc đăng xuất/đăng nhập lại
docker --version
docker compose version   # phải là Compose v2
```
Kiểm tra: `docker run --rm hello-world` chạy được.

### 1.3 Kiểm tra cổng trống
```bash
sudo ss -tlnp | grep -E ':(80|443|3000|9090|9443)\b' || echo "Các cổng đều trống"
```
Nếu 80/443 đang bị Apache/Nginx cài sẵn chiếm: `sudo systemctl disable --now apache2 nginx`.

### 1.4 Cấu hình git
```bash
git config --global user.name  "Họ Tên Của Bạn"
git config --global user.email "dtc245180062@ictu.edu.vn"
```

---

## 2. Tạo GitHub và đưa code lên

1. Tạo tài khoản GitHub **đặt tên theo MSSV** (ví dụ `dtc245180062`). Nếu đã có tài khoản khác, tạo tài khoản mới hoặc hỏi giảng viên xem có chấp nhận repo đặt tên theo MSSV không.
2. Tạo repo mới tên `dtc245180062-blog-cms`, **Public** (hoặc Private rồi mời giảng viên), **không** tick “Add README”.
3. Tạo Personal Access Token: GitHub → Settings → Developer settings → Personal access tokens → *Fine-grained* → quyền *Contents: Read and write* cho repo này. (Hoặc dùng SSH key.)
4. Giải nén gói code, vào thư mục:
   ```bash
   cd dtc245180062-blog-cms
   git log --oneline          # phải thấy 3 commit
   ```
5. **Đổi tác giả commit sang tên bạn** (các commit sinh sẵn có tác giả mặc định):
   ```bash
   git rebase -r --root --exec 'git commit --amend --reset-author --no-edit'
   git log --format='%h %an <%ae> %s'
   ```
6. Sửa dòng đầu `README.md`: điền **họ tên, lớp** của bạn rồi commit bổ sung:
   ```bash
   git add README.md && git commit -m "Cap nhat thong tin sinh vien trong README"
   ```
7. Đẩy lên GitHub:
   ```bash
   git remote add origin https://github.com/<ten-github>/dtc245180062-blog-cms.git
   git push -u origin main     # username = tên GitHub, password = token
   ```
8. Mở repo trên web, chụp ảnh **danh sách commit** (Commits → 3 commit + commit README) → **ảnh #1**.

> Mẹo thầy hay hỏi: mỗi commit tương ứng bước nào? → Commit 1: app+DB+Nginx; Commit 2: Prometheus+Grafana; Commit 3: Loki+Promtail. Hardening rải đều trong cả 3 commit và được kiểm chứng bằng `scripts/verify.sh`.

### Nếu thầy yêu cầu bạn “tự tay commit từng bước”
Có thể xóa `.git`, `git init` lại và commit theo nhóm file:
- **Commit 1:** `docker-compose.yml` (phần db/wordpress/phpmyadmin/nginx), `nginx/`, `scripts/gen-env.sh`, `scripts/gen-cert.sh`, `.env.example`, `.gitignore`, `README.md`
- **Commit 2:** `monitoring/prometheus`, `monitoring/grafana`, `mysql/init`, các service prometheus/grafana/cadvisor/node-exporter/nginx-exporter/mysqld-exporter
- **Commit 3:** `monitoring/loki`, `monitoring/promtail`, `docs/logql-queries.md`, `scripts/gen-traffic.sh`
Cách dễ nhất là giữ nguyên lịch sử sẵn có (đã đúng cấu trúc đó).

---

## 3. BƯỚC 1 – Triển khai ứng dụng + DB + Nginx (Commit 1)

### 3.1 Hiểu kiến trúc (để vẽ hình trong báo cáo)
```
Trình duyệt ──HTTPS 443──▶ Nginx ──FastCGI 9000──▶ WordPress (php-fpm) ──3306──▶ MySQL
                  │                                                         ▲
                  └──HTTPS 9443 (Basic Auth)──▶ phpMyAdmin ─────────3306────┘
```
- **Nginx** là cổng vào duy nhất: chuyển HTTP→HTTPS, gắn security headers, phục vụ file tĩnh, đẩy `.php` sang WordPress, bảo vệ phpMyAdmin bằng Basic Auth.
- **WordPress** dùng ảnh `php-fpm` (chỉ xử lý PHP) nên cần Nginx đứng trước; chia sẻ volume `wp_data` với Nginx để Nginx đọc file tĩnh.
- **MySQL** nằm trong mạng `database` (internal) → không ai từ ngoài chạm tới được.

### 3.2 Chạy
```bash
cd dtc245180062-blog-cms
./scripts/gen-env.sh                 # tạo .env, mật khẩu ngẫu nhiên 24 ký tự
./scripts/gen-cert.sh localhost      # cert tự ký + .htpasswd
#   Nếu truy cập từ máy khác tới VM:  ./scripts/gen-cert.sh 192.168.x.x
docker compose up -d
docker compose ps
```
Lần đầu sẽ kéo ảnh về (vài phút). Chờ `db` ở trạng thái `healthy`.

Xem mật khẩu: `cat .env` (đừng đưa file này lên GitHub – đã nằm trong `.gitignore`).

> Nếu chỉ muốn thử Commit 1 trước (để chụp ảnh đúng thời điểm), chạy: `docker compose up -d db wordpress phpmyadmin nginx`. Nếu đã chạy cả bộ thì bỏ qua.

### 3.3 Cài đặt WordPress và tạo dữ liệu (đề yêu cầu: bài viết, danh mục, người dùng)
1. Mở `https://localhost` (hoặc `https://<IP-VM>`) → chấp nhận cảnh báo chứng chỉ tự ký → **ảnh #2** (cảnh báo/ổ khóa).
2. Chọn ngôn ngữ → nhập: *Site Title*, *Username* (đừng dùng `admin`), *Password* mạnh, *Email*.
3. Đăng nhập `https://localhost/wp-admin`.
4. **Danh mục:** Bài viết → Danh mục → tạo 3 danh mục (ví dụ *Công nghệ*, *DevOps*, *Đời sống*).
5. **Bài viết:** Bài viết → Viết bài mới → tạo ≥ 3 bài, gán danh mục, **Đăng**.
6. **Người dùng:** Người dùng → Thêm mới → tạo 1 *Author* và 1 *Editor*.
7. Xem trang chủ hiển thị bài viết → **ảnh #3** (trang chủ), **ảnh #4** (danh sách bài viết/danh mục/người dùng trong wp-admin).

### 3.4 phpMyAdmin
1. Mở `https://localhost:9443` → hộp thoại Basic Auth: user/password là `PMA_BASIC_USER/PMA_BASIC_PASSWORD` trong `.env`.
2. Màn hình đăng nhập phpMyAdmin: user `wp_user` (hoặc `root`), mật khẩu tương ứng trong `.env`.
3. Mở DB `wordpress` → bảng `wp_posts`, `wp_terms`, `wp_users` → **ảnh #5**. Cho thấy bài viết vừa tạo nằm trong DB (chứng minh kết nối app↔DB thành công).

### 3.5 Kiểm tra Nginx
```bash
curl -I http://localhost                    # 301 -> https
curl -skI https://localhost                 # xem security headers
curl -sk -o /dev/null -w '%{http_code}\n' https://localhost/xmlrpc.php   # 403
docker compose exec nginx nginx -t          # cú pháp cấu hình OK
```
**Ảnh #6:** output `curl -skI` thấy `Strict-Transport-Security`, `X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy`.
**Ảnh #7:** `docker compose ps` toàn bộ container Up/healthy.

### 3.6 Giải thích cấu hình Nginx (học để trả lời vấn đáp)
| Thành phần | Ý nghĩa |
|---|---|
| `listen 8080` → `return 301 https://…` | Ép HTTPS. Cổng 8080 trong container được map ra 80 vì image *unprivileged* không bind được cổng <1024 |
| `ssl_protocols TLSv1.2 TLSv1.3` | Tắt TLS cũ |
| `fastcgi_pass wordpress:9000` | Nginx là reverse proxy tới php-fpm; `wordpress` là tên DNS nội bộ của Docker |
| `fastcgi_param HTTPS on` | Cho WordPress biết nó đang chạy sau HTTPS (tránh vòng lặp redirect/mixed content) |
| `limit_req zone=login rate=5r/m` | Giới hạn 5 lần/phút cho `/wp-login.php` → chống dò mật khẩu |
| `location = /xmlrpc.php { deny all; }` | Chặn vector tấn công phổ biến của WordPress |
| `server_tokens off` | Ẩn phiên bản Nginx |
| `add_header … always` | Security headers (HSTS, X-Frame-Options, nosniff, Referrer-Policy, Permissions-Policy) |
| `auth_basic` ở cổng 9443 | Lớp xác thực thứ nhất trước khi tới phpMyAdmin |
| `log_format logfmt` | Log dạng `key=value` để LogQL dùng `| logfmt` |

---

## 4. BƯỚC 2 – Prometheus + Grafana (Commit 2)

### 4.1 Các thành phần
| Thành phần | Vai trò | Giám sát đối tượng |
|---|---|---|
| cAdvisor | Metrics CPU/RAM/mạng từng container | **Container** |
| nginx-prometheus-exporter | Đọc `stub_status` của Nginx (cổng 8081 nội bộ) | **Web server** |
| mysqld-exporter | Truy vấn MySQL bằng user `exporter` (quyền tối thiểu) | **Database** |
| node-exporter | CPU/RAM/disk của máy chủ | Host |
| Prometheus | Thu thập (pull mỗi 15 s) và lưu 7 ngày | – |
| Grafana | Vẽ dashboard (đã provisioning sẵn) | – |

### 4.2 Chạy / kiểm tra
```bash
docker compose up -d
docker compose ps
```
> Nếu bạn đã khởi tạo DB từ trước (volume cũ), user `exporter` chưa có → chạy tay:
> `docker compose exec db bash /docker-entrypoint-initdb.d/02-exporter-user.sh`
> rồi `docker compose restart mysqld-exporter`.

1. Mở `http://localhost:9090/targets` → cả 5 job (`prometheus, cadvisor, node, nginx, mysql`) phải **UP** → **ảnh #8**.
2. Thử query trong Prometheus (tab Graph) → **ảnh #9**:
   - `up`
   - `rate(nginx_http_requests_total[1m])`
   - `mysql_global_status_threads_connected`
   - `sum by (name) (rate(container_cpu_usage_seconds_total{name=~"blogcms-.+"}[1m]))`
3. Mở `http://localhost:3000` → đăng nhập bằng `GRAFANA_ADMIN_USER/PASSWORD` trong `.env` (Grafana sẽ không bắt đổi mật khẩu vì đã đặt qua biến môi trường).
4. Dashboards → thư mục **Blog CMS** → **Blog CMS - Tổng quan hệ thống**.
5. Tạo tải để biểu đồ có dữ liệu: `./scripts/gen-traffic.sh 100`
6. Chụp **ảnh #10** (hàng trạng thái dịch vụ – tất cả UP), **#11** (container CPU/RAM), **#12** (Nginx connections/requests), **#13** (MySQL connections/queries), **#14** (máy chủ).
7. (Tùy chọn, ăn điểm) Import thêm dashboard cộng đồng: Dashboards → New → Import → nhập ID (ví dụ **14282** cho cAdvisor, **7362** cho MySQL Overview; số ID có thể thay đổi, nếu không đúng hãy tìm trên grafana.com/grafana/dashboards) → chọn datasource Prometheus. *Máy trong lab có thể không ra được Internet để import – khi đó bỏ qua, dashboard tự viết đã đủ yêu cầu.*

---

## 5. BƯỚC 3 – Loki + Promtail + LogQL (Commit 3)

### 5.1 Cách hoạt động
```
Mọi container ──stdout/stderr──▶ Docker log ──(Docker socket)──▶ Promtail ──push──▶ Loki ◀──query── Grafana (Explore)
```
Promtail gắn nhãn `container`, `service`, `compose_project`. Loki chỉ index nhãn (nhẹ), nội dung log lọc bằng LogQL.

### 5.2 Thực hành
1. `docker compose logs promtail | tail` – phải thấy đã tìm thấy container, không lỗi kết nối Loki.
2. `./scripts/gen-traffic.sh 50` để sinh log (có 404, 401, 403, đăng nhập sai).
3. Grafana → **Explore** → datasource **Loki**. Chạy và chụp ảnh các query (file `docs/logql-queries.md` có 11 query):
   | Ảnh | Query | Ý nghĩa |
   |---|---|---|
   | #15 | `{service="nginx"}` | Toàn bộ log Nginx (stream selector) |
   | #16 | `{service="nginx"} \|~ "status=5\\d\\d"` hoặc `{service="nginx"} \| logfmt \| status >= 400` | Lọc request lỗi (line filter / parser) |
   | #17 | `sum(rate({service="nginx"}[1m]))` | Số request/giây (metric query) |
   | #18 | `sum by (status) (count_over_time({service="nginx"} \| logfmt [5m]))` | Đếm theo mã status |
   | #19 | `{service="db"} \|~ "(?i)error\|warning"` | Log lỗi MySQL |
4. Dashboard *Tổng quan hệ thống* kéo xuống cuối có panel Loki (**ảnh #20**).

### 5.3 Giải thích 3 loại biểu thức LogQL (vấn đáp)
- **Log stream selector:** `{service="nginx"}` – chọn luồng log theo nhãn.
- **Line filter:** `|=` chứa, `!=` không chứa, `|~` regex.
- **Parser + label filter:** `| logfmt | status >= 400` – tách `key=value` thành nhãn rồi lọc.
- **Metric query:** `rate()`, `count_over_time()`, `sum by()` – biến log thành số để vẽ biểu đồ.

---

## 6. BƯỚC 4 – Hardening

Chạy kiểm tra tự động, chụp **ảnh #21**:
```bash
./scripts/verify.sh
```

### 6.1 Bảng biện pháp (đề yêu cầu ≥ 3–4; hệ thống này có 10)
| # | Biện pháp | Thực hiện ở đâu | Cách chứng minh |
|---|---|---|---|
| 1 | **Non-root container** | Nginx (`nginx-unprivileged` uid 101), WordPress `user: 82:82`, Prometheus/exporters `65534`, Grafana `472`, Loki `10001` | `docker exec blogcms-nginx id` → ảnh **#22** |
| 2 | **Network isolation** | 3 mạng: `frontend`, `database` (`internal: true`), `monitoring` (`internal: true`) | `docker network inspect blogcms_database \| grep Internal` → ảnh **#23** |
| 3 | **Không publish port nhạy cảm** | MySQL, phpMyAdmin, Loki, exporters không có `ports:`; Prometheus bind `127.0.0.1` | `docker compose ps` / `docker port blogcms-db` (rỗng) |
| 4 | **Mật khẩu mạnh, không hard-code** | `gen-env.sh` sinh 24 ký tự ngẫu nhiên; `.env` quyền 600, nằm trong `.gitignore` | `ls -l .env`, `git check-ignore .env` |
| 5 | **Hạn chế quyền DB** | `wp_user` chỉ có quyền trên DB `wordpress`; `exporter` chỉ `PROCESS, REPLICATION CLIENT, SELECT` và tối đa 3 kết nối | phpMyAdmin → User accounts, hoặc `SHOW GRANTS` → ảnh **#24** |
| 6 | **Security headers Nginx** | HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy | `curl -skI https://localhost` |
| 7 | **TLS** | TLS 1.2/1.3, cert tự ký, HTTP→HTTPS | `curl -I http://localhost` |
| 8 | **Chống brute-force + chặn endpoint** | `limit_req` cho wp-login, chặn xmlrpc, file ẩn, PHP trong uploads, `wp-config.php` | `gen-traffic.sh` rồi xem 403/503 trong log |
| 9 | **Bảo vệ phpMyAdmin** | Chỉ vào qua Nginx cổng 9443 + Basic Auth; `PMA_ARBITRARY=0` (không cho nhập host tùy ý) | Truy cập không user → 401 |
| 10 | **Giảm đặc quyền kernel** | `no-new-privileges`, `cap_drop: ALL` cho Nginx/WordPress/Prometheus/Grafana/Loki/exporters; `DISALLOW_FILE_EDIT` trong WordPress | `docker inspect -f '{{.HostConfig.CapDrop}}' blogcms-nginx` |

### 6.2 Ngoại lệ có chủ đích (nên nói thật khi vấn đáp)
- **cAdvisor** chạy `privileged` vì cần đọc cgroup của host.
- **Promtail** chạy root và mount `docker.sock` **chỉ đọc** để đọc log container (quyền đọc socket vẫn rất nhạy cảm – trong sản phẩm thật nên dùng Docker logging driver `loki` hoặc agent tách riêng).
- **MySQL, phpMyAdmin** không chạy `user:` non-root riêng: MySQL tự hạ quyền xuống user `mysql` sau khi khởi tạo; phpMyAdmin (Apache) bind cổng 80 nên master process là root, worker là `www-data`. Hai container này chỉ dùng `no-new-privileges` và nằm trong mạng nội bộ.
- Chứng chỉ tự ký → trình duyệt cảnh báo; môi trường thật dùng Let’s Encrypt.
- Grafana publish cổng 3000 qua HTTP: trong sản phẩm thật nên đặt sau Nginx + HTTPS.

---

## 7. Danh sách ảnh chụp (đặt tên file vào `docs/images/`)

| # | Nội dung | Ở đâu |
|---|---|---|
| 1 | Danh sách commit trên GitHub (3 commit + README) | GitHub |
| 2 | Cảnh báo cert tự ký / ổ khóa HTTPS | Trình duyệt |
| 3 | Trang chủ blog có bài viết | `https://localhost` |
| 4 | wp-admin: bài viết, danh mục, người dùng | wp-admin |
| 5 | phpMyAdmin: bảng `wp_posts` có dữ liệu | `:9443` |
| 6 | `curl -skI` thấy security headers | Terminal |
| 7 | `docker compose ps` | Terminal |
| 8 | Prometheus Targets: tất cả UP | `:9090/targets` |
| 9 | Prometheus Graph: 1–2 query | `:9090` |
| 10–14 | Grafana dashboard (trạng thái, container, Nginx, MySQL, host) | `:3000` |
| 15–19 | Grafana Explore: 5 query LogQL | `:3000` |
| 20 | Dashboard có panel log Loki | `:3000` |
| 21 | Kết quả `./scripts/verify.sh` | Terminal |
| 22 | `docker exec … id` non-root | Terminal |
| 23 | `docker network inspect` internal | Terminal |
| 24 | `SHOW GRANTS` / User accounts | phpMyAdmin |
| 25 | Cấu trúc thư mục `tree -L 2` | Terminal |
| 26 | Sơ đồ kiến trúc (vẽ bằng draw.io hoặc dùng sơ đồ trong báo cáo mẫu) | – |

Chụp ảnh nên thấy **thanh địa chỉ** và **thời gian/hostname** để chứng minh là máy của bạn.

---

## 8. Viết báo cáo (≥ 10 trang)

Dùng file khung `BaoCao_DTC245180062_De7.docx` được gửi kèm (ngoài repo, vì báo cáo nộp riêng). Cấu trúc:

- **Bìa:** trường, khoa, tên môn, đề tài (“Đề 7: Hệ thống Blog/CMS”), họ tên – MSSV – lớp, giảng viên hướng dẫn, năm học.
- **Mục lục, danh mục hình**
- **Chương 1 – Giới thiệu:** mục tiêu, phạm vi, công nghệ (mỗi công nghệ 2–3 câu).
- **Chương 2 – Kiến trúc hệ thống:** sơ đồ, vai trò từng container, các mạng, các volume, luồng request.
- **Chương 3 – Triển khai và kết quả:** 3.1 GitHub (ảnh #1) · 3.2 Ứng dụng + DB (ảnh #2–5, #7) · 3.3 Nginx (ảnh #6) · 3.4 Prometheus+Grafana (ảnh #8–14) · 3.5 Loki/LogQL (ảnh #15–20) · 3.6 Hardening (ảnh #21–24).
- **Chương 4 – Đánh giá:** kiểm thử, hạn chế, hướng cải tiến (Let’s Encrypt, alert rules, backup DB, WAF…).
- **Kết luận · Tài liệu tham khảo · Phụ lục** (mã nguồn các file cấu hình chính).

Mỗi ảnh phải có **chú thích “Hình x.y – …”** và **1–2 đoạn giải thích** ngay dưới (ảnh này chứng minh điều gì, cấu hình nào tạo ra kết quả này). Định dạng thường dùng: Times New Roman 13, giãn dòng 1.3–1.5, lề trái 3 cm, các lề khác 2 cm, đánh số trang. Hãy hỏi lại giảng viên nếu khoa có mẫu bìa riêng.

---

## 9. Kịch bản demo (10–15 phút) + câu hỏi vấn đáp

### 9.1 Kịch bản
1. GitHub: cho xem 3 commit và README (1 phút).
2. Terminal: `docker compose down -v && docker compose up -d` hoặc `docker compose ps` để chứng minh chạy bằng compose (1 phút). *Chỉ làm `down -v` nếu bạn đã chắc chắn chạy lại được, vì nó xóa dữ liệu.*
3. Website: mở blog, đăng 1 bài mới ngay trước mặt thầy (1–2 phút).
4. phpMyAdmin: tìm bài vừa đăng trong `wp_posts` (1 phút).
5. Nginx: `curl -skI`, cho thấy headers + chuyển hướng HTTP→HTTPS (1 phút).
6. Grafana: dashboard, chạy `gen-traffic.sh` và nhìn biểu đồ tăng (2 phút).
7. Loki: chạy 2–3 query LogQL, tìm đúng request 404/đăng nhập sai vừa tạo (2 phút).
8. Hardening: `./scripts/verify.sh`, `docker exec blogcms-nginx id` (2 phút).

### 9.2 Câu hỏi thường gặp
- *Tại sao WordPress dùng php-fpm chứ không dùng ảnh Apache?* → Tách web server và PHP, Nginx chịu tải tĩnh tốt hơn, chạy non-root dễ hơn.
- *Vì sao MySQL không map cổng ra host?* → Giảm bề mặt tấn công; chỉ container cùng mạng `database` truy cập được; mạng này `internal`.
- *Prometheus pull hay push? Khác gì Loki?* → Prometheus kéo metrics (số) theo chu kỳ 15 s; Promtail đẩy log (văn bản) vào Loki; Loki chỉ index nhãn.
- *Làm sao biết container nào chiếm RAM nhiều nhất?* → cAdvisor + query `container_memory_working_set_bytes`.
- *Nếu một container chết thì sao?* → `restart: unless-stopped`; `mysql_up`/`nginx_up`/`up` về 0 trên dashboard.
- *Cách khôi phục DB?* → `docker compose exec db mysqldump …` và volume `db_data` (nêu cách backup: `docker compose exec -T db sh -c 'mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" wordpress' > backup.sql`).
- *HTTPS tự ký có an toàn không?* → Mã hóa được đường truyền nhưng không xác thực danh tính; sản phẩm thật dùng Let’s Encrypt.
- *Network internal nghĩa là gì?* → Docker không tạo route ra ngoài và không cho publish port; chỉ container trong network trao đổi được.

---

## 10. Xử lý lỗi thường gặp

| Triệu chứng | Nguyên nhân hay gặp | Cách xử lý |
|---|---|---|
| `bind: address already in use` | Cổng 80/443/3000 bị chiếm | Tắt dịch vụ đang chiếm hoặc đổi cổng bên trái dấu `:` trong `ports:` |
| Nginx không lên, log báo `.htpasswd` / `server.crt` | Chưa chạy `gen-cert.sh` (Docker tự tạo thư mục rỗng thay file) | `docker compose down`, xóa `nginx/.htpasswd` nếu nó là thư mục, chạy `./scripts/gen-cert.sh`, `up -d` |
| Nginx `permission denied` đọc `server.key` | Quyền file | `chmod 644 nginx/certs/server.key` (script đã làm) |
| `502 Bad Gateway` | WordPress chưa sẵn sàng hoặc lỗi | `docker compose logs wordpress`; đợi DB healthy; `docker compose restart wordpress` |
| WordPress: “Error establishing a database connection” | Đổi mật khẩu `.env` sau khi DB đã khởi tạo | Mật khẩu DB chỉ áp dụng lần tạo đầu. Làm sạch: `docker compose down -v` rồi `up -d` (mất dữ liệu) |
| WordPress/Nginx báo `Permission denied` ghi `wp-content` | Volume cũ thuộc root | `docker compose down -v` rồi chạy lại (volume mới tự lấy quyền của image) |
| Trình duyệt “quá nhiều lần chuyển hướng” | Thiếu `fastcgi_param HTTPS on` | Đã có sẵn; kiểm tra file `nginx/conf.d/default.conf` chưa bị sửa |
| Chỉ vào được bằng `localhost`, không vào bằng IP | Cert/URL đặt cố định theo lần cài | Cài WP khi đã truy cập bằng đúng địa chỉ sẽ dùng demo. Nếu đã cài bằng `localhost`: đổi trong wp-admin → Cài đặt → Chung, hoặc đặt lại bằng `docker compose down -v` |
| Prometheus target `mysql` DOWN | Chưa có user `exporter` | Xem mục 4.2 |
| Target `cadvisor` UP nhưng panel container trống | cAdvisor không nhận ra tên container (một số bản Docker dùng containerd image store) | Thử đổi image sang `ghcr.io/google/cadvisor:<phiên bản mới nhất>`; xem `docker compose logs cadvisor` |
| `cadvisor` lỗi `/dev/kmsg` | Máy không có thiết bị này (WSL2/Docker Desktop) | Xóa dòng `devices: - /dev/kmsg` |
| Grafana panel “No data” | Chưa có traffic / sai khoảng thời gian | `./scripts/gen-traffic.sh 100`, chọn “Last 15 minutes”, đợi 30–60 s |
| Loki Explore không có nhãn `service` | Promtail chưa thu | `docker compose logs promtail`; xác nhận container có nhãn compose project `blogcms` (`name:` đầu file compose) |
| Loki không start vì quyền `/loki` | Volume cũ | `docker compose down`; `docker volume rm blogcms_loki_data`; `up -d` |
| Một container không chạy sau khi thêm `cap_drop` | Image cần capability | Xóa dòng `cap_drop` của riêng service đó và ghi chú trong báo cáo |
| `no space left on device` | Hết dung lượng | `docker system prune -af` (cẩn thận, xóa ảnh/mạng chưa dùng) |

Lệnh gỡ rối cơ bản:
```bash
docker compose ps
docker compose logs --tail=100 <service>
docker compose exec <service> sh
docker compose config            # kiểm tra cú pháp sau khi sửa
docker compose up -d --force-recreate <service>
```

---

## 11. Checklist nộp bài
- [ ] Repo GitHub đặt tên theo MSSV, có ≥ 3 commit rõ ràng, README hướng dẫn chạy
- [ ] `.env`, `*.key`, `.htpasswd` **không** có trong repo
- [ ] `docker compose up -d` chạy từ đầu (máy sạch) thành công
- [ ] Website blog có bài viết/danh mục/người dùng
- [ ] phpMyAdmin xem được dữ liệu
- [ ] Nginx: HTTPS + security headers
- [ ] Prometheus: 5 target UP; Grafana: dashboard container/web/DB
- [ ] Loki: ≥ 3 query LogQL chạy được
- [ ] Hardening: ≥ 4 biện pháp có minh chứng (hệ thống này có 10)
- [ ] Báo cáo ≥ 10 trang, bìa đủ thông tin, mỗi bước có hình + giải thích
- [ ] Hiểu từng file cấu hình (đọc lại phần 3.6, 4.1, 5.3, 6.1, 6.2, 9.2)
