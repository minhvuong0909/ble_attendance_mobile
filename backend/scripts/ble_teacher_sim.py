"""Giả máy giảng viên bằng Bluetooth của laptop (để thử khi chỉ có 1 điện thoại).

Điện thoại đăng nhập sinh viên và mở app khi buổi học đang diễn ra; script này quét
gói quảng cáo của điện thoại và gửi detection lên server như app giảng viên.

    .venv/bin/python scripts/ble_teacher_sim.py --url http://localhost:8000 --teacher T001
"""
import argparse
import asyncio
import time

import httpx
from bleak import BleakScanner

COMPANY_ID = 0xFFFF
BUCKET = 30


def decode_student(data: bytes):
    if len(data) < 6 or len(data) > 21 or data[0] != 0x02:
        return None
    return data[5:].decode("ascii", "replace"), data[1:5].hex()


async def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", default="http://localhost:8000")
    ap.add_argument("--teacher", default="GV1")
    ap.add_argument("--password", default="123456")
    ap.add_argument("--class-code", default=None, help="mã lớp để mở buổi nếu chưa có")
    args = ap.parse_args()

    api = httpx.Client(base_url=args.url, timeout=10)
    token = api.post("/auth/login", json={"identifier": args.teacher, "password": args.password}).json()["access_token"]
    api.headers["Authorization"] = f"Bearer {token}"
    session = api.get("/sessions/active")
    if session.status_code == 404:
        classes = api.get("/classes/mine").json()
        cls = next((c for c in classes if args.class_code in (None, c["class_code"])), None)
        if cls is None:
            raise SystemExit("Giảng viên chưa có lớp nào.")
        session = api.post(f"/classes/{cls['id']}/sessions")
        print("Đã mở buổi học mới cho lớp", cls["class_code"])
    session = session.json()
    sid = session["id"]
    print(f"Buổi {sid} ({session['course_code']}). Mở app sinh viên trên điện thoại... Ctrl+C để kết thúc.")

    last_seen: dict[str, float] = {}
    queue: list[dict] = []
    flushed = time.time()

    def on_adv(device, adv):
        data = adv.manufacturer_data.get(COMPANY_ID)
        if data is None:
            return
        parsed = decode_student(bytes(data))
        now = time.time()
        if parsed is None:
            print(f"Gói lạ ({len(data)} byte): {bytes(data).hex()}")
            return
        student, tag = parsed
        if now - last_seen.get(student, 0) < 5:
            return
        last_seen[student] = now
        print(f"Thấy {student} tag={tag} rssi={adv.rssi}")
        queue.append({
            "session_id": sid,
            "student_identifier": student,
            "bucket": int(now // BUCKET),
            "tag": tag,
            "rssi": adv.rssi,
            "observed_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now)),
        })

    async with BleakScanner(on_adv):
        while True:
            await asyncio.sleep(1)
            if queue and time.time() - flushed >= 10:
                batch, queue[:] = list(queue), []
                resp = api.post("/detections/batch", json={"detections": batch})
                print("Gửi", len(batch), "->", resp.status_code, resp.json())
                flushed = time.time()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
