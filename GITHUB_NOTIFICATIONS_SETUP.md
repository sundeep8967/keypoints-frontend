# 🔔 GitHub Actions Daily News Notifications Setup

## 📋 Overview
This GitHub Action automatically sends daily push notifications to all your app users using their FCM tokens stored in Supabase.

## 🔧 Setup Instructions

### **Step 1: Add GitHub Secrets**
Go to your GitHub repository → Settings → Secrets and variables → Actions

Add these secrets:

#### **SUPABASE_URL**
```
https://your-project-id.supabase.co
```

#### **SUPABASE_SERVICE_KEY**
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```
*Get this from Supabase Dashboard → Settings → API → service_role key*

#### **FIREBASE_SERVICE_ACCOUNT**
```json
{
  "type": "service_account",
  "project_id": "your-firebase-project",
  "private_key_id": "...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-...@your-project.iam.gserviceaccount.com",
  "client_id": "...",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-...%40your-project.iam.gserviceaccount.com"
}
```
*Get this from Firebase Console → Project Settings → Service Accounts → Generate new private key*

### **Step 2: Create Firebase Service Account**
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to **Project Settings** (gear icon)
4. Click **Service Accounts** tab
5. Click **Generate new private key**
6. Copy the entire JSON content
7. Paste it as the `FIREBASE_SERVICE_ACCOUNT` secret in GitHub

### **Step 3: Optional - Create Notifications Log Table**
Run this SQL in your Supabase SQL Editor:
```sql
-- See .github/scripts/setup_notifications_log.sql
```

### **Step 4: Configure Schedule**
Edit `.github/workflows/daily_news_notifications.yml`:

```yaml
schedule:
  # Current: 9:00 AM UTC daily
  - cron: '0 9 * * *'
  
  # Examples:
  # - cron: '0 14 * * *'  # 2:00 PM UTC (7:30 PM IST)
  # - cron: '30 12 * * *' # 12:30 PM UTC (6:00 PM IST)
  # - cron: '0 6 * * *'   # 6:00 AM UTC (11:30 AM IST)
```

## 🚀 How It Works

### **Daily Process:**
1. **Fetch FCM Tokens**: Gets all active FCM tokens from `user_data` table
2. **Get Latest News**: Fetches news from `news_article` table (or uses fallback)
3. **Select Random News**: Picks one news article for the day
4. **Send Notifications**: Sends push notifications to all users in batches
5. **Log Results**: Records statistics in `notifications_log` table

### **Notification Content:**
- **Title**: News article title (max 50 chars)
- **Body**: News description/content (max 100 chars)
- **Data**: Article URL, timestamp, type
- **Icon**: Your app launcher icon

### **Batch Processing:**
- Sends notifications in batches of 500 to avoid rate limits
- Handles failures gracefully
- Logs success/failure rates

## 📊 Monitoring

### **GitHub Actions Logs:**
Check the workflow runs in GitHub Actions tab to see:
- How many users received notifications
- Success/failure rates
- Any errors

### **Supabase Logs:**
Query the `notifications_log` table:
```sql
SELECT 
  sent_at,
  total_tokens,
  successful_sends,
  failed_sends,
  success_rate,
  news_title
FROM notifications_log 
ORDER BY sent_at DESC 
LIMIT 10;
```

## 🎯 Customization

### **Change Notification Frequency:**
- **Twice daily**: Add another cron schedule
- **Weekly**: Change to `0 9 * * 1` (Mondays only)
- **Weekdays only**: Change to `0 9 * * 1-5`

### **Customize Message Content:**
Edit the `create_notification_message()` function in the Python script.

### **Add Categories:**
Modify the script to send different news based on user preferences.

### **A/B Testing:**
Send different messages to different user segments.

## 🔧 Manual Testing

### **Test the workflow manually:**
1. Go to GitHub Actions tab
2. Select "Daily News Notifications"
3. Click "Run workflow"
4. Check your phone for the notification!

### **Test locally:**
```bash
# Set environment variables
export SUPABASE_URL="your-url"
export SUPABASE_SERVICE_KEY="your-key"
export FIREBASE_SERVICE_ACCOUNT='{"type":"service_account",...}'

# Run the script
python .github/scripts/send_daily_notifications.py
```

## 📱 Expected User Experience

Users will receive:
- **Daily notification** at the scheduled time
- **News headline** as the title
- **Brief description** as the body
- **Tapping opens your app** (if configured)

## 🚨 Important Notes

1. **Rate Limits**: Firebase has daily quotas for free tier
2. **Token Management**: Invalid tokens are automatically handled
3. **Privacy**: Only active users receive notifications
4. **Timezone**: Adjust cron schedule for your target audience timezone

## ✅ Success Metrics

Monitor these in your logs:
- **Daily active tokens**: Number of valid FCM tokens
- **Delivery rate**: Percentage of successful sends
- **User engagement**: App opens after notifications

**Your automated news notification system is ready! 🎉**