import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/event_service.dart';
import 'package:intl/intl.dart';
import 'event_details_screen.dart';

class AdminApprovalScreen extends StatefulWidget {
  const AdminApprovalScreen({super.key});

  @override
  State<AdminApprovalScreen> createState() => _AdminApprovalScreenState();
}

class _AdminApprovalScreenState extends State<AdminApprovalScreen> {
  final EventService _eventService = EventService();
  String _selectedFilter = 'pending'; // pending, published, rejected

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF0F2F5),
      body: CustomScrollView(
        slivers: [
          // Custom Admin AppBar
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFF3E0014),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                "Admin Control",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      const Color(0xFF7A002B),
                      isDark ? const Color(0xFF1A1A1A) : const Color(0xFF3E0014),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -30,
                      top: -20,
                      child: Icon(
                        Icons.admin_panel_settings,
                        size: 200,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 80, 20, 0),
                      child: Row(
                        children: [
                          _buildHeaderStat("TOTAL", "event_count", Icons.event),
                          const SizedBox(width: 12),
                          _buildHeaderStat("PENDING", "pending_count", Icons.pending_actions, color: Colors.orangeAccent),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Filters and Search Placeholder
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Moderate Requests",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip("Pending", "pending", Icons.timer_outlined),
                        const SizedBox(width: 8),
                        _buildFilterChip("Approved", "published", Icons.check_circle_outline),
                        const SizedBox(width: 8),
                        _buildFilterChip("Rejected", "rejected", Icons.cancel_outlined),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Events List
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('events')
                .where('status', isEqualTo: _selectedFilter)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 60, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            "Database Error",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _selectedFilter == 'pending' ? Icons.done_all_rounded : Icons.search_off_rounded,
                          size: 80, 
                          color: Colors.grey.withOpacity(0.5)
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedFilter == 'pending' ? "All caught up!" : "No events found",
                          style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final events = snapshot.data!.docs;

              return SliverPadding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 40),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final event = events[index];
                      final eventData = event.data() as Map<String, dynamic>;
                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EventDetailsScreen(
                                event: event,
                              ),
                            ),
                          );
                        },
                        child: _buildManagementCard(event.id, eventData, isDark),
                      );
                    },
                    childCount: events.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String label, String statKey, IconData icon, {Color? color}) {
    return FutureBuilder<QuerySnapshot>(
      future: statKey == "event_count" 
          ? FirebaseFirestore.instance.collection('events').get()
          : FirebaseFirestore.instance.collection('events').where('status', isEqualTo: 'pending').get(),
      builder: (context, snapshot) {
        String count = snapshot.hasData ? snapshot.data!.docs.length.toString() : "-";
        return Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 24, color: color ?? Colors.white.withOpacity(0.8)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(count, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis),
                      Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.6)), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    bool isSelected = _selectedFilter == value;
    final cs = Theme.of(context).colorScheme;
    
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _selectedFilter = value);
      },
      selectedColor: const Color(0xFF7A002B),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey.shade700,
        fontWeight: FontWeight.bold,
      ),
      backgroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: isSelected ? 4 : 0,
    );
  }

  Widget _buildManagementCard(String eventId, Map<String, dynamic> eventData, bool isDark) {
    final date = (eventData['date'] as Timestamp?)?.toDate();
    final dateStr = date != null ? DateFormat('MMM dd, yyyy').format(date) : 'TBA';
    final posterUrl = eventData['posterUrl'] as String?;
    final category = eventData['category'] as String? ?? 'Other';

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Container(
                  height: 140,
                  width: double.infinity,
                  color: Colors.grey.shade200,
                  child: posterUrl != null && posterUrl.isNotEmpty
                      ? Image.network(posterUrl, fit: BoxFit.cover)
                      : const Icon(Icons.broken_image_outlined, size: 40, color: Colors.grey),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    category.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eventData['title'] ?? 'Untitled Event',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(dateStr, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 16),
                    Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Expanded(child: Text(eventData['location'] ?? 'Online', style: TextStyle(fontSize: 13, color: Colors.grey.shade600, overflow: TextOverflow.ellipsis))),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Host Summary
                FutureBuilder<DocumentSnapshot>(
                   future: FirebaseFirestore.instance.collection('users').doc(eventData['createdBy']).get(),
                   builder: (context, snapshot) {
                      final hostData = (snapshot.hasData && snapshot.data!.exists) ? snapshot.data!.data() as Map<String, dynamic> : null;
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: const Color(0xFF7A002B).withOpacity(0.2),
                              child: Text((hostData?['name']?.substring(0, 1) ?? "?").toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF7A002B))),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text("Creator: ${hostData?['name'] ?? 'Unknown Member'}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFF7A002B).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                              child: Text((hostData?['role'] ?? 'User').toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF7A002B))),
                            ),
                          ],
                        ),
                      );
                   },
                ),

                const SizedBox(height: 20),
                
                if (_selectedFilter == 'pending')
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _handleAction(context, eventId, 'rejected'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text("Reject", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handleAction(context, eventId, 'published'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7A002B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: const Text("Approve Event", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedFilter == 'published' ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _selectedFilter == 'published' ? "PUBLISHED" : "REJECTED",
                        style: TextStyle(
                          color: _selectedFilter == 'published' ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          fontSize: 12
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleAction(BuildContext context, String eventId, String status) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      
      await _eventService.updateEventStatus(eventId, status);
      
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'published' ? "Event approved and published!" : "Event submission rejected."),
            backgroundColor: status == 'published' ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }
}
