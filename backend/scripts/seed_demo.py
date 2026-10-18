import os
import sys

ROOT = os.path.dirname(os.path.dirname(__file__))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

from app.core.database import SessionLocal
from app.services.seed import seed


def main() -> None:
    db = SessionLocal()
    try:
        result = seed(db)
        print("Seed xong: admin A001, giảng viên T001, sinh viên 25CE099/25CE100/D26CE045")
        print(f"Mã lớp SE1901: {result['join_code']}")
    finally:
        db.close()


if __name__ == "__main__":
    main()
