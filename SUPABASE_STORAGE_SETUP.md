# Supabase Storage Migration Guide

This guide will help you migrate from Firebase Storage to Supabase Storage for certificate template uploads.

## Prerequisites

1. A Supabase account (sign up at https://supabase.com)
2. A Supabase project created

## Step 1: Get Your Supabase Credentials

1. Go to your Supabase project dashboard
2. Click on **Settings** (gear icon) in the sidebar
3. Go to **API** section
4. Copy the following:
   - **Project URL** (looks like: `https://xxxxxxxxxxxxx.supabase.co`)
   - **Anon/Public Key** (starts with `eyJ...`)

## Step 2: Update main.dart with Your Credentials

Open `lib/main.dart` and replace the placeholder values:

```dart
// Initialize Supabase
await Supabase.initialize(
  url: 'YOUR_SUPABASE_URL',        // Replace with your Project URL
  anonKey: 'YOUR_SUPABASE_ANON_KEY', // Replace with your Anon key
);
```

**Example:**
```dart
await Supabase.initialize(
  url: 'https://abcdefghijk.supabase.co',
  anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
);
```

## Step 3: Create Storage Bucket in Supabase

1. Go to your Supabase project dashboard
2. Click on **Storage** in the sidebar
3. Click **New bucket**
4. Enter bucket name: `certificates`
5. Set the bucket to **Public** (so URLs are accessible)
6. Click **Create bucket**

### Configure Bucket Policies

After creating the bucket, you need to set up policies:

1. Click on the `certificates` bucket
2. Go to **Policies** tab
3. Click **New Policy**
4. Create the following policies:

#### Policy 1: Allow Public Read Access
- **Policy Name**: `Public Read Access`
- **Allowed operation**: `SELECT`
- **Target roles**: `public`
- **Policy definition**:
```sql
true
```

#### Policy 2: Allow Authenticated Users to Upload
- **Policy Name**: `Authenticated Upload`
- **Allowed operation**: `INSERT`
- **Target roles**: `authenticated`
- **Policy definition**:
```sql
true
```

#### Policy 3: Allow Authenticated Users to Update
- **Policy Name**: `Authenticated Update`
- **Allowed operation**: `UPDATE`
- **Target roles**: `authenticated`
- **Policy definition**:
```sql
true
```

#### Policy 4: Allow Authenticated Users to Delete
- **Policy Name**: `Authenticated Delete`
- **Allowed operation**: `DELETE`
- **Target roles**: `authenticated`
- **Policy definition**:
```sql
true
```

**Alternative: Quick Setup (Less Secure)**
If you want to quickly test, you can enable all operations for authenticated users:
1. Click on **Configuration** for the bucket
2. Toggle **Public bucket** to ON
3. This allows anyone to read files, but only authenticated users can upload

## Step 4: Install Dependencies

Run the following command to install the new dependencies:

```bash
flutter pub get
```

This will install `supabase_flutter` and remove `firebase_storage`.

## Step 5: Test the Migration

1. Run your app
2. Navigate to the certificate template editor
3. Try uploading a certificate template
4. Verify the upload works correctly

## Step 6: Verify Upload in Supabase

1. Go to Supabase Dashboard → Storage → certificates bucket
2. Navigate to `certificate_templates` folder
3. You should see your uploaded images there

## Troubleshooting

### Error: "Bucket not found"
- Make sure you created the `certificates` bucket in Supabase
- Check that the bucket name in the code matches exactly

### Error: "Permission denied" or "Row Level Security"
- Make sure you've set up the storage policies correctly
- Verify that the bucket is set to public or has appropriate policies

### Error: "Invalid URL" or "Failed to upload"
- Double-check your Supabase URL and anon key in `main.dart`
- Make sure you're connected to the internet
- Check Supabase dashboard for any service issues

### Images not loading
- Verify the bucket is set to **Public**
- Check the URL returned from the upload - it should be accessible in a browser
- Make sure CORS is enabled (usually enabled by default in Supabase)

## Benefits of Supabase Storage

1. **Better Pricing**: More generous free tier than Firebase
2. **Faster Uploads**: Generally faster upload speeds
3. **Better Integration**: Works seamlessly with Supabase Auth and Database
4. **More Control**: Better policy management and access control
5. **CDN**: Built-in CDN for faster image delivery worldwide

## Migration Checklist

- [ ] Created Supabase account and project
- [ ] Copied Supabase URL and Anon Key
- [ ] Updated `main.dart` with credentials
- [ ] Created `certificates` bucket in Supabase
- [ ] Set bucket to Public
- [ ] Configured storage policies
- [ ] Ran `flutter pub get`
- [ ] Tested certificate template upload
- [ ] Verified files appear in Supabase Storage

## Optional: Migrate Existing Files

If you have existing certificate templates in Firebase Storage, you can:

1. Download them from Firebase Storage
2. Upload them to Supabase Storage using the Supabase dashboard
3. Update the URLs in your Firestore database

Or create a migration script to automate this process.

## Need Help?

If you encounter any issues:
1. Check the Supabase documentation: https://supabase.com/docs/guides/storage
2. Check the Flutter Supabase package: https://pub.dev/packages/supabase_flutter
3. Review the error messages in your console
