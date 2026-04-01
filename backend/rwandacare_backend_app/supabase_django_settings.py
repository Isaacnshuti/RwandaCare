"""
Drop-in Django DATABASES settings for Supabase PostgreSQL.

Usage in your project settings.py:

from pathlib import Path
from dotenv import load_dotenv
load_dotenv(Path(BASE_DIR) / ".env")

from .supabase_django_settings import DATABASES
"""

import os
from urllib.parse import parse_qs, unquote, urlparse


def _database_from_url(url: str):
    parsed = urlparse(url)
    query = parse_qs(parsed.query)
    sslmode = query.get("sslmode", ["require"])[0]

    return {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": (parsed.path or "").lstrip("/") or "postgres",
        "USER": unquote(parsed.username or "postgres"),
        "PASSWORD": unquote(parsed.password or ""),
        "HOST": parsed.hostname or "localhost",
        "PORT": str(parsed.port or 5432),
        "CONN_MAX_AGE": int(os.getenv("DB_CONN_MAX_AGE", "300")),
        "OPTIONS": {
            "sslmode": sslmode,
        },
    }


DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:[YOUR-PASSWORD]@db.kbsqbxhfewvguwtchwzp.supabase.co:5432/postgres",
)

SUPABASE_URL = os.getenv(
    "SUPABASE_URL",
    "https://kbsqbxhfewvguwtchwzp.supabase.co",
)

SUPABASE_PUBLISHABLE_KEY = os.getenv(
    "SUPABASE_PUBLISHABLE_KEY",
    "sb_publishable_Ch-HXaqwI8oBcMXxZmAgJQ_Mh7TDRwX",
)

DATABASES = {
    "default": _database_from_url(DATABASE_URL),
}
