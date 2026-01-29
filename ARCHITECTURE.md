# Architecture Overview

## Current Architecture (After Migration)

```
┌─────────────────────────────────────────────────────────────┐
│                      Tickify App                            │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         Certificate Template Editor                   │  │
│  │                                                       │  │
│  │  1. User selects image                               │  │
│  │  2. Calls StorageService.uploadFile()               │  │
│  │  3. Gets back public URL                            │  │
│  │  4. Saves URL to Firestore                          │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                          │
                          │
        ┌─────────────────┴─────────────────┐
        │                                   │
        ▼                                   ▼
┌───────────────────┐            ┌──────────────────┐
│  Supabase Storage │            │  Firebase        │
│                   │            │  Firestore       │
│  • certificates   │            │                  │
│    bucket         │            │  • events        │
│  • Public access  │            │  • users         │
│  • CDN enabled    │            │  • certificates  │
└───────────────────┘            └──────────────────┘
        │                                   │
        │                                   │
        └─────────────────┬─────────────────┘
                          │
                          ▼
                ┌──────────────────┐
                │   Certificate    │
                │   Generation     │
                │                  │
                │  • Fetches data  │
                │  • Generates PDF │
                │  • Uses template │
                └──────────────────┘
```

## Data Flow

### 1. Upload Certificate Template

```
User Action
    │
    ▼
Certificate Template Editor
    │
    ├─► Pick Image (ImagePicker)
    │
    ├─► Upload to Supabase Storage
    │   └─► StorageService.uploadFile()
    │       └─► Supabase Storage API
    │           └─► Returns public URL
    │
    └─► Save URL to Firestore
        └─► events/{eventId}/certificateTemplateUrl
```

### 2. Generate Certificate

```
Certificate Generation Request
    │
    ▼
CertificateService
    │
    ├─► Fetch event data from Firestore
    │   └─► Get certificateTemplateUrl
    │
    ├─► Download template from Supabase
    │   └─► HTTP GET request to public URL
    │
    ├─► Fetch participant data from Firestore
    │
    └─► Generate PDF
        └─► Overlay text on template
        └─► Return PDF bytes
```

## Service Responsibilities

### StorageService (NEW)
- Upload files to Supabase Storage
- Update/replace files
- Delete files
- Get public URLs
- List files in directories

### CertificateService (UNCHANGED)
- Generate PDF certificates
- Manage certificate metadata
- Publish certificates to users
- Handle custom templates

### Firestore (UNCHANGED)
- Store event data
- Store user data
- Store certificate metadata
- Store registration data

## Security Model

```
┌─────────────────────────────────────────────────────┐
│              Supabase Storage Policies              │
├─────────────────────────────────────────────────────┤
│                                                     │
│  Public Access (SELECT):                           │
│  • Anyone can view/download files                  │
│  • Enables public URLs                             │
│                                                     │
│  Authenticated Upload (INSERT):                    │
│  • Only logged-in users can upload                 │
│  • Prevents spam/abuse                             │
│                                                     │
│  Authenticated Update (UPDATE):                    │
│  • Only logged-in users can replace files          │
│                                                     │
│  Authenticated Delete (DELETE):                    │
│  • Only logged-in users can delete files           │
│                                                     │
└─────────────────────────────────────────────────────┘
```

## File Organization

```
Supabase Storage
│
└── certificates (bucket)
    │
    └── certificate_templates/
        │
        ├── 1705432100000.jpg  (Event 1 template)
        ├── 1705432200000.jpg  (Event 2 template)
        ├── 1705432300000.jpg  (Event 3 template)
        └── ...

Firestore
│
└── events (collection)
    │
    ├── event1 (document)
    │   ├── title: "Tech Conference 2024"
    │   ├── certificateTemplateUrl: "https://xxx.supabase.co/..."
    │   └── ...
    │
    ├── event2 (document)
    │   ├── title: "Workshop"
    │   ├── certificateTemplateUrl: "https://xxx.supabase.co/..."
    │   └── ...
    │
    └── ...
```

## Integration Points

### 1. App Initialization (main.dart)
```dart
void main() async {
  // Initialize Firebase (existing)
  await Firebase.initializeApp(...);
  
  // Initialize Supabase (new)
  await Supabase.initialize(...);
  
  runApp(TickifyApp());
}
```

### 2. Certificate Template Upload
```dart
// In certificate_template_editor_screen.dart
final storageService = StorageService();
final url = await storageService.uploadFile(
  file: imageFile,
  path: 'certificate_templates/timestamp.jpg',
  bucket: 'certificates',
);

// Save to Firestore
await FirebaseFirestore.instance
    .collection('events')
    .doc(eventId)
    .update({'certificateTemplateUrl': url});
```

### 3. Certificate Generation
```dart
// In certificate_service.dart
final templateUrl = eventData['certificateTemplateUrl'];

// Download template from Supabase
final response = await http.get(Uri.parse(templateUrl));
final imageBytes = response.bodyBytes;

// Generate PDF with template
final pdf = await generateCertificatePDF(...);
```

## Benefits of This Architecture

✅ **Separation of Concerns**
- Storage: Supabase
- Database: Firestore
- Auth: Firebase Auth
- Each service does what it does best

✅ **Scalability**
- Supabase CDN handles global traffic
- Firestore handles database queries
- No single point of failure

✅ **Cost Efficiency**
- Supabase Storage is cheaper
- Only pay for what you use
- Free tier is generous

✅ **Maintainability**
- Clear service boundaries
- Easy to test and debug
- Simple to extend

✅ **Performance**
- CDN caching for images
- Parallel requests possible
- Fast global delivery
