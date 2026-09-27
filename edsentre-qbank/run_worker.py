"""
نقطة الدخول لتشغيل الـ Worker.
الاستخدام:
  cd edsentre-qbank
  python run_worker.py
أو مع متغيرات البيئة:
  $env:SUPABASE_URL="https://xxx.supabase.co"
  $env:SUPABASE_SERVICE_ROLE_KEY="eyJ..."
  python run_worker.py
"""
import os
import sys
from pathlib import Path

# أضف المجلد الأصلي لـ sys.path
sys.path.insert(0, str(Path(__file__).parent))

# تحميل .env إذا كانت موجودة
env_file = Path(__file__).parent.parent / ".env"
if env_file.exists():
    for line in env_file.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key not in os.environ:
            os.environ[key] = value
    print(f"[run_worker] Loaded .env from {env_file}")

from services.worker.runner import main
main()
