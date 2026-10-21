# Truy vấn LogQL mẫu

Grafana → **Explore** → chọn datasource **Loki** → dán query → *Run query*.
Nhãn có sẵn: `container`, `service`, `compose_project`.

Tạo traffic trước bằng `./scripts/gen-traffic.sh`.

### 1. Xem toàn bộ log của Nginx
```logql
{service="nginx"}
```

### 2. Chỉ các request lỗi 5xx
```logql
{service="nginx"} |~ "status=5\\d\\d"
```

### 3. Request tới trang đăng nhập
```logql
{service="nginx"} |= "wp-login.php"
```

### 4. Parse logfmt, lọc status >= 400
```logql
{service="nginx"} | logfmt | status >= 400
```

### 5. Request chậm (> 1 giây)
```logql
{service="nginx"} | logfmt | rt > 1
```

### 6. Số request/giây của Nginx
```logql
sum(rate({service="nginx"}[1m]))
```

### 7. Số request theo mã status (5 phút)
```logql
sum by (status) (count_over_time({service="nginx"} | logfmt [5m]))
```

### 8. Log lỗi của MySQL
```logql
{service="db"} |~ "(?i)error|warning"
```

### 9. Log lỗi PHP / WordPress
```logql
{service="wordpress"} |~ "(?i)error|fatal|warning"
```

### 10. Tỉ lệ log lỗi theo từng service
```logql
sum by (service) (rate({compose_project="blogcms"} |~ "(?i)error" [5m]))
```

### 11. phpMyAdmin bị từ chối Basic Auth (401)
```logql
{service="nginx"} | logfmt | status = 401
```

