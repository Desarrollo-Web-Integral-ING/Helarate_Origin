import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../domain/models/tenant_model.dart';
import '../../domain/models/venta_model.dart';

/// Genera el ticket en formato de rollo de 80 mm (impresoras térmicas)
/// o como PDF si no hay impresora.
class ReceiptPdf {
  ReceiptPdf._();

  static String folio(VentaModel v) => v.id.length >= 8
      ? v.id.substring(0, 8).toUpperCase()
      : v.id.toUpperCase();

  static Future<Uint8List> build({
    required VentaModel venta,
    required NumberFormat fmt,
    TenantModel? tenant,
    double? efectivoRecibido,
    int paperWidthMm = 80,
  }) async {
    final doc = pw.Document(title: 'Ticket ${folio(venta)}');
    final date = DateFormat('dd/MM/yyyy HH:mm').format(venta.fecha);

    pw.TextStyle s(double size, {bool bold = false}) => pw.TextStyle(
          fontSize: size,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        );

    pw.Widget line() => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Divider(thickness: 0.5, height: 1),
        );

    pw.Widget row(String l, String r, {bool bold = false, double size = 9}) =>
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(l, style: s(size, bold: bold)),
            pw.Text(r, style: s(size, bold: bold)),
          ],
        );

    final cambio = (efectivoRecibido != null && efectivoRecibido > 0)
        ? efectivoRecibido - venta.totalIngresos
        : null;

    doc.addPage(
      pw.Page(
        pageFormat: (paperWidthMm <= 58 ? PdfPageFormat.roll57 : PdfPageFormat.roll80).copyWith(
          marginLeft: 4 * PdfPageFormat.mm,
          marginRight: 4 * PdfPageFormat.mm,
          marginTop: 4 * PdfPageFormat.mm,
          marginBottom: 6 * PdfPageFormat.mm,
        ),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: pw.Text(tenant?.nombre ?? 'Punto de Venta',
                  style: s(13, bold: true), textAlign: pw.TextAlign.center),
            ),
            if ((tenant?.direccion ?? '').isNotEmpty)
              pw.Center(
                child: pw.Text(tenant!.direccion!,
                    style: s(8), textAlign: pw.TextAlign.center),
              ),
            if ((tenant?.telefono ?? '').isNotEmpty)
              pw.Center(child: pw.Text('Tel: ${tenant!.telefono}', style: s(8))),
            line(),
            row('Folio: ${folio(venta)}', date, size: 8),
            line(),
            for (final d in venta.detalles) ...[
              pw.Text(d.insumoNombre ?? 'Producto', style: s(9, bold: true)),
              row('${d.cantidad.toInt()} x ${fmt.format(d.precioVentaUnitario)}',
                  fmt.format(d.total)),
              pw.SizedBox(height: 3),
            ],
            line(),
            row('TOTAL', fmt.format(venta.totalIngresos), bold: true, size: 12),
            if (cambio != null) ...[
              row('Recibido', fmt.format(efectivoRecibido)),
              row('Cambio', fmt.format(cambio < 0 ? 0 : cambio), bold: true),
            ],
            line(),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                tenant?.mensajeRecibo ?? '¡Gracias por su compra!',
                style: s(9, bold: true),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(height: 8),
            // QR con el folio: sirve para buscar la venta con un lector.
            pw.Center(
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: venta.id,
                width: 64,
                height: 64,
              ),
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }
}
