#!/usr/bin/env bash
# Build bản web của app Flutter và đặt vào backend/web_dist (phục vụ tại /app/).
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
app="$here/../mobile/ble_attendance_mobile"
(cd "$app" && flutter build web --release --base-href /app/)
rm -rf "$here/web_dist"
cp -r "$app/build/web" "$here/web_dist"
echo "Đã build web vào $here/web_dist. Mở http://<IP-máy>:8000/app/"
