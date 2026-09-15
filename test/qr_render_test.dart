import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podwise/domain/transfer.dart';
import 'package:podwise/features/transfer/qr_code_view.dart';
import 'package:qr/qr.dart';

/// The QR matrix itself comes from the `qr` package and is not this app's
/// problem. The painter over it is, and a painter that transposes the grid,
/// drops the quiet zone or inverts the colours still produces something that
/// looks exactly like a QR code — it just cannot be scanned.
///
/// So this renders the widget and reads the pixels back.
void main() {
  testWidgets('the painted code matches the matrix it came from', (
    tester,
  ) async {
    final data = TransferCodec.encode(_pod());
    final expected = QrImage(
      QrCode(
        payload: QrPayload.fromTypedData(data),
        errorCorrectLevel: QrErrorCorrectLevel.medium,
      ),
    );

    const size = 400.0;
    final key = GlobalKey();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: PodWiseQrCode(data: data, size: size),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pixels = await _readPixels(tester, key);

    // The painter centres the code and pads it by four modules, matching what
    // it does on screen.
    const quietZone = 4;
    final modules = expected.moduleCount + quietZone * 2;
    final scale = (size / modules).floorToDouble();
    final drawn = scale * modules;
    final origin = (size - drawn) / 2;

    bool darkAt(int row, int col) {
      // Sample the middle of the module, away from any edge softening.
      final x = (origin + (col + quietZone) * scale + scale / 2).round();
      final y = (origin + (row + quietZone) * scale + scale / 2).round();
      return pixels.isDark(x, y);
    }

    // Collected rather than asserted one by one: a transposed grid would
    // otherwise produce thousands of near-identical failures.
    final wrong = <String>[];
    var checked = 0;
    for (var row = 0; row < expected.moduleCount; row++) {
      for (var col = 0; col < expected.moduleCount; col++) {
        if (darkAt(row, col) != expected.isDark(row, col)) {
          wrong.add('($row, $col)');
        }
        checked++;
      }
    }

    expect(checked, greaterThan(1000));
    expect(
      wrong,
      isEmpty,
      reason:
          '${wrong.length} of $checked modules painted wrong — a transposed '
          'or inverted grid still looks like a QR code but will not scan. '
          'First few: ${wrong.take(5).join(', ')}',
    );
  });

  testWidgets('the code is dark on white, with a quiet zone', (tester) async {
    final data = TransferCodec.encode(_pod());
    const size = 400.0;
    final key = GlobalKey();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: PodWiseQrCode(data: data, size: size),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pixels = await _readPixels(tester, key);

    // ML Kit does not reliably read an inverted code, and this app is dark
    // everywhere else — so the white card is deliberate and worth pinning.
    expect(pixels.isDark(4, 4), isFalse);
    expect(pixels.isDark(size ~/ 2, 4), isFalse);
    expect(pixels.isDark(size ~/ 2, size.toInt() - 5), isFalse);

    // Something was actually drawn.
    expect(pixels.darkCount, greaterThan(2000));
  });
}

Future<_Pixels> _readPixels(WidgetTester tester, GlobalKey key) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;

  // Rasterising is real async work, which a widget test's fake clock would
  // otherwise never let complete.
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    return _Pixels(data.buffer.asUint8List(), image.width, image.height);
  }))!;
}

class _Pixels {
  _Pixels(this.bytes, this.width, this.height);

  final Uint8List bytes;
  final int width;
  final int height;

  bool isDark(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) return false;
    final i = (y * width + x) * 4;
    // Red channel is enough: everything here is black, white or a blend.
    return bytes[i] < 128;
  }

  int get darkCount {
    var count = 0;
    for (var i = 0; i < bytes.length; i += 4) {
      if (bytes[i] < 128) count++;
    }
    return count;
  }
}

/// A pod the size of a real one, so the code under test is realistically
/// dense rather than a trivial few modules.
PodTransfer _pod() => const PodTransfer(
  sourceDeviceId: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
  seats: [
    TransferSeat(
      playerId: '69587ff4-a8d1-4176-b652-719f336c6304',
      name: 'Dave',
      colorIndex: 0,
      deckId: 'd9897c33-44e9-4cb2-b46e-24b5f5fbbc29',
      commanders: [
        TransferCard(
          id: '11111111-2222-3333-4444-555555555555',
          name: 'Atraxa, Praetors Voice',
        ),
      ],
    ),
    TransferSeat(
      playerId: '204cfd36-6844-4c94-9628-5ec690420831',
      name: 'Jordan',
      colorIndex: 2,
      deckId: '29357043-2baf-4ce8-9163-9699d90f1e29',
      commanders: [
        TransferCard(
          id: '22222222-3333-4444-5555-666666666666',
          name: 'Krenko, Mob Boss',
        ),
      ],
    ),
    TransferSeat(
      playerId: '2cd5be80-59b1-46fb-b573-729243dc79e4',
      name: 'Taylor Smith',
      colorIndex: 3,
      deckId: 'legacy-2cd5be80-59b1-46fb-b573-729243dc79e4',
      commanders: [
        TransferCard(
          id: '33333333-4444-5555-6666-777777777777',
          name: 'Yshtola, Nights Blessed',
        ),
      ],
    ),
  ],
);
