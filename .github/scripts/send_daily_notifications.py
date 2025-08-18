#!/usr/bin/env python3
"""
Daily News Notifications Script
Sends push notifications to all FCM tokens in Supabase with latest news
"""

import os
import json
import random
from datetime import datetime
from supabase import create_client, Client
import firebase_admin
from firebase_admin import credentials, messaging

def initialize_services():
    """Initialize Supabase and Firebase services"""
    
    # Initialize Supabase
    supabase_url = os.getenv('SUPABASE_URL')
    supabase_key = os.getenv('SUPABASE_SERVICE_KEY')
    
    if not supabase_url or not supabase_key:
        raise ValueError("Missing Supabase credentials")
    
    supabase: Client = create_client(supabase_url, supabase_key)
    
    # Initialize Firebase Admin
    firebase_creds = os.getenv('FIREBASE_SERVICE_ACCOUNT')
    if not firebase_creds:
        raise ValueError("Missing Firebase service account credentials")
    
    # Parse the service account JSON
    service_account_info = json.loads(firebase_creds)
    cred = credentials.Certificate(service_account_info)
    firebase_admin.initialize_app(cred)
    
    return supabase

def get_active_fcm_tokens(supabase):
    """Get all active FCM tokens from Supabase"""
    try:
        response = supabase.table('user_data').select('fcm_token').eq('active', True).execute()
        tokens = [row['fcm_token'] for row in response.data if row['fcm_token']]
        print(f"Found {len(tokens)} active FCM tokens")
        return tokens
    except Exception as e:
        print(f"Error fetching FCM tokens: {e}")
        return []

def get_latest_news(supabase):
    """Get latest news from news_article table"""
    try:
        # Use the actual table name from your app
        response = supabase.table('news_articles').select('*').limit(5).execute()
        
        if response.data:
            print(f"✅ Found {len(response.data)} articles in table")
            return response.data
        
        # Fallback: If no news table, create sample news
        print("No news table found, using sample news")
        return [
            {
                'title': 'Daily News Update',
                'description': 'Stay updated with the latest news and trends. Open the app to read more!',
                'url': 'https://your-app-link.com'
            }
        ]
        
    except Exception as e:
        print(f"Error fetching news: {e}")
        # Return fallback news
        return [
            {
                'title': 'Daily News Update',
                'description': 'Stay updated with the latest news and trends. Open the app to read more!',
                'url': 'https://your-app-link.com'
            }
        ]

def create_notification_message(news_item):
    """Create FCM notification message with image and title only"""
    
    # Extract title only
    title = news_item.get('title', 'Daily News Update')[:60]  # Slightly longer title since no body text
    
    # Get image URL (check multiple possible field names)
    image_url = (
        news_item.get('image_url') or 
        news_item.get('imageUrl') or 
        news_item.get('image') or 
        news_item.get('thumbnail') or 
        news_item.get('urlToImage') or
        'https://via.placeholder.com/400x200/0066CC/FFFFFF?text=News+Update'  # Fallback image
    )
    
    # Create the message with image and title only
    message_data = {
        'notification': {
            'title': title,
            'body': '',  # Empty body - only title and image
            'icon': 'ic_launcher',
            'image': image_url,  # Big picture notification
        },
        'data': {
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'type': 'news',
            'article_url': news_item.get('url', ''),
            'image_url': image_url,
            'timestamp': str(int(datetime.now().timestamp()))
        },
        'android': messaging.AndroidConfig(
            notification=messaging.AndroidNotification(
                channel_id='news_channel',
                priority=messaging.Priority.HIGH,
                default_sound=True,
                default_vibrate=True,
                image=image_url
            )
        ),
        'apns': messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(
                    alert=messaging.ApsAlert(
                        title=title,
                        body=''
                    ),
                    sound='default',
                    badge=1,
                    mutable_content=True
                )
            ),
            fcm_options=messaging.APNSFCMOptions(
                image=image_url
            )
        )
    }
    
    return message_data

def send_notifications_batch(tokens, message_data, batch_size=500):
    """Send notifications in batches to avoid rate limits"""
    
    total_sent = 0
    total_failed = 0
    
    # Split tokens into batches
    for i in range(0, len(tokens), batch_size):
        batch_tokens = tokens[i:i + batch_size]
        
        try:
            # Create multicast message
            multicast_message = messaging.MulticastMessage(
                tokens=batch_tokens,
                notification=messaging.Notification(
                    title=message_data['notification']['title'],
                    body=message_data['notification']['body'],
                    image=message_data['notification']['image']
                ),
                data=message_data['data'],
                android=message_data['android'],
                apns=message_data['apns']
            )
            
            # Send batch (use send_each_for_multicast for newer Firebase versions)
            response = messaging.send_each_for_multicast(multicast_message)
            
            # Count results
            total_sent += response.success_count
            total_failed += response.failure_count
            
            print(f"Batch {i//batch_size + 1}: Sent {response.success_count}, Failed {response.failure_count}")
            
            # Log failed tokens for debugging
            if response.failure_count > 0:
                for idx, resp in enumerate(response.responses):
                    if not resp.success:
                        print(f"Failed to send to token {batch_tokens[idx][:20]}...: {resp.exception}")
                        
        except Exception as e:
            print(f"Error sending batch {i//batch_size + 1}: {e}")
            total_failed += len(batch_tokens)
    
    return total_sent, total_failed

def main():
    """Main function to send daily notifications"""
    
    print(f"Starting daily news notifications at {datetime.now()}")
    
    try:
        # Initialize services
        supabase = initialize_services()
        print("✅ Services initialized successfully")
        
        # Get active FCM tokens
        fcm_tokens = get_active_fcm_tokens(supabase)
        
        if not fcm_tokens:
            print("❌ No active FCM tokens found")
            return
        
        # Get latest news
        news_articles = get_latest_news(supabase)
        
        if not news_articles:
            print("❌ No news articles found")
            return
        
        # Pick a random news article for today
        selected_news = random.choice(news_articles)
        print(f"📰 Selected news: {selected_news.get('title', 'Daily Update')}")
        
        # Create notification message
        message_data = create_notification_message(selected_news)
        
        # Send notifications
        print(f"📤 Sending notifications to {len(fcm_tokens)} users...")
        sent_count, failed_count = send_notifications_batch(fcm_tokens, message_data)
        
        # Log results
        print(f"✅ Notifications sent successfully: {sent_count}")
        print(f"❌ Failed notifications: {failed_count}")
        print(f"📊 Success rate: {(sent_count / len(fcm_tokens) * 100):.1f}%")
        
        # Log to Supabase (optional - create a notifications_log table)
        try:
            log_data = {
                'sent_at': datetime.now().isoformat(),
                'total_tokens': len(fcm_tokens),
                'successful_sends': sent_count,
                'failed_sends': failed_count,
                'news_title': selected_news.get('title', 'Daily Update'),
                'success_rate': round(sent_count / len(fcm_tokens) * 100, 1)
            }
            
            # Try to log to notifications_log table (create if needed)
            supabase.table('notifications_log').insert(log_data).execute()
            print("📝 Logged notification stats to Supabase")
            
        except Exception as e:
            print(f"⚠️ Could not log to Supabase (table may not exist): {e}")
        
    except Exception as e:
        print(f"❌ Error in main function: {e}")
        raise

if __name__ == "__main__":
    main()