import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../services/registration_service.dart';
import 'event_registration_screen.dart';
import 'create_event_screen.dart';
import 'reminder_setting_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late ValueNotifier<List<DocumentSnapshot>> _selectedEvents;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  final RegistrationService _registrationService = RegistrationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Maps to store events and registrations by date
  Map<DateTime, List<DocumentSnapshot>> _eventsMap = {};
  Map<DateTime, List<DocumentSnapshot>> _registeredEventsMap = {};
  Map<String, DocumentSnapshot> _allEvents = {};
  Map<String, DocumentSnapshot> _userRegistrations = {};

  @override
  void initState() {
    super.initState();
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay));
    _loadEventsAndRegistrations();
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  // Load all events and user registrations
  Future<void> _loadEventsAndRegistrations() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Load events first
    final eventsSnapshot = await FirebaseFirestore.instance
        .collection('events')
        .where('status', isEqualTo: 'published')
        .get();

    final eventsMap = <DateTime, List<DocumentSnapshot>>{};
    final allEvents = <String, DocumentSnapshot>{};

    for (var doc in eventsSnapshot.docs) {
      final eventData = doc.data();
      final date = eventData['date'] as Timestamp?;
      
      if (date != null) {
        final eventDate = date.toDate();
        final dateKey = DateTime(eventDate.year, eventDate.month, eventDate.day);
        
        if (!eventsMap.containsKey(dateKey)) {
          eventsMap[dateKey] = [];
        }
        // Check if event is already in the list to avoid duplicates
        final existingIndex = eventsMap[dateKey]!.indexWhere(
          (e) => e.id == doc.id,
        );
        if (existingIndex == -1) {
          eventsMap[dateKey]!.add(doc);
        }
        allEvents[doc.id] = doc;
      }
    }

    // Now load user registrations
    final registrationsSnapshot = await _registrationService.getUserRegistrations().first;

    final registeredEventsMap = <DateTime, List<DocumentSnapshot>>{};
    final userRegistrations = <String, DocumentSnapshot>{};

    for (var regDoc in registrationsSnapshot.docs) {
      final regData = regDoc.data() as Map<String, dynamic>;
      final eventId = regData['eventId'] as String?;
      
      if (eventId != null) {
        // Try to get event from loaded events first
        DocumentSnapshot? eventDoc = allEvents[eventId];
        
        // If event not in loaded events, fetch it directly
        if (eventDoc == null) {
          try {
            final eventSnapshot = await FirebaseFirestore.instance
                .collection('events')
                .doc(eventId)
                .get();
            
            if (eventSnapshot.exists) {
              eventDoc = eventSnapshot;
              final eventData = eventDoc.data() as Map<String, dynamic>;
              final date = eventData['date'] as Timestamp?;
              
              // Add to allEvents and eventsMap if it has a date
              if (date != null) {
                allEvents[eventId] = eventDoc;
                final eventDate = date.toDate();
                final dateKey = DateTime(eventDate.year, eventDate.month, eventDate.day);
                
                if (!eventsMap.containsKey(dateKey)) {
                  eventsMap[dateKey] = [];
                }
                // Check if event is already in the list to avoid duplicates
                final existingIndex = eventsMap[dateKey]!.indexWhere(
                  (e) => e.id == eventId,
                );
                if (existingIndex == -1) {
                  eventsMap[dateKey]!.add(eventDoc);
                }
              }
            }
          } catch (e) {
            print('Error fetching event $eventId: $e');
            continue;
          }
        }
        
        // Process registration if we have the event
        if (eventDoc != null) {
          final eventData = eventDoc.data() as Map<String, dynamic>;
          final date = eventData['date'] as Timestamp?;
          
          if (date != null) {
            final eventDate = date.toDate();
            final dateKey = DateTime(eventDate.year, eventDate.month, eventDate.day);
            
            if (!registeredEventsMap.containsKey(dateKey)) {
              registeredEventsMap[dateKey] = [];
            }
            // Check if event is already in the list to avoid duplicates
            final existingIndex = registeredEventsMap[dateKey]!.indexWhere(
              (e) => e.id == eventId,
            );
            if (existingIndex == -1) {
              registeredEventsMap[dateKey]!.add(eventDoc);
            }
            userRegistrations[eventId] = regDoc;
          }
        }
      }
    }

    setState(() {
      _eventsMap = eventsMap;
      _allEvents = allEvents;
      _registeredEventsMap = registeredEventsMap;
      _userRegistrations = userRegistrations;
    });
  }

  // Update registrations from a snapshot (used by StreamBuilder)
  Future<void> _updateRegistrationsFromSnapshot(QuerySnapshot snapshot) async {
    final registeredEventsMap = <DateTime, List<DocumentSnapshot>>{};
    final userRegistrations = <String, DocumentSnapshot>{};

    for (var regDoc in snapshot.docs) {
      final regData = regDoc.data() as Map<String, dynamic>;
      final eventId = regData['eventId'] as String?;
      
      if (eventId != null) {
        DocumentSnapshot? eventDoc = _allEvents[eventId];
        
        // If event not in loaded events, fetch it
        if (eventDoc == null) {
          try {
            final eventSnapshot = await FirebaseFirestore.instance
                .collection('events')
                .doc(eventId)
                .get();
            
            if (eventSnapshot.exists) {
              eventDoc = eventSnapshot;
              final eventData = eventDoc.data() as Map<String, dynamic>;
              final date = eventData['date'] as Timestamp?;
              
              if (date != null) {
                _allEvents[eventId] = eventDoc;
                final eventDate = date.toDate();
                final dateKey = DateTime(eventDate.year, eventDate.month, eventDate.day);
                
                if (!_eventsMap.containsKey(dateKey)) {
                  _eventsMap[dateKey] = [];
                }
                // Check if event is already in the list to avoid duplicates
                final existingIndex = _eventsMap[dateKey]!.indexWhere(
                  (e) => e.id == eventId,
                );
                if (existingIndex == -1) {
                  _eventsMap[dateKey]!.add(eventDoc);
                }
              }
            }
          } catch (e) {
            continue;
          }
        }
        
        if (eventDoc != null) {
          final eventData = eventDoc.data() as Map<String, dynamic>;
          final date = eventData['date'] as Timestamp?;
          
          if (date != null) {
            final eventDate = date.toDate();
            final dateKey = DateTime(eventDate.year, eventDate.month, eventDate.day);
            
            if (!registeredEventsMap.containsKey(dateKey)) {
              registeredEventsMap[dateKey] = [];
            }
            // Check if event is already in the list to avoid duplicates
            final existingIndex = registeredEventsMap[dateKey]!.indexWhere(
              (e) => e.id == eventId,
            );
            if (existingIndex == -1) {
              registeredEventsMap[dateKey]!.add(eventDoc);
            }
            userRegistrations[eventId] = regDoc;
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _registeredEventsMap = registeredEventsMap;
        _userRegistrations = userRegistrations;
      });
    }
  }

  // Refresh registrations (called after user registers or manually)
  Future<void> _refreshRegistrations() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final registrationsSnapshot = await _registrationService.getUserRegistrations().first;

    final registeredEventsMap = <DateTime, List<DocumentSnapshot>>{};
    final userRegistrations = <String, DocumentSnapshot>{};

    for (var regDoc in registrationsSnapshot.docs) {
      final regData = regDoc.data() as Map<String, dynamic>;
      final eventId = regData['eventId'] as String?;
      
      if (eventId != null) {
        DocumentSnapshot? eventDoc = _allEvents[eventId];
        
        // If event not in loaded events, fetch it
        if (eventDoc == null) {
          try {
            final eventSnapshot = await FirebaseFirestore.instance
                .collection('events')
                .doc(eventId)
                .get();
            
            if (eventSnapshot.exists) {
              eventDoc = eventSnapshot;
              final eventData = eventDoc.data() as Map<String, dynamic>;
              final date = eventData['date'] as Timestamp?;
              
              if (date != null) {
                _allEvents[eventId] = eventDoc;
                final eventDate = date.toDate();
                final dateKey = DateTime(eventDate.year, eventDate.month, eventDate.day);
                
                if (!_eventsMap.containsKey(dateKey)) {
                  _eventsMap[dateKey] = [];
                }
                // Check if event is already in the list to avoid duplicates
                final existingIndex = _eventsMap[dateKey]!.indexWhere(
                  (e) => e.id == eventId,
                );
                if (existingIndex == -1) {
                  _eventsMap[dateKey]!.add(eventDoc);
                }
              }
            }
          } catch (e) {
            continue;
          }
        }
        
        if (eventDoc != null) {
          final eventData = eventDoc.data() as Map<String, dynamic>;
          final date = eventData['date'] as Timestamp?;
          
          if (date != null) {
            final eventDate = date.toDate();
            final dateKey = DateTime(eventDate.year, eventDate.month, eventDate.day);
            
            if (!registeredEventsMap.containsKey(dateKey)) {
              registeredEventsMap[dateKey] = [];
            }
            // Check if event is already in the list to avoid duplicates
            final existingIndex = registeredEventsMap[dateKey]!.indexWhere(
              (e) => e.id == eventId,
            );
            if (existingIndex == -1) {
              registeredEventsMap[dateKey]!.add(eventDoc);
            }
            userRegistrations[eventId] = regDoc;
          }
        }
      }
    }

    setState(() {
      _registeredEventsMap = registeredEventsMap;
      _userRegistrations = userRegistrations;
    });
  }

  List<DocumentSnapshot> _getEventsForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _eventsMap[dateKey] ?? [];
  }

  bool _isEventDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _eventsMap.containsKey(dateKey);
  }

  bool _isRegisteredDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _registeredEventsMap.containsKey(dateKey);
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });

    _selectedEvents.value = _getEventsForDay(selectedDay);
    
    // Always show details for the selected day (even if clicking the same day again)
    final events = _getEventsForDay(selectedDay);
    _showEventDetails(selectedDay, events);
  }

  void _showEventDetails(DateTime date, List<DocumentSnapshot> events) {
    // If no events, show empty state
    if (events.isEmpty) {
      _showEmptyDateDialog(date);
      return;
    }
    
    // If multiple events, show a list to choose from
    if (events.length > 1) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _buildEventListSheet(date, events),
      );
    } else {
      // Single event, show directly
      _showEventDetailDialog(events.first);
    }
  }

  void _showEmptyDateDialog(DateTime date) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dayNumber = date.day;
    final monthName = DateFormat('MMMM').format(date);
    final isToday = isSameDay(date, DateTime.now());
    final isPast = date.isBefore(DateTime.now().subtract(const Duration(days: 1)));
    
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF1E1E1E),
                      const Color(0xFF2A2A2A),
                    ]
                  : [
                      Colors.white,
                      const Color(0xFFF8F9FA),
                    ],
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative background elements
              Positioned(
                top: -50,
                right: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF6C5CE7).withOpacity(0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF00D2D3).withOpacity(0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              
              // Content
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Close button
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              size: 20,
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Large date display
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF6C5CE7),
                              const Color(0xFFA29BFE),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6C5CE7).withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Day number
                            Text(
                              '$dayNumber',
                              style: const TextStyle(
                                fontSize: 72,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Month and year
                            Text(
                              monthName.toUpperCase(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.9),
                                letterSpacing: 2,
                              ),
                            ),
                            Text(
                              '${date.year}',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (isToday) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle, size: 8, color: Colors.white),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'TODAY',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Empty state illustration
                      Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF6C5CE7).withOpacity(0.1),
                              const Color(0xFF00D2D3).withOpacity(0.1),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              isPast ? Icons.event_busy : Icons.event_available,
                              size: 80,
                              color: const Color(0xFF6C5CE7).withOpacity(0.3),
                            ),
                            Positioned(
                              bottom: 20,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6C5CE7).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.add,
                                  color: const Color(0xFF6C5CE7),
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Message
                      Text(
                        isPast 
                            ? 'No events on this date'
                            : 'No events scheduled yet',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isPast
                            ? 'This date has already passed'
                            : 'Would you like to create an event for this date?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          height: 1.5,
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Action button
                      if (!isPast)
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6C5CE7).withOpacity(0.4),
                                blurRadius: 15,
                                spreadRadius: 2,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CreateEventScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add_circle_outline, size: 24),
                            label: const Text(
                              'Create Event for This Date',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      
                      if (isPast)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Past dates cannot have new events',
                                style: TextStyle(
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventListSheet(DateTime date, List<DocumentSnapshot> events) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Events on ${DateFormat('MMM dd, yyyy').format(date)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return _buildEventListItem(event);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventListItem(DocumentSnapshot event) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final eventData = event.data() as Map<String, dynamic>;
    final isRegistered = _userRegistrations.containsKey(event.id);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRegistered 
              ? Colors.green.withOpacity(0.5)
              : const Color(0xFF6C5CE7).withOpacity(0.3),
          width: 2,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isRegistered
                  ? [Colors.green.shade400, Colors.green.shade600]
                  : [const Color(0xFF6C5CE7), const Color(0xFFA29BFE)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isRegistered ? Icons.check_circle : Icons.event,
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Text(
          eventData['title'] ?? 'Untitled Event',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (eventData['time'] != null)
              Text(
                'Time: ${eventData['time']}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            if (isRegistered)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Registered',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
        onTap: () {
          Navigator.pop(context);
          _showEventDetailDialog(event);
        },
      ),
    );
  }

  void _showEventDetailDialog(DocumentSnapshot event) {
    final isRegistered = _userRegistrations.containsKey(event.id);
    final registration = isRegistered ? _userRegistrations[event.id] : null;
    
    showDialog(
      context: context,
      builder: (context) => _buildEventDetailDialog(event, isRegistered, registration),
    );
  }

  Widget _buildEventDetailDialog(
    DocumentSnapshot event,
    bool isRegistered,
    DocumentSnapshot? registration,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final eventData = event.data() as Map<String, dynamic>;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isRegistered
                        ? [Colors.green.shade400, Colors.green.shade600]
                        : [const Color(0xFF6C5CE7), const Color(0xFFA29BFE)],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            eventData['title'] ?? 'Event',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (isRegistered)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'Registered',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Event Details
                    _buildDetailRow(Icons.calendar_today, 'Date', 
                      eventData['date'] != null
                          ? DateFormat('MMM dd, yyyy').format(
                              (eventData['date'] as Timestamp).toDate())
                          : 'TBA'),
                    const SizedBox(height: 12),
                    if (eventData['time'] != null)
                      _buildDetailRow(Icons.access_time, 'Time', eventData['time']),
                    const SizedBox(height: 12),
                    if (eventData['location'] != null)
                      _buildDetailRow(Icons.location_on, 'Location', eventData['location']),
                    const SizedBox(height: 12),
                    if (eventData['description'] != null)
                      _buildDetailRow(Icons.description, 'Description', eventData['description']),
                    
                    const SizedBox(height: 24),
                    
                    // Action Buttons
                    if (isRegistered) ...[
                      // View Ticket Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EventRegistrationScreen(
                                  eventId: event.id,
                                  eventData: eventData,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.confirmation_number),
                          label: const Text('View Ticket'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C5CE7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Set Reminder Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context); // Close event details dialog first
                            
                            // Navigate to reminder setting screen
                            final date = eventData['date'] as Timestamp?;
                            final eventTime = eventData['time'] as String?;
                            
                            if (date != null) {
                              final eventDateTime = date.toDate();
                              
                              // Parse event time if available
                              TimeOfDay? eventTimeOfDay;
                              if (eventTime != null) {
                                try {
                                  final parts = eventTime.split(':');
                                  if (parts.length == 2) {
                                    eventTimeOfDay = TimeOfDay(
                                      hour: int.parse(parts[0]),
                                      minute: int.parse(parts[1]),
                                    );
                                  }
                                } catch (e) {
                                  // If time parsing fails, use default
                                }
                              }
                              
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ReminderSettingScreen(
                                    event: event,
                                    eventData: eventData,
                                    eventDateTime: eventDateTime,
                                    eventTimeOfDay: eventTimeOfDay,
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.notifications),
                          label: const Text('Set Reminder'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6C5CE7),
                            side: const BorderSide(color: Color(0xFF6C5CE7)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Register Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EventRegistrationScreen(
                                  eventId: event.id,
                                  eventData: eventData,
                                ),
                              ),
                          ).then((_) {
                            // Refresh registrations after registration
                            _refreshRegistrations();
                          });
                          },
                          icon: const Icon(Icons.how_to_reg),
                          label: const Text('Register for Event'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6C5CE7)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = _auth.currentUser;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Calendar'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: user == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Please log in to view calendar',
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: _registrationService.getUserRegistrations(),
              builder: (context, registrationSnapshot) {
                // Update registrations when stream updates (only once per snapshot)
                if (registrationSnapshot.hasData && registrationSnapshot.data != null) {
                  // Use a Future.microtask to avoid calling setState during build
                  Future.microtask(() {
                    if (mounted) {
                      _updateRegistrationsFromSnapshot(registrationSnapshot.data!);
                    }
                  });
                }
                
                return RefreshIndicator(
                  onRefresh: () async {
                    await _loadEventsAndRegistrations();
                  },
                  color: const Color(0xFF6C5CE7),
                  backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        // Calendar
                        Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              eventLoader: _getEventsForDay,
              startingDayOfWeek: StartingDayOfWeek.monday,
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                weekendTextStyle: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                defaultTextStyle: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
                selectedDecoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7),
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                markerDecoration: const BoxDecoration(
                  color: Color(0xFF6C5CE7),
                  shape: BoxShape.circle,
                ),
                // Highlight registered dates in green
                selectedTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonShowsNext: false,
                formatButtonDecoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                formatButtonTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                titleTextStyle: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
                weekendStyle: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  if (events.isEmpty) return null;
                  
                  final isRegistered = _isRegisteredDay(date);
                  
                  return Positioned(
                    bottom: 1,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isRegistered ? Colors.green : const Color(0xFF6C5CE7),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
                selectedBuilder: (context, date, events) {
                  final isRegistered = _isRegisteredDay(date);
                  
                  return Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isRegistered ? Colors.green : const Color(0xFF6C5CE7),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
                todayBuilder: (context, date, events) {
                  final isRegistered = _isRegisteredDay(date);
                  final hasEvents = _isEventDay(date);
                  
                  return Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isRegistered 
                          ? Colors.green.withOpacity(0.3)
                          : hasEvents
                              ? const Color(0xFF6C5CE7).withOpacity(0.3)
                              : Colors.grey.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isRegistered 
                            ? Colors.green
                            : hasEvents
                                ? const Color(0xFF6C5CE7)
                                : Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          color: isRegistered 
                              ? Colors.green.shade700
                              : hasEvents
                                  ? const Color(0xFF6C5CE7)
                                  : (Theme.of(context).brightness == Brightness.dark 
                                      ? Colors.white 
                                      : Colors.black87),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
              onDaySelected: _onDaySelected,
              onFormatChanged: (format) {
                if (_calendarFormat != format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                }
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
            ),
          ),
          
          // Legend
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(const Color(0xFF6C5CE7), 'Events'),
                const SizedBox(width: 24),
                _buildLegendItem(Colors.green, 'Registered'),
              ],
            ),
          ),
                        const SizedBox(height: 20), // Extra space for pull-to-refresh
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey.shade400
                : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}


