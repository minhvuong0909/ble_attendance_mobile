"""In openapi.json của backend ra stdout (dùng để sinh kiểu TypeScript cho web)."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.main import app  # noqa: E402

json.dump(app.openapi(), sys.stdout, ensure_ascii=False, indent=1)
