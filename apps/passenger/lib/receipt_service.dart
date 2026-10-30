import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class RrydReceiptService {
  RrydReceiptService._();

  static String _value(dynamic value, {String fallback = 'Not recorded'}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static String _money(dynamic value) {
    if (value is num) return 'NPR ${value.round()}';
    final parsed = num.tryParse(value?.toString() ?? '');
    return parsed == null ? 'Not recorded' : 'NPR ${parsed.round()}';
  }

  static String _date(dynamic value) {
    if (value == null) return 'Not recorded';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();
    final local = parsed.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  static List<MapEntry<String, String>> _receiptRows(
    Map<String, dynamic> ride,
  ) {
    final fare = ride['final_fare'] ??
        ride['actual_fare'] ??
        ride['fare'] ??
        ride['estimated_fare'];

    return [
      MapEntry('Ride ID', _value(ride['id'])),
      MapEntry('Completed', _date(ride['completed_at'])),
      MapEntry('Pickup', _value(ride['pickup_location'])),
      MapEntry('Destination', _value(ride['destination'])),
      MapEntry('Vehicle', _value(ride['vehicle_type'])),
      MapEntry(
        'Distance',
        ride['distance_km'] == null
            ? 'Not recorded'
            : '${(ride['distance_km'] as num).toStringAsFixed(2)} km',
      ),
      MapEntry('Payment method', _value(ride['payment_method'])),
      MapEntry('Payment status', _value(ride['payment_status'])),
      MapEntry('Final fare', _money(fare)),
    ];
  }

  static Future<Uint8List> buildPdf(Map<String, dynamic> ride) async {
    final status = (ride['status'] ?? '').toString().toLowerCase();
    if (status != 'completed') {
      throw StateError('A receipt is available only after ride completion.');
    }

    final document = pw.Document();
    final rows = _receiptRows(ride);

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(38),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.only(bottom: 18),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(
                      color: PdfColor.fromInt(0xFFFF7417),
                      width: 2,
                    ),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Rryd',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFFFF7417),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Move your way.',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.SizedBox(height: 18),
                    pw.Text(
                      'TRIP RECEIPT',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 22),
              ...rows.map(
                (row) => pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 10),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(
                        color: PdfColor.fromInt(0xFFE5E7EB),
                        width: 0.6,
                      ),
                    ),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(
                        width: 125,
                        child: pw.Text(
                          row.key,
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColor.fromInt(0xFF64748B),
                          ),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          row.value,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: row.key == 'Final fare'
                                ? pw.FontWeight.bold
                                : pw.FontWeight.normal,
                            color: row.key == 'Final fare'
                                ? const PdfColor.fromInt(0xFF111827)
                                : const PdfColor.fromInt(0xFF1F2937),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              pw.Spacer(),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.only(top: 14),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(
                      color: PdfColor.fromInt(0xFFE5E7EB),
                    ),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Thank you for riding with Rryd.',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'This receipt reflects the completed trip record available in Rryd. '
                      'Payment confirmation is shown only as recorded by the payment system.',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColor.fromInt(0xFF64748B),
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Generated: ${_date(DateTime.now().toIso8601String())}',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColor.fromInt(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return document.save();
  }

  static Future<void> printOrSave(Map<String, dynamic> ride) async {
    final bytes = await buildPdf(ride);
    final id = _value(ride['id'], fallback: 'trip');
    await Printing.layoutPdf(
      name: 'Rryd-Receipt-$id.pdf',
      onLayout: (_) async => bytes,
    );
  }

  static Future<void> share(Map<String, dynamic> ride) async {
    final bytes = await buildPdf(ride);
    final id = _value(ride['id'], fallback: 'trip');
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Rryd-Receipt-$id.pdf',
    );
  }
}
