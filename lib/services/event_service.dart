import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'notification_db_service.dart';
import 'notification_service.dart';

class EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> createEvent(Map<String, dynamic> eventData) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not logged in");
    }

    // Convert TimeOfDay to string format
    String? timeString;
    if (eventData['time'] != null) {
      final time = eventData['time'] as TimeOfDay;
      timeString = "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
    }

    // Convert DateTime to Timestamp
    Timestamp? dateTimestamp;
    if (eventData['date'] != null) {
      dateTimestamp = Timestamp.fromDate(eventData['date'] as DateTime);
    }
 
    // Ensure category is a valid lowercase key
    final category = (eventData['category'] ?? '').toString().toLowerCase().trim();
    
    // Debug: Print category being saved
    print('📝 Saving event with category: $category');

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    // Use toLowerCase() to handle any case variation (e.g. 'Admin', 'ADMIN')
    final userRole = (userDoc.data()?['role'] ?? 'student').toString().toLowerCase().trim();
    // Only admin users can publish directly; all others go through approval workflow
    final status = (userRole == 'admin') ? 'published' : 'pending';

    await _firestore.collection('events').add({
      'title': eventData['title'] ?? '',
      'category': category,
      'description': eventData['description'] ?? '',
      'location': eventData['location'] ?? '',
      'date': dateTimestamp,
      'time': timeString,
      'collegeType': eventData['collegeType'] ?? 'Intra College',
      'hostingUniversity': eventData['hostingUniversity'] ?? userDoc.data()?['university'] ?? '',
      'hostingCollege': eventData['hostingCollege'] ?? userDoc.data()?['collegeName'] ?? '',
      'limitedSeats': eventData['limitedSeats'] ?? false,
      'seatCount': eventData['seatCount'],
      'paidEvent': eventData['paidEvent'] ?? false,
      'feeAmount': eventData['feeAmount'],
      'certification': eventData['certification'] ?? false,
      'whatsappLink': eventData['whatsapp'],
      'posterUrl': eventData['posterUrl'],
      'certificateTemplateUrl': eventData['certificateTemplateUrl'],
      'certificateFields': eventData['certificateFields'],
      'audience': eventData['audience'] ?? {
        'students': false,
        'outsiders': false,
        'staff': false,
      },
      'coordinators': (eventData['coordinators'] as List? ?? []).map((c) => {
        'name': c['name']?.toString() ?? '',
        'phone': c['phone']?.toString() ?? '',
      }).toList(),
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'status': status,
    });
  }

  Future<void> updateEvent(String eventId, Map<String, dynamic> eventData) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not logged in");
    }

    // Verify the user is the creator of the event
    final eventDoc = await _firestore.collection('events').doc(eventId).get();
    if (!eventDoc.exists) {
      throw Exception("Event not found");
    }
    
    final existingEventData = eventDoc.data() as Map<String, dynamic>;
    if (existingEventData['createdBy'] != user.uid) {
      throw Exception("You don't have permission to edit this event");
    }

    final Map<String, dynamic> updateData = {};

    // Basic details
    if (eventData.containsKey('title')) updateData['title'] = eventData['title'];
    if (eventData.containsKey('description')) updateData['description'] = eventData['description'];
    if (eventData.containsKey('location')) updateData['location'] = eventData['location'];
    
    // Category (with lowercase conversion)
    if (eventData.containsKey('category')) {
      updateData['category'] = eventData['category'].toString().toLowerCase().trim();
    }

    // Time parsing
    if (eventData.containsKey('time') && eventData['time'] != null) {
      if (eventData['time'] is TimeOfDay) {
        final time = eventData['time'] as TimeOfDay;
        updateData['time'] = "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
      } else {
        updateData['time'] = eventData['time'];
      }
    }

    // Date parsing
    if (eventData.containsKey('date') && eventData['date'] != null) {
      if (eventData['date'] is DateTime) {
        updateData['date'] = Timestamp.fromDate(eventData['date'] as DateTime);
      } else {
        updateData['date'] = eventData['date'];
      }
    }

    // Toggles and numeric fields
    if (eventData.containsKey('limitedSeats')) updateData['limitedSeats'] = eventData['limitedSeats'];
    if (eventData.containsKey('seatCount')) updateData['seatCount'] = eventData['seatCount'];
    if (eventData.containsKey('paidEvent')) updateData['paidEvent'] = eventData['paidEvent'];
    if (eventData.containsKey('feeAmount')) updateData['feeAmount'] = eventData['feeAmount'];
    if (eventData.containsKey('certification')) updateData['certification'] = eventData['certification'];
    if (eventData.containsKey('isTeamEvent')) updateData['isTeamEvent'] = eventData['isTeamEvent'];
    
    // Institution
    if (eventData.containsKey('collegeType')) updateData['collegeType'] = eventData['collegeType'];
    if (eventData.containsKey('hostingUniversity')) updateData['hostingUniversity'] = eventData['hostingUniversity'];
    if (eventData.containsKey('hostingCollege')) updateData['hostingCollege'] = eventData['hostingCollege'];

    // Audience
    if (eventData.containsKey('audience')) updateData['audience'] = eventData['audience'];
    
    // Coordinators
    if (eventData.containsKey('coordinators')) updateData['coordinators'] = eventData['coordinators'];
    
    // WhatsApp and Poster
    if (eventData.containsKey('whatsapp')) updateData['whatsappLink'] = eventData['whatsapp'];
    if (eventData.containsKey('whatsappLink')) updateData['whatsappLink'] = eventData['whatsappLink'];
    if (eventData.containsKey('posterUrl')) updateData['posterUrl'] = eventData['posterUrl'];

    // Certificate Fields (IMPORTANT FIX)
    if (eventData.containsKey('certificateTemplateUrl')) updateData['certificateTemplateUrl'] = eventData['certificateTemplateUrl'];
    if (eventData.containsKey('certificateFields')) updateData['certificateFields'] = eventData['certificateFields'];
    if (eventData.containsKey('certificateSettings')) updateData['certificateSettings'] = eventData['certificateSettings'];

    updateData['updatedAt'] = Timestamp.now();

    await _firestore.collection('events').doc(eventId).update(updateData);
  }

  Future<void> deleteEvent(String eventId) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not logged in");
    }

    // Verify the user is the creator of the event
    final eventDoc = await _firestore.collection('events').doc(eventId).get();
    if (!eventDoc.exists) {
      throw Exception("Event not found");
    }
    
    final eventData = eventDoc.data() as Map<String, dynamic>;
    if (eventData['createdBy'] != user.uid) {
      throw Exception("You don't have permission to delete this event");
    }

    // Get all registrations for this event
    final registrations = await _firestore
        .collection('event_registrations')
        .where('eventId', isEqualTo: eventId)
        .get();

    // Create notifications for all registered users
    final notificationDbService = NotificationDbService();
    final localNotificationService = NotificationService();
    await localNotificationService.initialize();
    
    final eventTitle = eventData['title'] ?? 'Event';
    final eventDate = eventData['date'] as Timestamp?;
    final eventLocation = eventData['location'] as String? ?? '';
    
    // Format event date for notification
    String eventDateStr = 'Date TBA';
    if (eventDate != null) {
      try {
        eventDateStr = DateFormat('MMM dd, yyyy').format(eventDate.toDate());
      } catch (e) {
        // Keep default
      }
    }
    
    for (var regDoc in registrations.docs) {
      final regData = regDoc.data();
      final userId = regData['userId'] as String?;
      
      if (userId != null) {
        // Create notification in Firestore
        await notificationDbService.createNotification(
          userId: userId,
          title: 'Event Cancelled',
          body: 'The event "$eventTitle" has been cancelled by the host.',
          type: 'event_cancelled',
          eventId: eventId,
          data: {
            'eventTitle': eventTitle,
            'eventId': eventId,
          },
        );
        
        // Send immediate pop-up notification
        // Generate unique notification ID based on event ID and user ID
        final notificationId = (eventId.hashCode + userId.hashCode).abs() % 2147483647;
        
        try {
          await localNotificationService.showNotification(
            id: notificationId,
            title: '🚫 Event Cancelled: $eventTitle',
            body: 'The event "$eventTitle" scheduled for $eventDateStr${eventLocation.isNotEmpty ? ' at $eventLocation' : ''} has been cancelled by the host.',
            payload: eventId,
            channelId: 'reminder_channel',
            channelName: 'Event Reminders',
          );
        } catch (e) {
          // If notification fails, continue with other users
          print('Error sending notification to user $userId: $e');
        }
      }
    }

    // Delete the event
    await _firestore.collection('events').doc(eventId).delete();
  }

  Future<void> updateEventStatus(String eventId, String status) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");
    
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userRole = (userDoc.data()?['role'] ?? 'student').toString().toLowerCase().trim();
    
    if (userRole != 'admin') {
      throw Exception("Only admins can update event status");
    }

    await _firestore.collection('events').doc(eventId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (status == 'rejected') {
      // Create a notification for the creator
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (eventDoc.exists) {
        final creatorId = eventDoc.data()?['createdBy'];
        final title = eventDoc.data()?['title'] ?? 'Event';
        if (creatorId != null) {
          final notificationDbService = NotificationDbService();
          await notificationDbService.createNotification(
            userId: creatorId,
            title: 'Event Request Rejected',
            body: 'Your event request "$title" has been rejected.',
            type: 'event_rejected',
            eventId: eventId,
          );
        }
      }
    } else if (status == 'published') {
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (eventDoc.exists) {
        final creatorId = eventDoc.data()?['createdBy'];
        final title = eventDoc.data()?['title'] ?? 'Event';
        if (creatorId != null) {
          final notificationDbService = NotificationDbService();
          await notificationDbService.createNotification(
            userId: creatorId,
            title: 'Event Request Approved',
            body: 'Your event "$title" has been published successfully.',
            type: 'event_approved',
            eventId: eventId,
          );
        }
      }
    }
  }
}

