import os

from supabase import create_client


url = os.getenv("SUPABASE_URL", "https://ttjplkudbiwqboxzozwc.supabase.co")
key = os.getenv(
    "SUPABASE_KEY",
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR0anBsa3VkYml3cWJveHpvendjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUxMjI2NTMsImV4cCI6MjA5MDY5ODY1M30.UGKilzRo-rP2dPsOIQRQT7qBZ4uYPtCQ_vlZcM6icNk",
)

if not url or not key:
    raise RuntimeError("Missing Supabase configuration.")

supabase = create_client(url, key)
