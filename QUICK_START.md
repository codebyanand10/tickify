# Quick Start: Supabase Storage Setup

## 🚀 Quick Setup (5 minutes)

### 1. Get Supabase Credentials (2 min)

1. Go to https://supabase.com and sign in
2. Create a new project (or select existing)
3. Go to **Settings** → **API**
4. Copy:
   - **Project URL**: `https://xxxxx.supabase.co`
   - **Anon public key**: `eyJhbG...`

### 2. Update Your Code (1 min)

Open `lib/main.dart` and replace these lines (around line 14-17):

```dart
// Initialize Supabase
await Supabase.initialize(
  url: 'YOUR_SUPABASE_URL',        // ← Paste your Project URL here
  anonKey: 'YOUR_SUPABASE_ANON_KEY', // ← Paste your Anon key here
);
```

### 3. Create Storage Bucket (2 min)

1. In Supabase Dashboard, go to **Storage**
2. Click **New bucket**
3. Name: `certificates`
4. **Make it Public** ✓
5. Click **Create**

### 4. Set Bucket Policies

Click on the `certificates` bucket → **Policies** → **New Policy**

**Quick Policy (Copy & Paste):**

For **SELECT** (read):
```sql
true
```
Target: `public`

For **INSERT** (upload):
```sql
true
```
Target: `authenticated`

For **UPDATE** (replace):
```sql
true
```
Target: `authenticated`

For **DELETE** (remove):
```sql
true
```
Target: `authenticated`

### 5. Test It! ✅

Dependencies are already installed. Just:

```bash
flutter run
```

Then try uploading a certificate template in your app!

---

## 📁 What Changed?

### Files Modified:
- ✅ `pubspec.yaml` - Replaced `firebase_storage` with `supabase_flutter`
- ✅ `lib/main.dart` - Added Supabase initialization
- ✅ `lib/screens/certificate_template_editor_screen.dart` - Now uses Supabase Storage
- ✅ `lib/services/storage_service.dart` - New service for Supabase Storage operations

### Files Removed:
- ❌ Firebase Storage dependency

---

## 🎯 What You Need to Do

**ONLY 2 THINGS:**

1. **Add your Supabase credentials** to `lib/main.dart`
2. **Create the `certificates` bucket** in Supabase Dashboard (and make it public)

That's it! Everything else is already done.

---

## 🔍 How to Verify It's Working

1. Run the app
2. Create/edit an event with certificate enabled
3. Go to certificate template editor
4. Upload an image
5. Check Supabase Dashboard → Storage → certificates → certificate_templates
6. You should see your uploaded image!

---

## ⚠️ Common Issues

**"Bucket not found"**
→ Make sure you created the `certificates` bucket in Supabase

**"Permission denied"**
→ Make sure the bucket is set to **Public** and policies are configured

**"Invalid credentials"**
→ Double-check your URL and anon key in `main.dart`

---

## 📚 Full Documentation

See `SUPABASE_STORAGE_SETUP.md` for detailed instructions and troubleshooting.
