# Supabase Cloud Backup Setup

This app now supports backing up your data to Supabase cloud storage with automatic management of the 3 most recent backups.

## Setup Instructions

### 1. Create a Supabase Project

1. Go to [supabase.com](https://supabase.com)
2. Sign up or log in
3. Click "New Project"
4. Fill in your project details and create the project

### 2. Get Your Credentials

1. In your Supabase project dashboard, go to **Settings** > **API**
2. Copy the following values:
   - **Project URL** (e.g., `https://xxxxx.supabase.co`)
   - **anon/public key** (starts with `eyJhbGc...`)

### 3. Enable Anonymous Sign-In (Required for Private Buckets)

If your bucket is private, you need to enable authentication:

1. In your Supabase project, go to **Authentication** > **Providers**
2. Scroll down to **Anonymous Sign-in**
3. Toggle it **ON** (Enable anonymous sign-ins)
4. Click **Save**

This allows the app to authenticate anonymously to access your private bucket.

### 4. Create Storage Bucket

1. In your Supabase project, go to **Storage**
2. Click "Create a new bucket"
3. Name it: `mq-pay-backups`
4. Make it **Private** (recommended for security)
5. Click "Create bucket"

### 5. Set Storage Policies (for Private Buckets)

If you made the bucket private, you need to add policies to allow authenticated users to access it:

1. In **Storage**, click on your `mq-pay-backups` bucket
2. Go to **Policies** tab
3. Click **New Policy** and add these policies:

**Policy 1: Allow authenticated uploads**
```sql
CREATE POLICY "Allow authenticated uploads"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'mq-pay-backups');
```

**Policy 2: Allow authenticated reads**
```sql
CREATE POLICY "Allow authenticated reads"
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'mq-pay-backups');
```

**Policy 3: Allow authenticated deletes**
```sql
CREATE POLICY "Allow authenticated deletes"
ON storage.objects
FOR DELETE
TO authenticated
USING (bucket_id = 'mq-pay-backups');
```

### 6. Configure the App

1. In the project root, copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Open the `.env` file and update it with your actual Supabase credentials:

   ```env
   SUPABASE_URL=https://ibvpxycejucutnigrdvq.supabase.co
   SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...your-key-here...

   # Optional: Leave these empty to use anonymous sign-in (recommended)
   SUPABASE_AUTH_EMAIL=
   SUPABASE_AUTH_PASSWORD=
   ```

3. Save the `.env` file

**Important Security Notes:**
- ✅ The `.env` file is already in `.gitignore` and **will not be committed to GitHub**
- ✅ Your credentials are now safe and won't be exposed in version control
- ⚠️ Never commit the `.env` file - only commit `.env.example`
- ⚠️ Each developer/device needs their own `.env` file with their credentials

### 7. Enable Auto-Backup (Optional but Recommended)

To automatically backup to Supabase:

1. Go to **Settings** > **Auto-Backup** section
2. Toggle **Enable Auto-Backup** to ON
3. Choose your preferred frequency:
   - **Daily**: Backs up every 24 hours
   - **Weekly**: Backs up every 7 days
   - **Monthly**: Backs up every 30 days

**Note**: When auto-backup is enabled, the app will backup to BOTH:
- Local device storage
- Supabase cloud storage (if configured)

### 8. Use Manual Backup Features

You can also manually backup/restore at any time:

- **Upload Backup**: Go to Settings > Supabase Cloud Backup > Upload Backup
- **View Backups**: See all your cloud backups (max 3 most recent)
- **Restore Backup**: Download and merge data from a previous backup
- **Delete Backup**: Remove old backups manually

## Features

✅ **Automatic 3-Backup Limit**: Only the 3 most recent backups are kept. Older backups are automatically deleted when you create new ones.

✅ **Duplicate Prevention**: When restoring, duplicate records and payment methods are automatically skipped.

✅ **What Gets Backed Up**:
- All USSD transaction records
- Payment methods
- App settings (language, theme, etc.)

## Security Note

⚠️ **Important**: The anon key is safe to include in your code as it only allows access to your Supabase project's public APIs. However, make sure to:

1. Set appropriate Row Level Security (RLS) policies in Supabase if needed
2. Never commit your production credentials to public repositories
3. Consider using environment variables for production builds

## Troubleshooting

### "Supabase is not configured"
- Check that you created the `.env` file (copy from `.env.example`)
- Verify that `SUPABASE_URL` and `SUPABASE_ANON_KEY` are set in `.env`
- Make sure the values don't contain quotes or extra spaces
- Restart the app after modifying `.env` file

### Upload/Download fails
- Verify the storage bucket `mq-pay-backups` exists in your Supabase project
- Check your internet connection
- If bucket is private, make sure:
  - Anonymous sign-in is enabled in Authentication settings
  - Storage policies are set correctly (see step 5)
- Try checking the Supabase logs in your dashboard for detailed error messages

### "Authentication failed" or "Access denied"
- Make sure you enabled **Anonymous Sign-in** in your Supabase project
- Verify storage policies allow authenticated users to read/write
- Alternative: You can set the bucket to **Public** instead (less secure)

### "Already initialized" errors
- This is normal and can be ignored - it means Supabase was already set up
