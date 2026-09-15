import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// Renders transfer bytes as a QR code.
///
/// Painted by hand over the `qr` package's module matrix rather than using a
/// widget library — `qr_flutter`, the obvious choice, has not been published in
/// three years.
///
/// Two details here are load-bearing rather than cosmetic:
///
/// * **Dark modules on white**, breaking the app's dark theme on purpose.
///   ML Kit does not reliably decode an inverted code, and a light-on-dark QR
///   is the single most common reason a code "just won't scan".
/// * **A four-module quiet zone**, which the spec requires and scanners rely on
///   to find the code's edges at all.
class PodWiseQrCode extends StatelessWidget {
  const PodWiseQrCode({super.key, required this.data, this.size = 280});

  final Uint8List data;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Byte mode, so the payload goes in raw. Encoding it as text first would
    // cost a third more modules for no benefit.
    final image = QrImage(
      QrCode(
        payload: QrPayload.fromTypedData(data),
        // Medium recovers from a smudged screen without inflating the code the
        // way high correction would.
        errorCorrectLevel: QrErrorCorrectLevel.medium,
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(painter: _QrPainter(image)),
    );
  }
}

class _QrPainter extends CustomPainter {
  const _QrPainter(this.image);

  final QrImage image;

  /// Required by the spec, and what lets a scanner find the code's edges.
  static const _quietZone = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final modules = image.moduleCount + _quietZone * 2;

    // Modules are drawn on whole pixels. Letting them land on fractions leaves
    // antialiased grey edges, which is exactly the kind of softness that makes
    // a dense code decode intermittently.
    final scale = (size.shortestSide / modules).floorToDouble();
    if (scale < 1) return;

    final drawn = scale * modules;
    final offset = Offset((size.width - drawn) / 2, (size.height - drawn) / 2);

    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;

    for (var row = 0; row < image.moduleCount; row++) {
      for (var col = 0; col < image.moduleCount; col++) {
        if (!image.isDark(row, col)) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            offset.dx + (col + _quietZone) * scale,
            offset.dy + (row + _quietZone) * scale,
            // A hair over one module, so neighbours meet cleanly instead of
            // leaving hairline gaps that soften the pattern.
            scale + 0.5,
            scale + 0.5,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) => oldDelegate.image != image;
}
