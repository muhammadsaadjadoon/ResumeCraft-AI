import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'resume.dart';

class ResumePdf {
  static Iterable<String> _paragraphs(String text) sync* {
    for (var line in text.split('\n')) {
      while (line.length > 700) {
        var end = line.lastIndexOf(' ', 700);
        if (end < 100) {
          end = 700;
        }
        yield line.substring(0, end);
        line = line.substring(end).trimLeft();
      }
      yield line;
    }
  }

  static Future<Uint8List> build(Resume r, [PdfPageFormat? format]) async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Regular.ttf'),
    );
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Bold.ttf'));
    final document = pw.Document();
    final accent = PdfColor.fromInt(r.accent);
    final classic = r.template == 'classic';
    final minimal = r.template == 'minimal';
    final sections = [
      'summary',
      'skills',
      'experience',
      'education',
      'projects',
      'certifications',
      'languages',
    ];
    document.addPage(
      pw.MultiPage(
        pageFormat: format ?? PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(38),
        maxPages: 30,
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
          ),
        ),
        build: (context) => [
          pw.Container(
            padding: pw.EdgeInsets.only(bottom: 16),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(
                  color: minimal ? PdfColors.grey300 : accent,
                  width: classic ? 1 : 3,
                ),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: classic
                  ? pw.CrossAxisAlignment.center
                  : pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  r.data['name']!.isEmpty ? 'Your name' : r.data['name']!,
                  style: pw.TextStyle(
                    fontSize: 26,
                    fontWeight: pw.FontWeight.bold,
                    color: minimal ? PdfColors.black : accent,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  r.data['role']!,
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  ['email', 'phone', 'location', 'linkedin', 'website']
                      .map((k) => r.data[k]!)
                      .where((s) => s.trim().isNotEmpty)
                      .join('  |  '),
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
          ),
          for (final key in sections)
            if (r.data[key]!.trim().isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Text(
                resumeFields[key]!.split(' (').first.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: minimal ? PdfColors.black : accent,
                ),
              ),
              pw.SizedBox(height: 6),
              // Separate paragraphs can paginate; the entire section is never one unbreakable box.
              for (final line in _paragraphs(r.data[key]!))
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text(
                    line,
                    style: const pw.TextStyle(fontSize: 10, lineSpacing: 3),
                  ),
                ),
            ],
        ],
      ),
    );
    return document.save();
  }
}
