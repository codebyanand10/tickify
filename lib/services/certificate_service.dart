import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'storage_service.dart';

class CertificateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Generate a PDF certificate for a participant
  Future<Uint8List> generateCertificatePDF({
    required String participantName,
    required String eventName,
    required String eventDate,
    required String organizerName,
    String? certificateType,
    Map<String, dynamic>? certificateSettings,
    String? department,
    String? semester,
    String? collegeName,
    String? participantClass,
    String? templateImageUrl,
    List<Map<String, dynamic>>? templateFields,
    Uint8List? templateImageBytes,
  }) async {
    // Use custom template if available
    if ((templateImageUrl != null || templateImageBytes != null) && 
        templateFields != null && 
        templateFields.isNotEmpty) {
      return _generateCustomTemplateCertificate(
        participantName: participantName,
        eventName: eventName,
        eventDate: eventDate,
        organizerName: organizerName,
        department: department,
        semester: semester,
        collegeName: collegeName,
        templateImageUrl: templateImageUrl ?? '',
        templateImageBytes: templateImageBytes,
        templateFields: templateFields,
      );
    }
    
    // Otherwise use default template
    final pdf = pw.Document();
    
    final certTitle = certificateSettings?['title'] ?? 
                      certificateType ?? 
                      'PARTICIPATION';
    final signatureName = certificateSettings?['signatureName'] ?? organizerName;
    final signatureTitle = certificateSettings?['signatureTitle'] ?? 'Organizer';

    // Calculate year from semester if available
    String? year;
    if (semester != null) {
      try {
        final sem = int.parse(semester);
        if (sem <= 2) year = '1st Year';
        else if (sem <= 4) year = '2nd Year';
        else if (sem <= 6) year = '3rd Year';
        else if (sem <= 8) year = '4th Year';
        else year = 'Graduate';
      } catch (e) {
        // Keep year as null if parsing fails
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(0),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              gradient: pw.LinearGradient(
                begin: pw.Alignment.topLeft,
                end: pw.Alignment.bottomRight,
                colors: [
                  PdfColors.grey100,
                  PdfColors.white,
                ],
              ),
            ),
            child: pw.Stack(
              children: [
                // Decorative border
                pw.Positioned.fill(
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: PdfColor.fromHex('#D4AF37'),
                        width: 4,
                      ),
                    ),
                  ),
                ),
                pw.Positioned(
                  left: 20,
                  top: 20,
                  right: 20,
                  bottom: 20,
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: PdfColor.fromHex('#F4D03F'), // Lighter gold color
                        width: 1,
                      ),
                    ),
                  ),
                ),
                // Main content
                pw.Padding(
                  padding: const pw.EdgeInsets.all(60),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Award icon placeholder (using text)
                      pw.Container(
                        padding: const pw.EdgeInsets.all(20),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#D4AF37'),
                          shape: pw.BoxShape.circle,
                        ),
                        child: pw.Text(
                          '★',
                          style: pw.TextStyle(
                            fontSize: 40,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 20),
                      // Certificate title
                      pw.Text(
                        'CERTIFICATE OF',
                        style: pw.TextStyle(
                          fontSize: 16,
                          letterSpacing: 3,
                          color: PdfColor.fromHex('#D4AF37'),
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        certTitle,
                        style: pw.TextStyle(
                          fontSize: 32,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.SizedBox(height: 40),
                      // Certificate text
                      pw.Text(
                        'This is to certify that',
                        style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 20),
                      // Participant name
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                        decoration: pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(
                              color: PdfColor.fromHex('#D4AF37'),
                              width: 2,
                            ),
                          ),
                        ),
                        child: pw.Text(
                          participantName.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 28,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#D4AF37'),
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.SizedBox(height: 20),
                      // Participant details (if available)
                      if (department != null || semester != null || collegeName != null || participantClass != null)
                        pw.Column(
                          children: [
                            if (collegeName != null)
                              pw.Text(
                                collegeName,
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  color: PdfColors.grey700,
                                  fontStyle: pw.FontStyle.italic,
                                ),
                              ),
                            if (department != null || semester != null || participantClass != null)
                              pw.Text(
                                [
                                  if (department != null) department,
                                  if (semester != null) 'Semester $semester',
                                  if (participantClass != null) participantClass,
                                  if (year != null) year,
                                ].where((e) => e.isNotEmpty).join(' • '),
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  color: PdfColors.grey700,
                                ),
                              ),
                            pw.SizedBox(height: 20),
                          ],
                        ),
                      // Event details
                      pw.Text(
                        'has successfully participated in',
                        style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 15),
                      pw.Text(
                        eventName,
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        eventDate,
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Spacer(),
                      // Signature section
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Container(
                                width: 150,
                                height: 1,
                                color: PdfColor.fromHex('#D4AF37'),
                              ),
                              pw.SizedBox(height: 5),
                              pw.Text(
                                signatureName,
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.black,
                                ),
                              ),
                              pw.Text(
                                signatureTitle,
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  color: PdfColors.grey700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generate certificate using custom template
  Future<Uint8List> _generateCustomTemplateCertificate({
    required String participantName,
    required String eventName,
    required String eventDate,
    required String organizerName,
    String? department,
    String? semester,
    String? collegeName,
    required String templateImageUrl,
    Uint8List? templateImageBytes,
    required List<Map<String, dynamic>> templateFields,
  }) async {
    final pdf = pw.Document();

    // Download template image or use bytes
    late Uint8List imageBytes;
    if (templateImageBytes != null) {
      imageBytes = templateImageBytes;
    } else {
      final imageResponse = await http.get(Uri.parse(templateImageUrl));
      imageBytes = imageResponse.bodyBytes;
    }
    final image = pw.MemoryImage(imageBytes);

    // Prepare field data map
    final fieldData = <String, String>{
      'participantName': participantName,
      'eventName': eventName,
      'eventDate': eventDate,
      'organizerName': organizerName,
      'department': department ?? '',
      'semester': semester ?? '',
      'collegeName': collegeName ?? '',
    };

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(0),
        build: (pw.Context context) {
          // Get page dimensions
          final pageWidth = context.page.pageFormat.width;
          final pageHeight = context.page.pageFormat.height;

          return pw.Stack(
            children: [
              // Template image as background
              pw.Positioned.fill(
                child: pw.Image(image, fit: pw.BoxFit.fill),
              ),
              // Overlay text fields
              ...templateFields.map((fieldMap) {
                final field = _CertificateField.fromMap(fieldMap);
                final text = fieldData[field.fieldKey] ?? '';
                
                if (text.isEmpty) return pw.Container();

                // Convert Flutter color to PDF color
                final pdfColor = PdfColor(
                  field.fontColor.red / 255,
                  field.fontColor.green / 255,
                  field.fontColor.blue / 255,
                );

                // Convert font weight
                final fontWeight = field.fontWeight == 'bold' 
                    ? pw.FontWeight.bold 
                    : pw.FontWeight.normal;

                // Calculate alignment (-1 to 1) from percentage (0 to 1)
                final alignX = (field.x * 2) - 1;
                final alignY = (field.y * 2) - 1;

                return pw.Align(
                  alignment: pw.Alignment(alignX, alignY),
                  child: pw.Text(
                    text,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: field.fontSize,
                      color: pdfColor,
                      fontWeight: fontWeight,
                    ),
                  ),
                );
              }).toList(),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generate certificates for all participants of an event
  /// This NOW generates the physical PDF and Uploads it to Supabase
  Future<void> generateCertificatesForEvent({
    required String eventId,
    required Map<String, dynamic> eventData,
    required Map<String, dynamic> certificateSettings,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }

    // Verify user is the event creator
    if (eventData['createdBy'] != user.uid) {
      throw Exception("You don't have permission to generate certificates for this event");
    }

    // Get all registrations for this event
    final registrations = await _firestore
        .collection('event_registrations')
        .where('eventId', isEqualTo: eventId)
        .get();

    if (registrations.docs.isEmpty) {
      throw Exception("No registrations found for this event");
    }

    // Format event date
    String eventDateStr = 'Date TBA';
    if (eventData['date'] != null) {
      try {
        final eventDate = (eventData['date'] as Timestamp).toDate();
        eventDateStr = DateFormat('MMMM dd, yyyy').format(eventDate);
      } catch (e) {
        // Keep default
      }
    }

    final organizerName = certificateSettings['signatureName'] ?? 
                         eventData['title'] ?? 
                         'Event Organizer';

    // Priority: 1. Event Data (from Edit Screen), 2. Settings (fallback)
    final templateImageUrl = (eventData['certificateTemplateUrl'] as String?) ?? 
                           (certificateSettings['templateImageUrl'] as String?);
                           
    final rawFields = (eventData['certificateFields'] as List?) ?? 
                      (certificateSettings['templateFields'] as List?);
                      
    final templateFields = rawFields?.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    final storageService = StorageService();

    // Loop through each registration, GEN PDF, UPLOAD, SAVE RECORD
    for (var regDoc in registrations.docs) {
      final regData = regDoc.data();
      final participantName = regData['userName'] ?? 'Participant';
      final department = regData['department'];
      final semester = regData['semester']?.toString();
      final collegeName = regData['collegeName'];
      
      try {
        // 1. Generate PDF Bytes
        final pdfBytes = await generateCertificatePDF(
          participantName: participantName,
          eventName: eventData['title'],
          eventDate: eventDateStr,
          organizerName: organizerName,
          department: department,
          semester: semester,
          collegeName: collegeName,
          templateImageUrl: templateImageUrl,
          templateFields: templateFields,
        );

        // 2. Write to Temp File
        final tempDir = Directory.systemTemp;
        final tempFile = File('${tempDir.path}/cert_${eventId}_${regDoc.id}.pdf');
        await tempFile.writeAsBytes(pdfBytes);

        // 3. Upload to Supabase
        // Path: event_certificates/{eventId}/{userId}.pdf
        final storagePath = 'event_certificates/$eventId/${regData['userId']}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        
        final downloadUrl = await storageService.uploadFile(
          file: tempFile,
          path: storagePath,
          bucket: 'certificates',
        );

        // 4. Save Record to Firestore
        final certificateRef = _firestore
            .collection('certificates')
            .doc('${eventId}_${regDoc.id}');

        await certificateRef.set({
          'eventId': eventId,
          'registrationId': regDoc.id,
          'userId': regData['userId'],
          'participantName': participantName,
          'eventName': eventData['title'],
          'eventDate': eventDateStr,
          'organizerName': organizerName,
          'department': department,
          'semester': semester,
          'collegeName': collegeName,
          'generatedAt': Timestamp.now(),
          'published': false,
          'certificateUrl': downloadUrl, // NEW: Store the permanent link
          'storagePath': storagePath,
          'certificateSettings': certificateSettings,
        });

        // Cleanup temp file
        if (await tempFile.exists()) {
          await tempFile.delete();
        }

      } catch (e) {
        print("Error generating certificate for ${regDoc.id}: $e");
        // Continue to next student even if one fails
      }
    }

    // Mark event as having certificates generated
    await _firestore.collection('events').doc(eventId).update({
      'certificatesGenerated': true,
      'certificatesGeneratedAt': Timestamp.now(),
      'certificateSettings': certificateSettings,
    });
  }

  /// Check if certificates have been generated for an event
  Future<bool> areCertificatesGenerated(String eventId) async {
    final eventDoc = await _firestore.collection('events').doc(eventId).get();
    if (!eventDoc.exists) return false;
    
    final eventData = eventDoc.data();
    return eventData?['certificatesGenerated'] == true;
  }

  /// Check if certificates have been published (made available to participants)
  Future<bool> areCertificatesPublished(String eventId) async {
    final certificates = await _firestore
        .collection('certificates')
        .where('eventId', isEqualTo: eventId)
        .limit(1)
        .get();
    
    if (certificates.docs.isEmpty) return false;
    
    final certData = certificates.docs.first.data();
    return certData['published'] == true;
  }

  /// Publish certificates (make them available to participants)
  Future<void> publishCertificates(String eventId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }

    // Verify user is the event creator
    final eventDoc = await _firestore.collection('events').doc(eventId).get();
    if (!eventDoc.exists) {
      throw Exception("Event not found");
    }
    
    final eventData = eventDoc.data() as Map<String, dynamic>;
    if (eventData['createdBy'] != user.uid) {
      throw Exception("You don't have permission to publish certificates for this event");
    }

    // Update all certificates for this event to published
    final certificates = await _firestore
        .collection('certificates')
        .where('eventId', isEqualTo: eventId)
        .get();

    final batch = _firestore.batch();
    for (var certDoc in certificates.docs) {
      batch.update(certDoc.reference, {
        'published': true,
        'publishedAt': Timestamp.now(),
      });
    }

    await batch.commit();

    // Update event status
    await _firestore.collection('events').doc(eventId).update({
      'certificatesPublished': true,
      'certificatesPublishedAt': Timestamp.now(),
    });
  }

  /// Get certificate for a user and event (generates PDF on-demand OR fetches stored)
  Future<Uint8List?> getUserCertificate({
    required String eventId,
    required String userId,
  }) async {
    final certificates = await _firestore
        .collection('certificates')
        .where('eventId', isEqualTo: eventId)
        .where('userId', isEqualTo: userId)
        .where('published', isEqualTo: true)
        .limit(1)
        .get();

    if (certificates.docs.isEmpty) {
      return null;
    }

    final certData = certificates.docs.first.data();
    
    // OPTIMIZATION: If we have a stored URL, download that PDF directly
    if (certData['certificateUrl'] != null) {
      try {
        final response = await http.get(Uri.parse(certData['certificateUrl']));
        if (response.statusCode == 200) {
          return response.bodyBytes;
        }
      } catch (e) {
        print("Error fetching stored certificate, falling back to generation: $e");
      }
    }

    // Fallback: Generate PDF on-demand from stored metadata
    // Get event data for template
    final eventDoc = await _firestore.collection('events').doc(eventId).get();
    final eventData = eventDoc.data() ?? {};
    
    final pdfBytes = await generateCertificatePDF(
      participantName: certData['participantName'] ?? 'Participant',
      eventName: certData['eventName'] ?? 'Event',
      eventDate: certData['eventDate'] ?? 'Date TBA',
      organizerName: certData['organizerName'] ?? 'Organizer',
      certificateSettings: certData['certificateSettings'] as Map<String, dynamic>?,
      department: certData['department'],
      semester: certData['semester']?.toString(),
      collegeName: certData['collegeName'],
      templateImageUrl: eventData['certificateTemplateUrl'] as String?,
      templateFields: (eventData['certificateFields'] as List<dynamic>?)?.cast<Map<String, dynamic>>(),
    );
    
    return pdfBytes;
  }

  /// Get all certificates for a user
  Future<List<Map<String, dynamic>>> getUserCertificates(String userId) async {
    final certificates = await _firestore
        .collection('certificates')
        .where('userId', isEqualTo: userId)
        .where('published', isEqualTo: true)
        .orderBy('generatedAt', descending: true)
        .get();

    return certificates.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        ...data,
      };
    }).toList();
  }

  /// Download certificate as PDF file
  Future<void> downloadCertificate({
    required Uint8List pdfBytes,
    required String fileName,
  }) async {
    // Use printing package to share/save PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }
  /// Save a design as a reusable template
  Future<void> saveSeriesTemplate({
    required String name,
    required String imageUrl,
    required List<Map<String, dynamic>> fields,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('certificate_templates').add({
      'name': name,
      'imageUrl': imageUrl,
      'fields': fields,
      'createdBy': user.uid,
      'createdAt': Timestamp.now(),
      'isPublic': false, // Private by default
    });
  }

  /// Get available templates (Global + My Created)
  Future<List<Map<String, dynamic>>> getTemplates() async {
    final user = _auth.currentUser;
    
    // 1. Get Public Templates
    final publicQuery = await _firestore
        .collection('certificate_templates')
        .where('isPublic', isEqualTo: true)
        .get();

    // 2. Get My Templates
    QuerySnapshot? privateQuery;
    if (user != null) {
      privateQuery = await _firestore
          .collection('certificate_templates')
          .where('createdBy', isEqualTo: user.uid)
          .get();
    }

    final allDocs = [...publicQuery.docs, ...(privateQuery?.docs ?? [])];
    
    // Deduplicate based on ID if needed, but simple map is usually fine
    return allDocs.map<Map<String, dynamic>>((doc) => {
      'id': doc.id,
      ...(doc.data() as Map<String, dynamic>),
    }).toList();
  }
}

// Helper class for certificate fields
class _CertificateField {
  final double x;
  final double y;
  final String fieldKey;
  final double fontSize;
  final Color fontColor;
  final String fontWeight;

  _CertificateField({
    required this.x,
    required this.y,
    required this.fieldKey,
    required this.fontSize,
    required this.fontColor,
    this.fontWeight = 'normal',
  });

  factory _CertificateField.fromMap(Map<String, dynamic> map) {
    final colorMap = map['fontColor'] as Map<String, dynamic>;
    return _CertificateField(
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      fieldKey: map['fieldKey'] as String,
      fontSize: (map['fontSize'] as num).toDouble(),
      fontWeight: map['fontWeight'] ?? 'normal',
      fontColor: Color.fromARGB(
        colorMap['a'] as int,
        colorMap['r'] as int,
        colorMap['g'] as int,
        colorMap['b'] as int,
      ),
    );
  }
}

