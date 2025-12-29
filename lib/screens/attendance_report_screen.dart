import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../services/registration_service.dart';

class AttendanceReportScreen extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> eventData;

  const AttendanceReportScreen({
    super.key,
    required this.eventId,
    required this.eventData,
  });

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  final RegistrationService _registrationService = RegistrationService();
  List<Map<String, dynamic>> _attendanceRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAttendanceRecords();
  }

  Future<void> _loadAttendanceRecords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final records = await _registrationService.getAttendanceRecords(widget.eventId);
      setState(() {
        _attendanceRecords = records;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading attendance: $e')),
        );
      }
    }
  }

  Future<void> _exportToPDF() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ATTENDANCE REPORT',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    widget.eventData['title'] ?? 'Event',
                    style: pw.TextStyle(fontSize: 16),
                  ),
                  pw.Text(
                    'Date: ${widget.eventData['date'] != null ? DateFormat('dd/MM/yyyy').format((widget.eventData['date'] as Timestamp).toDate()) : 'TBA'}',
                    style: pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Total Attendance: ${_attendanceRecords.length}',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 20),
            // Table
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _buildPDFTableCell('S.No', isHeader: true),
                    _buildPDFTableCell('Name', isHeader: true),
                    _buildPDFTableCell('College Name', isHeader: true),
                    _buildPDFTableCell('Department', isHeader: true),
                    _buildPDFTableCell('Semester', isHeader: true),
                  ],
                ),
                // Data rows
                ..._attendanceRecords.asMap().entries.map((entry) {
                  final index = entry.key + 1;
                  final record = entry.value;
                  return pw.TableRow(
                    children: [
                      _buildPDFTableCell(index.toString()),
                      _buildPDFTableCell(record['name'] ?? 'N/A'),
                      _buildPDFTableCell(record['collegeName'] ?? 'N/A'),
                      _buildPDFTableCell(record['department'] ?? 'N/A'),
                      _buildPDFTableCell(record['semester'] ?? 'N/A'),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  pw.Widget _buildPDFTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: isHeader ? 12 : 10,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Attendance Report"),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        actions: [
          if (_attendanceRecords.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _exportToPDF,
              tooltip: 'Export to PDF',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _attendanceRecords.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 24),
                      Text(
                        "No attendance records",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Scan tickets to mark attendance",
                        style: TextStyle(
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Header Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.eventData['title'] ?? 'Event',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Total Attendance: ${_attendanceRecords.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Table Container
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
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
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Table(
                                border: TableBorder(
                                  top: BorderSide(
                                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                                    width: 2,
                                  ),
                                  bottom: BorderSide(
                                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                                    width: 2,
                                  ),
                                  left: BorderSide(
                                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                                    width: 1,
                                  ),
                                  right: BorderSide(
                                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                                    width: 1,
                                  ),
                                  horizontalInside: BorderSide(
                                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                                    width: 1,
                                  ),
                                  verticalInside: BorderSide(
                                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                columnWidths: const {
                                  0: FixedColumnWidth(70),  // S.No
                                  1: FixedColumnWidth(150), // Name
                                  2: FixedColumnWidth(180), // College Name
                                  3: FixedColumnWidth(120), // Department
                                  4: FixedColumnWidth(100), // Semester
                                },
                                children: [
                                  // Header row
                                  TableRow(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isDark
                                            ? [Colors.grey.shade800, Colors.grey.shade700]
                                            : [const Color(0xFF6C5CE7), const Color(0xFFA29BFE)],
                                      ),
                                    ),
                                    children: [
                                      _buildTableCell('S.No', isHeader: true, isDark: isDark),
                                      _buildTableCell('Name', isHeader: true, isDark: isDark),
                                      _buildTableCell('College Name', isHeader: true, isDark: isDark),
                                      _buildTableCell('Department', isHeader: true, isDark: isDark),
                                      _buildTableCell('Semester', isHeader: true, isDark: isDark),
                                    ],
                                  ),
                                  // Data rows with alternating colors
                                  ..._attendanceRecords.asMap().entries.map((entry) {
                                    final index = entry.key + 1;
                                    final record = entry.value;
                                    final isEven = index % 2 == 0;
                                    return TableRow(
                                      decoration: BoxDecoration(
                                        color: isEven
                                            ? (isDark
                                                ? Colors.grey.shade900.withOpacity(0.5)
                                                : Colors.grey.shade50)
                                            : Colors.transparent,
                                      ),
                                      children: [
                                        _buildTableCell(
                                          index.toString(),
                                          isDark: isDark,
                                          isEven: isEven,
                                        ),
                                        _buildTableCell(
                                          record['name'] ?? 'N/A',
                                          isDark: isDark,
                                          isEven: isEven,
                                        ),
                                        _buildTableCell(
                                          record['collegeName'] ?? 'N/A',
                                          isDark: isDark,
                                          isEven: isEven,
                                        ),
                                        _buildTableCell(
                                          record['department'] ?? 'N/A',
                                          isDark: isDark,
                                          isEven: isEven,
                                        ),
                                        _buildTableCell(
                                          record['semester'] ?? 'N/A',
                                          isDark: isDark,
                                          isEven: isEven,
                                        ),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    required bool isDark,
    bool isEven = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.w500,
          fontSize: isHeader ? 15 : 14,
          color: isHeader
              ? Colors.white
              : (isDark
                  ? Colors.grey.shade200
                  : Colors.black87),
          letterSpacing: isHeader ? 0.5 : 0,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

