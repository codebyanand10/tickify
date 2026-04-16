import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'event_registration_screen.dart';
import 'attendance_report_screen.dart';
import 'qr_scanner_screen.dart';
import 'certificate_template_editor_screen.dart';
import 'template_selection_screen.dart';
import '../services/event_service.dart';
import '../services/registration_service.dart';
import '../services/certificate_service.dart';
import 'payment_verification_screen.dart';
import 'tickets_screen.dart';

class EventDetailsScreen extends StatefulWidget {
  final DocumentSnapshot event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  Future<String>? _userRoleFuture;

  // Map category keys to display labels
  static const Map<String, String> categoryLabels = {
    'workshop': 'Workshop',
    'ideathon': 'Ideathon',
    'hackathon': 'Hackathon',
    'cultural': 'Cultural Event',
    'seminar': 'Seminar',
    'tournament': 'Tournament',
  };

  // Category colors
  static const Map<String, Color> categoryColors = {
    'workshop': Color(0xFF7A002B), // Burgundy
    'ideathon': Color(0xFFE77291), // Deep Blush
    'hackathon': Color(0xFFAC1634), // Cardinal Red
    'cultural': Color(0xFF5B002C), // Tyrian Purple
    'seminar': Color(0xFF3E0014), // Rustic Red
    'tournament': Color(0xFF900021), // Crimson Red
  };

