"""Giả máy sinh viên bằng Bluetooth của laptop (thử khi chỉ có 1 điện thoại).

Điện thoại đăng nhập giảng viên và có buổi đang diễn ra. Script đăng nhập một sinh viên
trong lớp, lấy khóa buổi, rồi phát gói BLE (company id 0xFFFF) với tag HMAC đổi mỗi 30 giây
bằng `bluetoothctl`.

    .venv/bin/python scripts/ble_student_sim.py --url http://localhost:8000 --student 25CE099
"""
import argparse
import hashlib
import hmac
import subprocess
import time

import httpx

BUCKET = 30


def make_tag(secret: str, bucket: int) -> str:
    return hmac.new(secret.encode(), str(bucket).encode(), hashlib.sha256).hexdigest()[:8]


def payload(student_id: str, tag: str) -> list[str]:
    data = [0x02, *bytes.fromhex(tag), *student_id.upper().encode("ascii")]
    return [f"0x{b:02x}" for b in data]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", default="http://localhost:8000")
    ap.add_argument("--student", default="25CE099")
    ap.add_argument("--password", default="Pass@123")
    args = ap.parse_args()

    api = httpx.Client(base_url=args.url, timeout=10)
    token = api.post("/auth/login", json={"identifier": args.student, "password": args.password}).json()["access_token"]
    api.headers["Authorization"] = f"Bearer {token}"
    while True:
        resp = api.get("/sessions/active")
        if resp.status_code == 200:
            break
        print("Chưa có buổi đang diễn ra, đợi giảng viên bắt đầu...")
        time.sleep(5)
    session = resp.json()
    secret = session["beacon_secret"]
    print(f"Buổi {session['id']} ({session['course_code']}), phát gói của {args.student}. Ctrl+C để dừng.")

    ctl = subprocess.Popen(["bluetoothctl"], stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, text=True)

    def send(*lines: str) -> None:
        for line in lines:
            ctl.stdin.write(line + "\n")
        ctl.stdin.flush()

    bucket = None
    try:
        send("menu advertise", "clear", "name off", "discoverable off")
        while True:
            now_bucket = int(time.time() // BUCKET)
            if now_bucket != bucket:
                bucket = now_bucket
                tag = make_tag(secret, bucket)
                send("back", "advertise off", "menu advertise", "clear manufacturer",
                     "manufacturer 0xffff " + " ".join(payload(args.student, tag)), "back", "advertise on", "menu advertise")
                print(f"bucket {bucket} tag {tag}")
            time.sleep(1)
    except KeyboardInterrupt:
        pass
    finally:
        send("back", "advertise off", "exit")
        ctl.wait(timeout=5)


if __name__ == "__main__":
    main()
