from supabase import create_client

url = "https://ttjplkudbiwqboxzozwc.supabase.co"
key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR0anBsa3VkYml3cWJveHpvendjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUxMjI2NTMsImV4cCI6MjA5MDY5ODY1M30.UGKilzRo-rP2dPsOIQRQT7qBZ4uYPtCQ_vlZcM6icNk"

supabase = create_client(url, key)

print("Supabase connected ")