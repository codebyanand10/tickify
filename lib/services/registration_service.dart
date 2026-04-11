import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'dart:convert';

class RegistrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Generate unique ticket number
  String _generateTicketNumber() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final randomNum = random.nextInt(9999).toString().padLeft(4, '0');
    return 'TICK-$timestamp-$randomNum';
  }

  // Generate QR code data as JSON string
  String _generateQRCodeData({
    required String name,
    required String ticketNumber,
    required String eventTitle,
    required String eventDate,
    required String eventTime,
    required String eventVenue,
    String? year,
    String? department,
    String? semester,
    String? collegeName,
  }) {
    final qrData = {
      'ticketNumber': ticketNumber,
      'name': name,
      'eventTitle': eventTitle,
      'eventDate': eventDate,
      'eventTime': eventTime,
      'eventVenue': eventVenue,
      if (year != null) 'year': year,
      if (department != null) 'department': department,
      if (semester != null) 'semester': semester,
      if (collegeName != null) 'collegeName': collegeName,
    };
    return jsonEncode(qrData);
  }

  // Register for an event
  Future<Map<String, dynamic>> registerForEvent({
    required String eventId,
    required Map<String, dynamic> eventData,
    required Map<String, dynamic> userData,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }

    // Check if already registered
    final existingRegistration = await _firestore
        .collection('event_registrations')
        .where('eventId', isEqualTo: eventId)
        .where('userId', isEqualTo: user.uid)
        .get();

    if (existingRegistration.docs.isNotEmpty) {
      throw Exception("Already registered for this event");
    }

    // Check if event has limited seats
    if (eventData['limitedSeats'] == true) {
      final registrationsCount = await _firestore
          .collection('event_registrations')
          .where('eventId', isEqualTo: eventId)
          .get();

      final availableSeats = eventData['seatCount'] as int? ?? 0;
      if (registrationsCount.docs.length >= availableSeats) {
        throw Exception("Event is fully booked");
      }
    }

    final ticketNumber = _generateTicketNumber();
    final eventDate = eventData['date'] != null
        ? (eventData['date'] as Timestamp).toDate().toString().split(' ')[0]
        : 'TBA';
    final eventTime = eventData['time'] ?? 'TBA';

    // Generate QR code data
    final qrData = _generateQRCodeData(
      name: userData['name'] ?? '',
      ticketNumber: ticketNumber,
      eventTitle: eventData['title'] ?? '',
      eventDate: eventDate,
      eventTime: eventTime.toString(),
      eventVenue: eventData['location'] ?? 'TBA',
      year: userData['role'] == 'student' ? _calculateYear(userData['semester']) : null,
      department: userData['department'],
      semester: userData['semester'],
      collegeName: userData['collegeName'],
    );

    // Create registration document
    final registrationData = <String, dynamic>{
      'eventId': eventId,
      'userId': user.uid,
      'ticketNumber': ticketNumber,
      'qrCodeData': qrData,
      'registeredAt': Timestamp.now(),
      'status': 'confirmed',
      // User details
      'userName': userData['name'],
      'userEmail': user.email,
      'userRole': userData['role'],
    };

    // Add student-specific fields
    if (userData['role'] == 'student') {
      registrationData['collegeName'] = userData['collegeName'];
      registrationData['department'] = userData['department'];
      registrationData['semester'] = userData['semester'];
    }

    // Add organizer/admin specific fields
    if (userData['role'] == 'organizer' || userData['role'] == 'admin') {
      registrationData['phone'] = userData['phone'];
      registrationData['dateOfBirth'] = userData['dateOfBirth'];
    }

    // Add payment info if paid event
    if (eventData['paidEvent'] == true) {
      registrationData['paymentStatus'] = 'pending';
      registrationData['amount'] = eventData['feeAmount'];
    }

    final registrationRef = await _firestore
        .collection('event_registrations')
        .add(registrationData);

    return {
      'registrationId': registrationRef.id,
      'ticketNumber': ticketNumber,
      'qrCodeData': qrData,
    };
  }

  // Calculate year from semester
  String _calculateYear(String? semester) {
    if (semester == null) return '';
    try {
      final sem = int.parse(semester);
      if (sem <= 2) return '1st Year';
      if (sem <= 4) return '2nd Year';
      if (sem <= 6) return '3rd Year';
      if (sem <= 8) return '4th Year';
      return 'Graduate';
    } catch (e) {
      return '';
    }
  }

  // Get user registrations
  Stream<QuerySnapshot> getUserRegistrations() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }

    return _firestore
        .collection('event_registrations')
        .where('userId', isEqualTo: user.uid)
        .orderBy('registeredAt', descending: true)
        .snapshots();
  }

  // Get event registrations (for host)
  Stream<QuerySnapshot> getEventRegistrations(String eventId) {
    return _firestore
        .collection('event_registrations')
        .where('eventId', isEqualTo: eventId)
        .orderBy('registeredAt', descending: true)
        .snapshots();
  }

  // Get event analytics
  Future<Map<String, dynamic>> getEventAnalytics(String eventId) async {
    final registrations = await _firestore
        .collection('event_registrations')
        .where('eventId', isEqualTo: eventId)
        .get();

    final totalRegistrations = registrations.docs.length;

    double totalAmount = 0;
    int paidCount = 0;

    for (var doc in registrations.docs) {
      final data = doc.data();
      if (data['paymentStatus'] == 'paid' && data['amount'] != null) {
        totalAmount += (data['amount'] as num).toDouble();
        paidCount++;
      }
    }

    return {
      'totalRegistrations': totalRegistrations,
      'totalAmount': totalAmount,
      'paidCount': paidCount,
    };
  }

  // Get attendance records (only scanned tickets)
  Future<List<Map<String, dynamic>>> getAttendanceRecords(String eventId) async {
    final registrations = await _firestore
        .collection('event_registrations')
        .where('eventId', isEqualTo: eventId)
        .where('attendanceMarked', isEqualTo: true)
        .get();

    final attendanceRecords = <Map<String, dynamic>>[];

    for (var doc in registrations.docs) {
      final regData = doc.data();
      final qrCodeData = regData['qrCodeData'] as String?;

      if (qrCodeData != null) {
        try {
          final qrData = jsonDecode(qrCodeData) as Map<String, dynamic>;
          attendanceRecords.add({
            'name': qrData['name'] ?? regData['userName'] ?? 'Unknown',
            'collegeName': qrData['collegeName'] ?? regData['collegeName'] ?? 'N/A',
            'department': qrData['department'] ?? regData['department'] ?? 'N/A',
            'semester': qrData['semester'] ?? regData['semester'] ?? 'N/A',
            'ticketNumber': regData['ticketNumber'] ?? '',
            'attendanceMarkedAt': regData['attendanceMarkedAt'],
          });
        } catch (e) {
          // If QR parsing fails, use registration data
          attendanceRecords.add({
            'name': regData['userName'] ?? 'Unknown',
            'collegeName': regData['collegeName'] ?? 'N/A',
            'department': regData['department'] ?? 'N/A',
            'semester': regData['semester'] ?? 'N/A',
            'ticketNumber': regData['ticketNumber'] ?? '',
            'attendanceMarkedAt': regData['attendanceMarkedAt'],
          });
        }
      }
    }

    // Sort by attendance marked time
    attendanceRecords.sort((a, b) {
      final aTime = a['attendanceMarkedAt'] as Timestamp?;
      final bTime = b['attendanceMarkedAt'] as Timestamp?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return aTime.compareTo(bTime);
    });

    return attendanceRecords;
  }

  // Verify and mark attendance from QR code
  Future<Map<String, dynamic>> verifyTicketAndMarkAttendance({
    required String qrCodeData,
    required String eventId,
  }) async {
    try {
      final qrData = jsonDecode(qrCodeData) as Map<String, dynamic>;
      final ticketNumber = qrData['ticketNumber'] as String?;

      if (ticketNumber == null) {
        throw Exception("Invalid QR code");
      }

      // Find registration
      final registration = await _firestore
          .collection('event_registrations')
          .where('eventId', isEqualTo: eventId)
          .where('ticketNumber', isEqualTo: ticketNumber)
          .get();

      if (registration.docs.isEmpty) {
        throw Exception("Ticket not found");
      }

      final regDoc = registration.docs.first;
      final regData = regDoc.data();

      // Check if already checked in
      if (regData['attendanceMarked'] == true) {
        return {
          'success': false,
          'message': 'Ticket already used',
          'data': regData,
        };
      }

      // Mark attendance
      await regDoc.reference.update({
        'attendanceMarked': true,
        'attendanceMarkedAt': Timestamp.now(),
      });

      return {
        'success': true,
        'message': 'Attendance marked successfully',
        'data': regData,
      };
    } catch (e) {
      throw Exception("Error verifying ticket: ${e.toString()}");
    }
  }
}

