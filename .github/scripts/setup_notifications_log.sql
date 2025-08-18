-- Optional: Create notifications_log table to track notification statistics
-- Run this in your Supabase SQL Editor

CREATE TABLE IF NOT EXISTS notifications_log (
  id SERIAL PRIMARY KEY,
  sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  total_tokens INTEGER NOT NULL,
  successful_sends INTEGER NOT NULL,
  failed_sends INTEGER NOT NULL,
  news_title TEXT,
  success_rate DECIMAL(5,2),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_notifications_log_sent_at ON notifications_log(sent_at);

-- Enable RLS (optional)
ALTER TABLE notifications_log ENABLE ROW LEVEL SECURITY;

-- Allow service role to manage all data
CREATE POLICY "Service role can manage notifications log" ON notifications_log
FOR ALL 
TO service_role
WITH CHECK (true);