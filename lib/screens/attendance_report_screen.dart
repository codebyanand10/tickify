import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../services/certificate_service.dart';
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
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;
  bool _showAllRegistrations = false; // Toggle between all and marked attendance

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<Map<String, dynamic>> records;
      if (_showAllRegistrations) {
        records = await _registrationService.getRegistrationRecords(widget.eventId);
      } else {
        records = await _registrationService.getAttendanceRecords(widget.eventId);
      }
      
      setState(() {
        _records = records;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _exportToPDF() async {
    final pdf = pw.Document();
    final title = _showAllRegistrations ? 'REGISTRATION LIST' : 'ATTENDANCE REPORT';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        title,
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        widget.eventData['title'] ?? 'Event',
                        style: pw.TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Generated on: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}'),
                      pw.Text('Total Count: ${_records.length}'),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            
            // Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _buildPDFTableCell('S.No', isHeader: true),
                    _buildPDFTableCell('Name', isHeader: true),
                    _buildPDFTableCell('Reg. Type', isHeader: true),
                    _buildPDFTableCell('College', isHeader: true),
                    _buildPDFTableCell('Dept', isHeader: true),
                    _buildPDFTableCell('Sem', isHeader: true),
                    if (_showAllRegistrations) _buildPDFTableCell('Status', isHeader: true),
                    if (!_showAllRegistrations) _buildPDFTableCell('Checked In At', isHeader: true),
                  ],
                ),
                // Data rows
                ..._records.asMap().entries.map((entry) {
                  final index = entry.key + 1;
                  final record = entry.value;
                  return pw.TableRow(
                    children: [
                      _buildPDFTableCell(index.toString()),
                      _buildPDFTableCell(record['name'] ?? 'N/A'),
                      _buildPDFTableCell(record['isTeamMember'] == true ? "Team Member" : "Individual"),
                      _buildPDFTableCell(record['collegeName'] ?? 'N/A'),
                      _buildPDFTableCell(record['department'] ?? 'N/A'),
                      _buildPDFTableCell(record['semester'] ?? 'N/A'),
                      if (_showAllRegistrations) 
                        _buildPDFTableCell(record['attendanceMarked'] == true ? "PRESENT" : "ABSENT"),
                      if (!_showAllRegistrations)
                        _buildPDFTableCell(record['attendanceMarkedAt'] != null 
                          ? DateFormat('hh:mm a').format((record['attendanceMarkedAt'] as Timestamp).toDate()) 
                          : 'N/A'),
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
      name: '${widget.eventData['title']}_${_showAllRegistrations ? 'Registrations' : 'Attendance'}.pdf',
    );
  }

  pw.Widget _buildPDFTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: isHeader ? 10 : 9,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF7A002B);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(_showAllRegistrations ? "Registration Report" : "Attendance Report"),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          if (_records.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _exportToPDF,
              tooltip: 'Export to PDF',
            ),
        ],
      ),
      body: Column(
        children: [
          // Toggle & Stats Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              border: Border(
                bottom: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          if (!_showAllRegistrations) return;
                          setState(() => _showAllRegistrations = false);
                          _loadRecords();
                        },
                        child: _buildToggleItem(
                          "Attendance", 
                          Icons.how_to_reg, 
                          !_showAllRegistrations, 
                          primaryColor,
                          isDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          if (_showAllRegistrations) return;
                          setState(() => _showAllRegistrations = true);
                          _loadRecords();
                        },
                        child: _buildToggleItem(
                          "Registrations", 
                          Icons.people_outline, 
                          _showAllRegistrations, 
                          primaryColor,
                          isDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, primaryColor.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.eventData['title'] ?? 'Event',
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _showAllRegistrations ? 'Total Enrolled: ${_records.length}' : 'Attended: ${_records.length}',
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      if (_records.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                             "${_records.length} Users",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // List content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                    ? _buildEmptyState(isDark)
                    : _buildTable(isDark, primaryColor),
          ),
          if (widget.eventData['certification'] == true)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 54,
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Generating certificates...')),
                      );
                      try {
                        await CertificateService().generateCertificatesForEvent(
                          eventId: widget.eventId,
                          eventData: widget.eventData,
                          certificateSettings: {
                            'signatureName': (widget.eventData['coordinators'] != null && (widget.eventData['coordinators'] as List).isNotEmpty)
                                ? (widget.eventData['coordinators'] as List)[0]['name']
                                : 'Organizer',
                          },
                        );
                        await CertificateService().publishCertificates(widget.eventId);
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String label, IconData icon, bool isActive, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.1) : (isDark ? Colors.grey.shade900 : Colors.grey.shade100),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? color : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
          width: 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: isActive ? color : Colors.grey),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isActive ? color : Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _showAllRegistrations ? "No registrations yet" : "No one checked in yet",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _showAllRegistrations 
              ? "Share the event to get registrations" 
              : "Scan tickets at the venue entry",
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(bool isDark, Color primaryColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
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
          child: DataTable(
            horizontalMargin: 20,
            columnSpacing: 30,
            headingRowColor: MaterialStateProperty.all(primaryColor.withOpacity(0.1)),
            dataRowHeight: 60,
            columns: [
              const DataColumn(label: Text('S.No', style: TextStyle(fontWeight: FontWeight.bold))),
              const DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
              const DataColumn(label: Text('College', style: TextStyle(fontWeight: FontWeight.bold))),
              const DataColumn(label: Text('Dept', style: TextStyle(fontWeight: FontWeight.bold))),
              if (_showAllRegistrations)
                const DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
              if (!_showAllRegistrations)
                const DataColumn(label: Text('Time', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _records.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final record = entry.value;
              return DataRow(
                cells: [
                  DataCell(Text(index.toString())),
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(record['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          record['isTeamMember'] == true ? "Team" : "Indiv",
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  DataCell(Text(record['collegeName'] ?? 'N/A')),
                  DataCell(Text(record['department'] ?? 'N/A')),
                  if (_showAllRegistrations)
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (record['attendanceMarked'] == true ? Colors.green : Colors.orange).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: (record['attendanceMarked'] == true ? Colors.green : Colors.orange).withOpacity(0.5)),
                        ),
                        child: Text(
                          record['attendanceMarked'] == true ? "PRESENT" : "NOT CHECKED IN",
                          style: TextStyle(
                            fontSize: 10, 
                            fontWeight: FontWeight.bold,
                            color: record['attendanceMarked'] == true ? Colors.green : Colors.orange,
                          ),
                        ),
                      ),
                    ),
                  if (!_showAllRegistrations)
                    DataCell(Text(
                      record['attendanceMarkedAt'] != null 
                        ? DateFormat('hh:mm a').format((record['attendanceMarkedAt'] as Timestamp).toDate()) 
                        : 'N/A'
                    )),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
