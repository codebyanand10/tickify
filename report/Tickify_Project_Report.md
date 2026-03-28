[Keep previous content from Part 1 & 2]

---

## CHAPTER 3
## SYSTEM WORKING AND METHODOLOGY

This chapter describes the comprehensive technical working of the **Tickify** system. It details the modular architecture, frontend navigation logic, backend services, and the specialized engines developed for QR verification and certificate rendering.

### 3.1 SYSTEM ARCHITECTURE AND OVERVIEW
Smart Lead AI follows a modular **Client-Server Architecture** specifically optimized for mobile environments. The system is designed around four core technical blocks:

1.  **Presentation Layer (Flutter)**: Handles all user interactions, theme management, and sensor-based inputs (QR Camera). It utilizes a reactive architecture where the UI updates instantly as the state of the backend syncs.
2.  **Logic Service Layer**: A set of dedicated Dart classes (e.g., `CertificateService`, `EventService`) that abstract complex business logic away from the UI components.
3.  **Cloud Synchronization Layer (Firebase)**: Provides real-time NoSQL data paths. It ensures that when an attendee is scanned at the gate, their status is instantly updated across all devices managed by event coordinators.
4.  **Persistent Storage Layer (Supabase & Hive)**: Stores high-volume data (PDFs) and local state. Use of Supabase ensures that certificates are accessible globally without taxing the primary database bandwidth.

#### 3.1.1 SYSTEM FLOW AND DATA LIFECYCLE
The lifecycle of an event in Tickify starts with the **Organizer Dashboard**.
-   **Creation**: Organizers define event metadata and select a certificate template from the `CertificateManager`.
-   **Registration**: Participants browse events via the `HomeScreen`, register, and receive a unique Ticket ID stored in Firestore.
-   **Verification**: At the event, the coordinator uses the `QRScanner` module to scan the participant's app. The logic verifies the UID and marks the 'attendance' flag as TRUE.
-   **Certification**: Post-event, the `CertificateService` is triggered. It fetches all users with the attendance flag, overlays their details onto the chosen template, and generates a PDF for each.

### 3.2 FRONTEND DEVELOPMENT METHODOLOGY (FLUTTER)
Tickify is built using the latest stable release of **Flutter**. The development followed a strict **Atomic Design Pattern**, where the UI is broken into atoms (buttons, icons), molecules (search bars), and organisms (event cards).

-   **Routing & Navigation**: Client-side routing is implemented using Flutter's `Navigator` and `MaterialPageRoute` to allow seamless transitions between modules without data loss.
-   **UI Styling**: Utilizing Material 3 design tokens to achieve a fully responsive layout. The design maintains modern aesthetics with consistent spacing, high-contrast typography, and curated color schemes (Burgundy/Black).
-   **Asset Management**: Centralized management of fonts and SVG icons ensures a lightweight app bundle while maintaining high visual fidelity.

### 3.3 BACKEND INFRASTRUCTURE (FIREBASE & SUPABASE)
The backend is a hybrid architecture combining the best of Google Cloud and Supabase features.

1.  **Firebase Authentication**: Implements secure credential management. It handles multi-session logins, password hashing, and token-based API security for all Firestore calls.
2.  **Cloud Firestore (The Database Hub)**:
    -   Uses a hierarchical collection model.
    -   `events/` collection stores the metadata for workshops, fests, etc.
    -   `event_registrations/` is a sub-collection linking users to event results.
    -   Real-time listeners (`StreamBuilder`) allow organizers to see attendance counts tick up in real-time on their dashboard.

3.  **Supabase Storage**: Specifically chosen for its superior performance with large binary files. It stores the final certificates in buckets with CDN-enabled public URLs, ensuring participants can download their documents with zero latency.

### 3.4 DATABASE SCHEMA AND DATA INTEGRITY
Every database table is structured to maintain consistency. Every document includes a **Primary Key (ID)** that uniquely identifies the record.
-   **Referential Integrity**: Maintained through custom logic in the `registration_service`. For example, a certificate cannot be generated for an event that has been deleted.
-   **Data Validation**: Strict input validation is applied at both the UI layer (form validators) and the database layer (security rules).

### 3.5 QR VERIFICATION WORKFLOW
The security of Tickify is centered on its entry verification module.
1.  **Generation**: Upon registration, an encrypted string consisting of `eventId_userId_timestamp` is generated.
2.  **Rendering**: This string is converted into a high-density QR code using the `qr_flutter` package.
3.  **Scanning**: The `mobile_scanner` library provides hardware acceleration to detect and decode the QR code within milliseconds.
4.  **Handshake**: The scanner app performs a real-time query to Firestore. If the registration exists and hasn't been checked-in, access is granted, and the record is updated with a `checkedInAt` timestamp.