  Map<String, dynamic>? _userData;
  bool _userDataLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _userDataLoaded = true);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (mounted) {
        setState(() {
          if (doc.exists) {
            _userData = doc.data();
          }
          _userDataLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _userDataLoaded = true);
    }
  }

  void _showDeleteConfirmation() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final eventTitle = _safeGet('title') ?? 'Event';
    final eventId = widget.event.id;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          'Delete Event',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "$eventTitle"?\n\nThis action cannot be undone. All registered users will be notified about the cancellation.',
          style: TextStyle(
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close confirmation dialog
              
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Deleting event and notifying users...'),
                      ],
                    ),
                  ),
                ),
              );

              try {
                final eventService = EventService();
                await eventService.deleteEvent(eventId);
                
                if (mounted) {
                  // Close loading dialog first
                  Navigator.pop(context);
                  
                  // Wait a tiny bit to ensure the dialog is fully closed
                  await Future.delayed(const Duration(milliseconds: 100));
                  
                  // Close the event details screen and return to events screen
                  if (mounted) {
                    Navigator.pop(context);
                  }
                  
                  // Show success message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text('Event deleted successfully.'),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  // Close loading dialog
                  Navigator.pop(context);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text('Error: ${e.toString()}'),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String getCategoryLabel(String? categoryKey) {
    if (categoryKey == null) return 'Unknown';
    return categoryLabels[categoryKey] ?? categoryKey;
  }

  Color getCategoryColor(String? categoryKey) {
    if (categoryKey == null) return const Color(0xFF7A002B);
    return categoryColors[categoryKey] ?? const Color(0xFF7A002B);
  }

  dynamic _safeGet(String field) {
    try {
      final data = widget.event.data() as Map<String, dynamic>?;
      if (data == null) return null;
      return data[field];
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final category = _safeGet('category') as String?;
    final date = _safeGet('date') as Timestamp?;
    final time = _safeGet('time') as String?;
    final coordinators = _safeGet('coordinators') as List?;
    final status = _safeGet('status')?.toString() ?? 'published';
    final categoryColor = getCategoryColor(category);

    final posterUrl = _safeGet('posterUrl') as String?;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // Hero Header with Banner
          SliverAppBar(
            expandedHeight: (posterUrl != null && posterUrl.isNotEmpty) ? 300 : 200,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: categoryColor,
            flexibleSpace: FlexibleSpaceBar(
              background: (posterUrl != null && posterUrl.isNotEmpty)
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          posterUrl,
                          fit: BoxFit.cover,
                          cacheWidth: 800, // Pre-size for memory efficiency
                          errorBuilder: (context, error, stackTrace) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  categoryColor,
                                  categoryColor.withOpacity(0.7),
                                ],
                              ),
                            ),
                            child: const Center(
                              child: Icon(Icons.image_not_supported, color: Colors.white, size: 48),
                            ),
                          ),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    categoryColor,
                                    categoryColor.withOpacity(0.7),
                                  ],
                                ),
                              ),
                              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                            );
                          },
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.5),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            categoryColor,
                            categoryColor.withOpacity(0.7),
                          ],
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Decorative circles
                          Positioned(
                            top: -50,
                            right: -50,
                            child: Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -30,
                            left: -30,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                          ),
                          // Content
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.event,
                                    size: 48,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  getCategoryLabel(category),
                                  style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Event Title
                    Text(
                      _safeGet('title') ?? 'Untitled Event',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category & Type Chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildChip(
                          getCategoryLabel(category),
                          categoryColor,
                          Icons.label,
                        ),
                        _buildChip(
                          _safeGet('collegeType')?.toString() ?? 'Intra College',
                          Colors.grey.shade600,
                          Icons.school,
                        ),
                        if (_safeGet('isTeamEvent') == true)
                          _buildChip(
                            'Team Event',
                            const Color(0xFF7A002B),
                            Icons.group,
                          ),
                        if (status != 'published')
                          _buildChip(
                            status.toUpperCase(),
                            status == 'rejected' ? Colors.red : Colors.orange,
                            status == 'rejected' ? Icons.cancel : Icons.hourglass_empty,
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Date, Time, Location Card
                    _buildInfoCard(
                      context,
                      isDark,
                      [
                        if (date != null)
                          _buildInfoItem(
                            Icons.calendar_today,
                            'Date',
                            date.toDate().toString().split(' ')[0],
                            categoryColor,
                            isDark,
                          ),
                        if (time != null && time.isNotEmpty)
                          _buildInfoItem(
                            Icons.access_time,
                            'Time',
                            time,
                            categoryColor,
                            isDark,
                          ),
                        if (_safeGet('location') != null)
                          _buildInfoItem(
                            Icons.location_on,
                            'Location',
                            _safeGet('location')?.toString() ?? 'TBA',
                            categoryColor,
                            isDark,
                          ),
                        if (_safeGet('hostingCollege') != null)
                          _buildInfoItem(
                            Icons.business,
                            'Hosted By',
                            "${_safeGet('hostingCollege')}${_safeGet('hostingUniversity') != null ? ', ${_safeGet('hostingUniversity')}' : ''}",
                            categoryColor,
                            isDark,
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Description Card
                    if (_safeGet('description') != null) ...[
                      _buildSectionCard(
                        context,
                        isDark,
                        'Description',
                        Icons.description,
                        categoryColor,
                        Text(
                          _safeGet('description')?.toString() ?? 'No description available',
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Event Details Card
                    _buildSectionCard(
                      context,
                      isDark,
                      'Event details & Audience',
                      Icons.info_outline,
                      categoryColor,
                      Column(
                        children: [
                          _buildDetailRow(
                            Icons.event_seat,
                            'Seats',
                            (_safeGet('limitedSeats') == true && _safeGet('seatCount') != null)
                                ? "${_safeGet('seatCount')} available"
                                : "Unlimited",
                            isDark,
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            Icons.payments,
                            'Registration Fee',
                            (_safeGet('paidEvent') == true && _safeGet('feeAmount') != null)
                                ? "₹ ${_safeGet('feeAmount')}"
                                : "Free",
                            isDark,
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            Icons.verified,
                            'Certificate',
                            (_safeGet('certification') == true) ? "Provided" : "Not provided",
                            isDark,
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            Icons.groups_3_outlined,
                            'Target Audience',
                            _getAudienceText(_safeGet('audience')),
                            isDark,
                          ),
                          if (status != 'published') ...[
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              Icons.history_toggle_off_rounded,
                              'Current Status',
                              status.toUpperCase(),
                              isDark,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Coordinators Card
                    if (coordinators != null && coordinators.isNotEmpty) ...[
                      _buildSectionCard(
                        context,
                        isDark,
                        'Event Coordinators',
                        Icons.contacts,
                        categoryColor,
                        Column(
                          children: coordinators.asMap().entries.map((entry) {
                            final coord = entry.value as Map<String, dynamic>;
                            return Container(
                              margin: EdgeInsets.only(bottom: entry.key < coordinators.length - 1 ? 12 : 0),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: categoryColor.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.person,
                                      color: categoryColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          coord['name'] ?? 'Not provided',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          coord['phone'] ?? 'Not provided',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
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
                      const SizedBox(height: 20),
                    ],

                    // Internal Admin / Creator Info
                    FutureBuilder<String>(
                      future: _userRoleFuture,
                      builder: (context, snapshot) {
                        final role = snapshot.data ?? 'student';
                        final isInternal = role == 'admin' || role == 'organizer';

                        if (!isInternal) return const SizedBox.shrink();

                        return Column(
                          children: [
                            _buildSectionCard(
                              context,
                              isDark,
                              'Internal Details',
                              Icons.admin_panel_settings_outlined,
                              const Color(0xFF7A002B),
                              Column(
                                children: [
                                  if (_safeGet('createdBy') != null)
                                    FutureBuilder<DocumentSnapshot>(
                                      future: FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(_safeGet('createdBy').toString())
                                          .get(),
                                      builder: (context, creatorSnapshot) {
                                        final creator = (creatorSnapshot.hasData && creatorSnapshot.data!.exists)
                                            ? creatorSnapshot.data!.data() as Map<String, dynamic>
                                            : null;
                                        return _buildDetailRow(
                                          Icons.person_outline,
                                          'Organizer',
                                          creator?['name'] ?? 'Unknown Creator',
                                          isDark,
                                        );
                                      },
                                    )
                                  else
                                    _buildDetailRow(
                                      Icons.person_outline,
                                      'Organizer',
                                      'Unknown Creator',
                                      isDark,
                                    ),
                                  const SizedBox(height: 12),
                                  _buildDetailRow(
                                    Icons.link_rounded,
                                    'WhatsApp',
                                    _safeGet('whatsappLink')?.toString() ?? 'None provided',
                                    isDark,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        );
                      },
                    ),

                    // Registration / Status Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: _buildActionSection(context, widget.event, isDark, categoryColor),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, bool isDark, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
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
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context,
    bool isDark,
    String title,
    IconData icon,
    Color color,
    Widget content,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Text(
          "$label: ",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionSection(BuildContext context, DocumentSnapshot event, bool isDark, Color categoryColor) {
    if (!_userDataLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final data = event.data() as Map<String, dynamic>;
    final status = data['status'] ?? 'published';
    final collegeType = data['collegeType'] as String?;
    final hostingCollege = data['hostingCollege'] as String?;
    final userCollege = _userData?['collegeName'] as String?;
    
    bool isRestricted = false;
    // Admins are never restricted
    final userRole = (_userData?['role'] ?? 'student').toString().toLowerCase().trim();
    if (userRole != 'admin' && collegeType == 'Intra College' && hostingCollege != null && hostingCollege.isNotEmpty && userCollege != null) {
       if (hostingCollege.toLowerCase().trim() != userCollege.toLowerCase().trim()) {
         isRestricted = true;
       }
    }

    if (status == 'published') {
      if (isRestricted) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person_rounded, color: Colors.red),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  "Restricted to $hostingCollege students",
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      }

      final isCreator = (_userData != null && data['createdBy'] == FirebaseAuth.instance.currentUser?.uid);
      
      return Column(
        children: [
          StreamBuilder<Map<String, dynamic>?>(
            stream: RegistrationService().checkUserRegistrationStream(event.id),
            builder: (context, snapshot) {
              final registration = snapshot.data;
              final isRegistered = registration != null;

              if (isRegistered) {
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Already Registered!",
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Navigate to Tickets Screen and focus on this ticket
                          // For simplicity, we just go to Tickets Screen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TicketsScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.qr_code, color: Colors.white),
                        label: const Text(
                          "View Your Ticket",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: categoryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Container(
                height: 56,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [categoryColor, categoryColor.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: categoryColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EventRegistrationScreen(
                          eventId: event.id,
                          eventData: data,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "Register for Event",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              );
            },
          ),
          if (isCreator) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF7A002B).withOpacity(0.5)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AttendanceReportScreen(
                        eventId: widget.event.id,
                        eventData: data,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.analytics_outlined, color: Color(0xFF7A002B)),
                label: const Text(
                  "View Registrations & Attendance",
                  style: TextStyle(
                    color: Color(0xFF7A002B),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (data['paidEvent'] == true) ...[
              Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.orange.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PaymentVerificationScreen(
                          eventId: widget.event.id,
                          eventTitle: data['title'] ?? 'Event',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.payments_outlined, color: Colors.orange),
                  label: const Text(
                    "Verify Payments",
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF00D2D3).withOpacity(0.5)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QRScannerScreen(eventId: widget.event.id),
                    ),
                  );
                },
                icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF00D2D3)),
                label: const Text(
                  "Scan Tickets",
                  style: TextStyle(
                    color: Color(0xFF00D2D3),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Generate Certificates?'),
                      content: const Text(
                        'This will generate and publish certificates for ALL registered participants.',
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Generate'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Generating certificates...')),
                      );
                    }
                    try {
                      final certService = CertificateService();
                      await certService.generateCertificatesForEvent(
                        eventId: widget.event.id,
                        eventData: data,
                        certificateSettings: {
                          'signatureName': (data['coordinators'] != null && (data['coordinators'] as List).isNotEmpty)
                              ? (data['coordinators'] as List)[0]['name']
                              : 'Organizer',
                        },
                      );
                      await certService.publishCertificates(widget.event.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Certificates published!'), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  }
                },
                icon: const Icon(Icons.workspace_premium, color: Colors.white),
                label: const Text(
                  "Generate Certificates",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextButton.icon(
                onPressed: _showDeleteConfirmation,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text(
                  "Delete Event",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    }

    // Handlers for non-published states
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (status == 'rejected') {
      statusColor = Colors.red;
      statusLabel = "Event Registration Closed (Rejected)";
      statusIcon = Icons.cancel;
    } else {
      statusColor = Colors.orange;
      statusLabel = "Waiting for Admin Approval";
      statusIcon = Icons.hourglass_empty;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(statusIcon, color: statusColor),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _getAudienceText(dynamic audience) {
    if (audience == null || audience is! Map) return "Everyone";
    final data = audience as Map<String, dynamic>;
    List<String> parts = [];
    if (data['students'] == true) parts.add("Students");
    if (data['outsiders'] == true) parts.add("Outsiders");
    if (data['staff'] == true) parts.add("Staff");
    return parts.isEmpty ? "Invite only" : parts.join(", ");
  }
}
