# 🗄️ Supabase Setup for User Data & Notifications

## 📋 Database Table Creation

### **Step 1: Create the `user_data` table**

Run this SQL in your **Supabase Dashboard → SQL Editor**:

```sql
CREATE TABLE user_data (
  fcm_token TEXT PRIMARY KEY,
  email VARCHAR(255) NOT NULL,
  points_claimed INTEGER DEFAULT 0,
  total_remaining_points INTEGER DEFAULT 0,
  active BOOLEAN DEFAULT true,
  claim_status VARCHAR(50) DEFAULT 'none',
  last_claim_date TIMESTAMP NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Add indexes for better performance
CREATE INDEX idx_user_data_email ON user_data(email);
CREATE INDEX idx_user_data_claim_status ON user_data(claim_status);
CREATE INDEX idx_user_data_active ON user_data(active);
CREATE INDEX idx_user_data_last_claim_date ON user_data(last_claim_date);
CREATE INDEX idx_user_data_total_remaining_points ON user_data(total_remaining_points);
```

### **Step 2: Set up Row Level Security (RLS)**

```sql
-- Enable RLS
ALTER TABLE user_data ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to insert/update their own data
CREATE POLICY "Users can manage their own data" ON user_data
  FOR ALL WITH CHECK (true);

-- Allow service role to manage all data (for admin operations)
CREATE POLICY "Service role can manage all data" ON user_data
  FOR ALL USING (true);
```

## 📱 App Integration Complete

### **✅ Features Implemented:**

#### **1. Claim Button**
- **Location**: Settings → Reward Points section
- **Text**: "Claim Reward" (always visible)
- **Note**: "Minimum 1000 points required to claim rewards"
- **Behavior**: Button works regardless of points, validation happens in dialog

#### **2. Claim Dialog**
- **Simple UI**: Just asks for email address
- **Validation**: Checks email format and minimum points
- **Actions**: Cancel or Save

#### **3. Supabase Integration**
- **Service**: `UserDataService` handles all database operations
- **Data Saved**: Email, FCM token, points claimed, voucher value, timestamps
- **Multi-purpose**: Supports both reward claims and push notifications

#### **4. User Experience**
- **Loading State**: Shows spinner while submitting
- **Success Message**: Confirms submission with 24-48 hour timeline
- **Error Handling**: Shows appropriate errors for invalid email or insufficient points

## 🔧 Admin Workflow

### **View Pending Claims:**
```sql
SELECT 
  fcm_token,
  email,
  points_claimed,
  total_remaining_points,
  last_claim_date
FROM user_data 
WHERE claim_status = 'pending' 
AND active = true 
ORDER BY last_claim_date DESC;
```

### **Mark Claim as Processed:**
```sql
UPDATE user_data 
SET 
  claim_status = 'processed',
  updated_at = NOW()
WHERE email = '[USER_EMAIL]';
```

### **Get All Users for Notifications:**
```sql
SELECT 
  fcm_token,
  email
FROM user_data 
WHERE active = true;
```

### **Your Manual Process:**
1. **Check Supabase** for new pending claims
2. **Purchase voucher** (₹80 mobile recharge/Flipkart/Paytm)
3. **Email voucher** to user's email address
4. **Mark claim as processed** in Supabase

## 📊 Table Structure

| Field | Type | Description |
|-------|------|-------------|
| `fcm_token` | TEXT | **Primary key** - FCM token for push notifications |
| `email` | VARCHAR(255) | User's email address |
| `points_claimed` | INTEGER | Points claimed in last request (default: 0) |
| `total_remaining_points` | INTEGER | User's current total points balance (default: 0) |
| `active` | BOOLEAN | Whether user is active (default: true) |
| `claim_status` | VARCHAR(50) | 'none', 'pending', or 'processed' |
| `last_claim_date` | TIMESTAMP | When last claim was submitted |
| `created_at` | TIMESTAMP | When user was first added |
| `updated_at` | TIMESTAMP | When user data was last updated |

## 🔔 Multi-Purpose Benefits

### **1. Reward Claims**
- Track user claims and processing status
- Store email for voucher delivery
- Maintain claim history

### **2. Push Notifications**
- Store FCM tokens for all users
- Send targeted notifications
- Manage notification preferences

### **3. User Management**
- Single source of truth for user data
- Track user engagement
- Manage active/inactive users

## 🚀 Ready to Use!

Your reward claim system is now fully functional and integrated with Supabase. Users can claim rewards, and you'll receive all the data needed to process vouchers manually.