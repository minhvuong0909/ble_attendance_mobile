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
        seed(db)
        print("Seed xong (mật khẩu 123456): admin, gv1/gv2/gv3, sv1/sv2/sv3")
        print("4 lớp: PRM393 SE1901 (gv1, sv1-sv3), PRN232 SE1918 (gv2), MLN131 Half2_EL1902 (gv3), EXE201 SE1919 (gv2)")
    finally:
        db.close()


if __name__ == "__main__":
    main()