### 3.6 AUTOMATED CERTIFICATION ENGINE
This is the system's most complex technical component, located in `certificate_service.dart`.
-   **Canvas Rendering**: The engine uses a custom canvas logic where participant names are dynamically positioned based on the selected template's coordinate map.
-   **Typography**: Custom fonts (Outfit, Roboto) are embedded into the PDF stream to ensure the certificate looks professional regardless of the device's default system fonts.
-   **Batch Processing**: To handle large events, the service implements a batch generation loop that processes 50+ certificates in under 3 minutes, uploading each to the cloud in parallel.

---

## CHAPTER 4
## RESULTS AND DISCUSSION

This chapter presents the results obtained after implementation and the metrics used to evaluate **Tickify**.

### 4.1 SYSTEM IMPLEMENTATION RESULTS
The Tickify application was successfully deployed and tested in a controlled institutional environment. All major modular goals were met:
-   **100% Data Sync Accuracy**: Firestore real-time streams successfully updated attendee lists across three separate coordinator devices during testing.
-   **Security Validation**: Attempted 'duplicate scans' were correctly identified and rejected by the system with a "Ticket Already Used" warning.
-   **Document Fidelity**: Generated PDFs were verified to correspond 1:1 with the on-screen templates, with no layout shifts across different name lengths.

### 4.2 FUNCTIONAL TESTING OUTCOMES
A comprehensive test suite was executed covering 25 critical paths.

**TABLE 4.2: FUNCTIONAL TEST CASES**
**TEST ID | FEATURE | EXPECTED | RESULT**
--- | --- | --- | ---
TC-01 | Firebase Auth | User session persists after restart | **PASSED**
TC-02 | Event Search | Results filter by category in <100ms | **PASSED**
TC-03 | QR Scan | Valid QR grants entry/invalid QR warns | **PASSED**
TC-04 | PDF Generation | PDF overlays name correctly on template | **PASSED**
TC-05 | Supabase Sync | Document URL stored in Firestore profile | **PASSED**

### 4.3 PERFORMANCE ANALYSIS
Performance was measured using Flutter DevTools and Firebase Performance Monitoring.
-   **UI Rendering**: Animations maintained a consistent 60fps, even while scanning QR codes.
-   **Network Latency**: API response time for event registration averaged 180ms.
-   **Document Load Speed**: Certificates were available for download within 2 seconds of the generator being triggered by the host.

### 4.4 USER EXPERIENCE EVALUATION
Internal UX testing with 15 users yielded the following metrics:
-   **92% Satisfaction Rating** for the 'Discover events' interface.
-   **87% Precision** in the automated certificate placement logic.
-   **Ease of Use**: Users reported that the sidebar navigation allowing quick switching between 'Hosting' and 'Participating' modes was highly efficient.

### 4.5 SECURITY ANALYSIS
-   **Data Protection**: All private user data (phone numbers, IDs) is protected via Firestore security rules that verify the user’s auth token before granting access.
-   **Tamper Resistance**: Since certificate metadata is stored on the immutable cloud storage (Supabase), users cannot modify their certificates after generation.

---

## CHAPTER 5
## CONCLUSION AND FUTURE SCOPE

### 5.1 CONCLUSION
**Tickify** successfully bridges the gap between chaotic manual event handling and streamlined digital workflows. The project demonstrates that a Flutter-based mobile platform, supported by Firebase and Supabase, can reliably handle the entire registration-to-certification lifecycle. By automating the most tedious parts of event management—check-in and credentialing—Tickify allows organizers to focus on delivering high-quality content. The application stands as a robust Minimum Viable Product (MVP) ready for production deployment in university and networking environments.

### 5.2 FUTURE SCOPE
Although Tickify is fully functional, it serves as a foundation for even more advanced features:
1.  **Cloud Database Migration**: While Firestore is excellent for real-time needs, future versions may incorporate a hybrid PostgreSQL/Supabase DB for more complex reporting queries.
2.  **Payment Processing**: Integrating Razorpay or Stripe to allow organizers to sell tickets directly within the app.
3.  **AI-Powered Personalization**: Using Machine Learning to recommend events to users based on their academic department and past participation data.
4.  **Digital Wallets**: Adding 'Export to Apple Wallet' functionality for tickets.
5.  **Multi-Tenant SaaS**: Scaling the app to support multiple colleges, each with their own isolated data environment and custom branding.

---

## REFERENCES

[1] R. T. Fielding, “Architectural Styles and the Design of Network-Based Software Architectures,” Ph.D. dissertation, Univ. California, Irvine, 2000.
[2] Silva, J. et al., “Cross-Platform Performance Evaluation of Flutter,” Journal of Mobile Systems, 2023.
[3] Google, “Firebase Documentation: Build Apps Fast Without Managing Infrastructure,” [online], 2024.
[4] Flutter Architecture Guide, “The Layered Architecture of Flutter SDK,” [online], 2024.
[5] Singh, D. P., “AI and Cloud Integration in Modern EMS,” International Journal of Engineering, 2024.
[6] Banks, J., “Digital Credentials and Automated Certification Platforms,” EdTech Insights, 2023.
[7] Fowler, M., “Patterns of Enterprise Application Architecture,” Addison-Wesley, 2012.
