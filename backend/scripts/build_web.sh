#!/usr/bin/env bash
# Build bản web React (thư mục web/) và đặt vào backend/web_dist (backend phục vụ tại /app/).
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
web="$here/../web"
(cd "$web" && npm ci && npm run build)
rm -rf "$here/web_dist"
cp -r "$web/dist" "$here/web_dist"
echo "Đã build web vào $here/web_dist. Mở http://<IP-máy>:8000/app/"
