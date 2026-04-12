import os

from supabase import create_client

DEFAULT_SUPABASE_URL = 'https://ttjplkudbiwqboxzozwc.supabase.co'
DEFAULT_SUPABASE_KEY = (
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR0anBsa3VkYml3cWJveHpvendjIiwicm9sZSI6'
    'ImFub24iLCJpYXQiOjE3NzUxMjI2NTMsImV4cCI6MjA5MDY5ODY1M30.'
    'UGKilzRo-rP2dPsOIQRQT7qBZ4uYPtCQ_vlZcM6icNk'
)

supabase = create_client(
    os.getenv('SUPABASE_URL', DEFAULT_SUPABASE_URL),
    os.getenv('SUPABASE_KEY', DEFAULT_SUPABASE_KEY),
)
