import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';

class ReminderSettingScreen extends StatefulWidget {
  final DocumentSnapshot event;
  final Map<String, dynamic> eventData;
  final DateTime eventDateTime;
  final TimeOfDay? eventTimeOfDay;

  const ReminderSettingScreen({
    super.key,
    required this.event,
    required this.eventData,
    required this.eventDateTime,
    this.eventTimeOfDay,
  });

  @override
  State<ReminderSettingScreen> createState() => _ReminderSettingScreenState();
}

class _ReminderSettingScreenState extends State<ReminderSettingScreen> {
  TimeOfDay? _selectedTime;
  String _reminderOption = 'custom'; // 'custom', '15min', '30min', '1hour', '1day'
  String _reminderType = 'notification'; // 'notification', 'alarm'

  @override
  void initState() {
    super.initState();
    // Set default time based on event time or current time
    if (widget.eventTimeOfDay != null) {
      // Default to 1 hour before event
      final eventTime = widget.eventTimeOfDay!;
      final reminderHour = eventTime.hour > 0 ? eventTime.hour - 1 : 23;
      final reminderMinute = eventTime.minute;
      _selectedTime = TimeOfDay(hour: reminderHour, minute: reminderMinute);
    } else {
      _selectedTime = TimeOfDay.now();
    }
  }

  void _calculatePresetTime(String option) {
    if (widget.eventTimeOfDay == null) return;

    final eventTime = widget.eventTimeOfDay!;
    final eventDateTime = DateTime(
      widget.eventDateTime.year,
      widget.eventDateTime.month,
      widget.eventDateTime.day,
      eventTime.hour,
      eventTime.minute,
    );

    DateTime reminderDateTime;

    switch (option) {
      case '15min':
        reminderDateTime = eventDateTime.subtract(const Duration(minutes: 15));
        break;
      case '30min':
        reminderDateTime = eventDateTime.subtract(const Duration(minutes: 30));
        break;
      case '1hour':
        reminderDateTime = eventDateTime.subtract(const Duration(hours: 1));
        break;
      case '1day':
        reminderDateTime = eventDateTime.subtract(const Duration(days: 1));
        break;
      default:
        return;
    }

    setState(() {
      _selectedTime = TimeOfDay(
        hour: reminderDateTime.hour,
        minute: reminderDateTime.minute,
      );
      _reminderOption = option;
    });
  }

  Future<void> _setReminder() async {
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a reminder time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final reminderDateTime = DateTime(
      widget.eventDateTime.year,
      widget.eventDateTime.month,
      widget.eventDateTime.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    // Check if reminder time is in the past
    if (reminderDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reminder time cannot be in the past'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Generate unique notification ID based on event ID and reminder type
      final notificationId = widget.event.id.hashCode + (_reminderType == 'alarm' ? 10000 : 0);

      final notificationService = NotificationService();
      await notificationService.initialize();

      final eventLocation = widget.eventData['location'] as String? ?? '';
      final eventDateStr = DateFormat('MMM dd, yyyy').format(widget.eventDateTime);
      final eventTimeStr = widget.eventData['time'] as String? ?? 'Time TBA';
      final eventTitle = widget.eventData['title'] as String? ?? 'Event';

      final notificationTitle = _reminderType == 'alarm'
          ? '🔔 Event Alarm: $eventTitle'
          : '📅 Event Reminder: $eventTitle';

      final notificationBody = _reminderType == 'alarm'
          ? 'Your event "$eventTitle" is starting soon!\n$eventDateStr at $eventTimeStr${eventLocation.isNotEmpty ? '\n📍 $eventLocation' : ''}'
          : 'Don\'t forget: "$eventTitle" on $eventDateStr at $eventTimeStr${eventLocation.isNotEmpty ? '\n📍 $eventLocation' : ''}';

      if (_reminderType == 'alarm') {
        await notificationService.scheduleAlarm(
          id: notificationId,
          title: notificationTitle,
          body: notificationBody,
          scheduledDate: reminderDateTime,
          payload: widget.event.id,
        );
      } else {
        await notificationService.scheduleNotification(
          id: notificationId,
          title: notificationTitle,
          body: notificationBody,
          scheduledDate: reminderDateTime,
          payload: widget.event.id,
          isAlarm: false,
        );
      }

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                _reminderType == 'alarm' ? Icons.alarm : Icons.check_circle,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${_reminderType == 'alarm' ? 'Alarm' : 'Reminder'} set for ${DateFormat('MMM dd, yyyy at hh:mm a').format(reminderDateTime)}',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // Navigate back
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to set reminder: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final eventDateStr = DateFormat('EEEE, MMMM dd, yyyy').format(widget.eventDateTime);
    final eventTitle = widget.eventData['title'] as String? ?? 'Event';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Set Reminder'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7A002B), Color(0xFFAC1634)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7A002B).withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.event,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              eventTitle,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              eventDateStr,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Preset options
            if (widget.eventTimeOfDay != null) ...[
              Text(
                'Quick Options',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildPresetButton('15min', '15 min before', isDark),
                  _buildPresetButton('30min', '30 min before', isDark),
                  _buildPresetButton('1hour', '1 hour before', isDark),
                  _buildPresetButton('1day', '1 day before', isDark),
                ],
              ),
              const SizedBox(height: 32),
            ],

            // Custom time picker
            Text(
              'Custom Time',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF7A002B).withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    _selectedTime?.format(context) ?? 'Select time',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime ?? TimeOfDay.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: const Color(0xFF7A002B),
                                  onPrimary: Colors.white,
                                  onSurface: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedTime = picked;
                            _reminderOption = 'custom';
                          });
                        }
                      },
                      icon: const Icon(Icons.access_time, size: 20),
                      label: const Text('Choose Time'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF7A002B),
                        side: const BorderSide(color: Color(0xFF7A002B)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Reminder Type Selection
            Text(
              'Reminder Type',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildReminderTypeButton(
                    'notification',
                    'Notification',
                    Icons.notifications,
                    isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildReminderTypeButton(
                    'alarm',
                    'Alarm',
                    Icons.alarm,
                    isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),

            // Set reminder button
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7A002B), Color(0xFFAC1634)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7A002B).withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _setReminder,
                icon: Icon(
                  _reminderType == 'alarm' ? Icons.alarm : Icons.check_circle,
                  size: 24,
                ),
                label: Text(
                  _reminderType == 'alarm' ? 'Set Alarm' : 'Set Reminder',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderTypeButton(
    String type,
    String label,
    IconData icon,
    bool isDark,
  ) {
    final isSelected = _reminderType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _reminderType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF7A002B), Color(0xFFAC1634)],
                )
              : null,
          color: isSelected ? null : (isDark ? const Color(0xFF2A2A2A) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : const Color(0xFF7A002B).withOpacity(0.3),
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF7A002B).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF7A002B),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey.shade300 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetButton(String option, String label, bool isDark) {
    final isSelected = _reminderOption == option;
    return GestureDetector(
      onTap: () => _calculatePresetTime(option),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF7A002B), Color(0xFFAC1634)],
                )
              : null,
          color: isSelected ? null : (isDark ? const Color(0xFF2A2A2A) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : const Color(0xFF7A002B).withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.grey.shade300 : Colors.black87),
          ),
        ),
      ),
    );
  }
}

