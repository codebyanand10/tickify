import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  final user = FirebaseAuth.instance.currentUser;

  // Helper to check if event is expired
  bool _isEventExpired(Timestamp? eventDate, String? eventTime) {
    if (eventDate == null) return false;
    
    final now = DateTime.now();
    final eventDateTime = eventDate.toDate();
    
    // If event time is available, compare with time
    if (eventTime != null) {
      try {
        final parts = eventTime.split(':');
        if (parts.length == 2) {
          final eventDateTimeWithTime = DateTime(
            eventDateTime.year,
            eventDateTime.month,
            eventDateTime.day,
            int.parse(parts[0]),
            int.parse(parts[1]),
          );
          return eventDateTimeWithTime.isBefore(now);
        }
      } catch (e) {
        // If time parsing fails, just compare dates
      }
    }
    
    // Compare just the date (end of day)
    final eventEndOfDay = DateTime(
      eventDateTime.year,
      eventDateTime.month,
      eventDateTime.day,
      23,
      59,
      59,
    );
    
    return eventEndOfDay.isBefore(now);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.confirmation_number, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'My Tickets',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      const Color(0xFF1E1E1E),
                      const Color(0xFF1E1E1E),
                    ]
                  : [
                      Colors.white,
                      Colors.white,
                    ],
            ),
          ),
        ),
      ),
      body: user == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.login,
                    size: 64,
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Please log in to view your tickets',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('event_registrations')
                  .where('userId', isEqualTo: user!.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading tickets',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade300,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF6C5CE7).withOpacity(0.2),
                                const Color(0xFFA29BFE).withOpacity(0.2),
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.confirmation_number_outlined,
                            size: 64,
                            color: const Color(0xFF6C5CE7),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No tickets yet',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Register for events to see your tickets here',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Process registrations and group by event
                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: _processRegistrations(snapshot.data!.docs),
                  builder: (context, processedSnapshot) {
                    if (processedSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final groupedTickets = processedSnapshot.data ?? [];
                    
                    if (groupedTickets.isEmpty) {
                      return const Center(child: Text('No tickets found'));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: groupedTickets.length,
                      itemBuilder: (context, index) {
                        final eventGroup = groupedTickets[index];
                        final eventData = eventGroup['eventData'] as Map<String, dynamic>;
                        final registrationsList = eventGroup['registrations'] as List;
                        final registrations = registrationsList.cast<Map<String, dynamic>>();
                        final isExpired = eventGroup['isExpired'] as bool;
                        final eventDate = eventData['date'] as Timestamp?;
                        final eventTime = eventData['time'] as String?;
                        final eventTitle = eventData['title'] ?? 'Event';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isExpired
                                  ? Colors.grey.shade600.withOpacity(0.3)
                                  : const Color(0xFF6C5CE7).withOpacity(0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isExpired
                                    ? Colors.black.withOpacity(0.05)
                                    : const Color(0xFF6C5CE7).withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Event Header Block (Tappable)
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _showTicketDetails(
                                    context,
                                    eventTitle,
                                    eventData,
                                    registrations,
                                    isExpired,
                                    isDark,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      gradient: isExpired
                                          ? LinearGradient(
                                              colors: [
                                                Colors.grey.shade700,
                                                Colors.grey.shade600,
                                              ],
                                            )
                                          : const LinearGradient(
                                              colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                                            ),
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(20),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            isExpired ? Icons.event_busy : Icons.event,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      eventTitle,
                                                      style: const TextStyle(
                                                        fontSize: 20,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (isExpired)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red.shade400,
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: const Text(
                                                        'EXPIRED',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.white,
                                                          letterSpacing: 1,
                                                        ),
                                                      ),
                                                    )
                                                  else
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.green.shade400,
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: const Text(
                                                        'ACTIVE',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.white,
                                                          letterSpacing: 1,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 16,
                                                runSpacing: 8,
                                                crossAxisAlignment: WrapCrossAlignment.center,
                                                children: [
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.calendar_today,
                                                        size: 14,
                                                        color: Colors.white.withOpacity(0.9),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Flexible(
                                                        child: Text(
                                                          eventDate != null
                                                              ? DateFormat('MMM dd, yyyy').format(eventDate.toDate())
                                                              : 'Date TBA',
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            color: Colors.white.withOpacity(0.9),
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (eventTime != null)
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.access_time,
                                                          size: 14,
                                                          color: Colors.white.withOpacity(0.9),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Flexible(
                                                          child: Text(
                                                            eventTime,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: Colors.white.withOpacity(0.9),
                                                            ),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Tap to view ticket details',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.white.withOpacity(0.8),
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          size: 16,
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Tickets List
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: registrations.asMap().entries.map((entry) {
                                    final idx = entry.key;
                                    final registration = entry.value;
                                    final regData = registration['regData'] as Map<String, dynamic>;
                                    final ticketNumber = regData['ticketNumber'] as String? ?? 'N/A';

                                    return Container(
                                      margin: EdgeInsets.only(bottom: idx < registrations.length - 1 ? 12 : 0),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isExpired
                                            ? (isDark ? Colors.grey.shade900 : Colors.grey.shade100)
                                            : (isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isExpired
                                              ? Colors.grey.shade600.withOpacity(0.3)
                                              : const Color(0xFF6C5CE7).withOpacity(0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: isExpired
                                                  ? Colors.grey.shade700.withOpacity(0.5)
                                                  : const Color(0xFF6C5CE7).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              Icons.confirmation_number,
                                              size: 20,
                                              color: isExpired
                                                  ? Colors.grey.shade400
                                                  : const Color(0xFF6C5CE7),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Ticket: $ticketNumber',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: isExpired
                                                        ? Colors.grey.shade400
                                                        : (isDark ? Colors.white : Colors.black87),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Tap event header to view QR code',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isExpired
                                                        ? Colors.grey.shade500
                                                        : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  Future<List<Map<String, dynamic>>> _processRegistrations(
    List<QueryDocumentSnapshot> registrations,
  ) async {
    final Map<String, Map<String, dynamic>> eventGroups = {};
    final List<Map<String, dynamic>> result = [];

    // Group registrations by event
    for (var regDoc in registrations) {
      final regData = regDoc.data() as Map<String, dynamic>;
      final eventId = regData['eventId'] as String?;

      if (eventId == null) continue;

      // Fetch event data
      final eventDoc = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .get();

      if (!eventDoc.exists) continue;

      final eventData = eventDoc.data() as Map<String, dynamic>;
      final eventTitle = eventData['title'] ?? 'Event';

      // Use event title as key for grouping
      if (!eventGroups.containsKey(eventTitle)) {
        eventGroups[eventTitle] = {
          'eventId': eventId,
          'eventData': eventData,
          'registrations': <Map<String, dynamic>>[],
        };
      }

      (eventGroups[eventTitle]!['registrations'] as List<Map<String, dynamic>>).add({
        'regData': regData,
        'eventId': eventId,
      });
    }

    // Convert to list and sort
    for (var entry in eventGroups.entries) {
      final eventData = entry.value['eventData'] as Map<String, dynamic>;
      final eventDate = eventData['date'] as Timestamp?;
      final eventTime = eventData['time'] as String?;
      final isExpired = _isEventExpired(eventDate, eventTime);

      result.add({
        'eventTitle': entry.key,
        'eventData': eventData,
        'registrations': entry.value['registrations'],
        'isExpired': isExpired,
      });
    }

    // Sort: active tickets first, then expired
    result.sort((a, b) {
      final aExpired = a['isExpired'] as bool;
      final bExpired = b['isExpired'] as bool;

      if (aExpired == bExpired) {
        // If both have same status, sort by date (newer first)
        final aDate = a['eventData']['date'] as Timestamp?;
        final bDate = b['eventData']['date'] as Timestamp?;
        if (aDate != null && bDate != null) {
          return bDate.compareTo(aDate);
        }
        return 0;
      }

      // Active (false) comes before expired (true)
      return aExpired ? 1 : -1;
    });

    return result;
  }

  void _showTicketDetails(
    BuildContext context,
    String eventTitle,
    Map<String, dynamic> eventData,
    List<Map<String, dynamic>> registrations,
    bool isExpired,
    bool isDark,
  ) {
    final eventDate = eventData['date'] as Timestamp?;
    final eventTime = eventData['time'] as String?;
    final eventLocation = eventData['location'] as String? ?? 'TBA';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          eventTitle,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (isExpired)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.red.shade400,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'EXPIRED',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.shade400,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'ACTIVE',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Event Details Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: isExpired
                            ? LinearGradient(
                                colors: [
                                  Colors.grey.shade700,
                                  Colors.grey.shade600,
                                ],
                              )
                            : const LinearGradient(
                                colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                              ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(
                            Icons.calendar_today,
                            'Date',
                            eventDate != null
                                ? DateFormat('EEEE, MMMM dd, yyyy').format(eventDate.toDate())
                                : 'Date TBA',
                            Colors.white,
                          ),
                          if (eventTime != null) ...[
                            const SizedBox(height: 16),
                            _buildDetailRow(
                              Icons.access_time,
                              'Time',
                              eventTime,
                              Colors.white,
                            ),
                          ],
                          const SizedBox(height: 16),
                          _buildDetailRow(
                            Icons.location_on,
                            'Location',
                            eventLocation,
                            Colors.white,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Tickets List
                    Text(
                      'Your Tickets (${registrations.length})',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...registrations.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final registration = entry.value;
                      final regData = registration['regData'] as Map<String, dynamic>;
                      final ticketNumber = regData['ticketNumber'] as String? ?? 'N/A';
                      final qrCodeData = regData['qrCodeData'] as String? ?? '';

                      return Container(
                        margin: EdgeInsets.only(bottom: idx < registrations.length - 1 ? 20 : 0),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isExpired
                                ? Colors.grey.shade600.withOpacity(0.3)
                                : const Color(0xFF6C5CE7).withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Ticket Number
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isExpired
                                    ? Colors.grey.shade700.withOpacity(0.5)
                                    : const Color(0xFF6C5CE7).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.tag,
                                    size: 18,
                                    color: isExpired
                                        ? Colors.grey.shade400
                                        : const Color(0xFF6C5CE7),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Ticket: $ticketNumber',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isExpired
                                          ? Colors.grey.shade400
                                          : (isDark ? Colors.white : Colors.black87),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            // QR Code
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isExpired
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade300,
                                  width: 2,
                                ),
                              ),
                              child: Opacity(
                                opacity: isExpired ? 0.5 : 1.0,
                                child: QrImageView(
                                  data: qrCodeData,
                                  version: QrVersions.auto,
                                  size: 200,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color textColor) {
    return Row(
      children: [
        Icon(icon, size: 20, color: textColor.withOpacity(0.9)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: textColor.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
