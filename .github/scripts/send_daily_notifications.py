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
        
        # Print complete FCM tokens for debugging
        for i, token in enumerate(tokens, 1):
            print(f"FCM Token {i}: {token}")
        
        return tokens
    except Exception as e:
        print(f"Error fetching FCM tokens: {e}")
        return []

def get_unique_daily_article(supabase):
    """Get unique article based on notification sequence for the day"""
    
    # Get current hour to determine which notification this is FOR THE DAY
    current_hour = datetime.now().hour
    
    # Determine notification sequence number for the day
    if 6 <= current_hour < 12:      # 1st notification of the day (7:30 AM UTC)
        limit_count = 1
        notification_number = "1st"
        
    elif 12 <= current_hour < 17:   # 2nd notification of the day (12:30 PM UTC)
        limit_count = 2  
        notification_number = "2nd"
        
    else:                           # 3rd notification of the day (4:00 PM UTC)
        limit_count = 3
        notification_number = "3rd"
    
    try:
        # Fetch articles with limit based on notification sequence
        response = supabase.table('news_articles')\
            .select('*')\
            .order('id', desc=True)\
            .limit(limit_count)\
            .execute()
        
        if response.data:
            # Take the LAST article from the result (which is the target article)
            article = response.data[-1]  
            print(f"📰 {notification_number} notification of the day: Selected article ID {article.get('id')} - {article.get('title', 'No title')}")
            return article
        else:
            # Fallback: If no articles found, create sample news
            print("No news articles found, using sample news")
            return {
                'title': 'Daily News Update',
                'description': 'Stay updated with the latest news and trends. Open the app to read more!',
                'url': 'https://your-app-link.com'
            }
            
    except Exception as e:
        print(f"Error fetching article: {e}")
        # Return fallback news
        return {
            'title': 'Daily News Update',
            'description': 'Stay updated with the latest news and trends. Open the app to read more!',
            'url': 'https://your-app-link.com'
        }

def create_notification_message(news_item):
    """Create FCM notification message with image and title only"""
    
    # Extract title with attention-grabbing emojis
    raw_title = news_item.get('title', 'Daily News Update')
    title = f"🔥 {raw_title}"[:60]  # Add fire emoji for urgency
    
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
                priority='high',
                default_sound=True,
                image=image_url,
                color='#FF6B35',  # Eye-catching orange color
                default_vibrate_timings=True,  # Vibration pattern
                visibility='public',  # Show on lock screen
                ticker='📰 Breaking News Update!'  # Scrolling text on older Android
            )
        ),
        'apns': messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(
                    alert=messaging.ApsAlert(
                        title=title,
                        body='',
                        subtitle='📱 Tap to read now!'  # Subtitle for iOS
                    ),
                    sound='default',
                    badge=1,
                    mutable_content=True,
                    interruption_level='active',  # iOS 15+ - bypass Focus modes
                    relevance_score=1.0  # iOS 15+ - highest relevance
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
        
        # Get unique daily article based on notification sequence
        selected_news = get_unique_daily_article(supabase)
        
        if not selected_news:
            print("❌ No news article found")
            return
        
        # Create notification message
        message_data = create_notification_message(selected_news)
        
        # Send notifications
        print(f"📤 Sending notifications to {len(fcm_tokens)} users...")
        sent_count, failed_count = send_notifications_batch(fcm_tokens, message_data)
        
        # Log results
        print(f"✅ Notifications sent successfully: {sent_count}")
        print(f"❌ Failed notifications: {failed_count}")
        print(f"📊 Success rate: {(sent_count / len(fcm_tokens) * 100):.1f}%")
        
        # Log results to console (Supabase logging disabled to avoid table errors)
        print("📝 Notification stats logged to console only")
        
    except Exception as e:
        print(f"❌ Error in main function: {e}")
        raise

if __name__ == "__main__":
    main()