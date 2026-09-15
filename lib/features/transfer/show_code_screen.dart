import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../domain/transfer.dart';
import 'qr_code_view.dart';

/// Shows a transfer code for the other phone to scan.
///
/// Used for both directions — a pod going out and a result coming home — since
/// the two differ only in wording.
class ShowCodeScreen extends StatelessWidget {
  const ShowCodeScreen({
    super.key,
    required this.payload,
    required this.title,
    required this.instruction,
    this.footnote,
  });

  final TransferPayload payload;
  final String title;
  final String instruction;

  /// Anything the person holding this phone needs to know before they walk
  /// away from the screen.
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final bytes = TransferCodec.encode(payload);
    final text = TransferCodec.encodeText(payload);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Text(
              instruction,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.maxWidth.clamp(200.0, 340.0);
                  return PodWiseQrCode(data: bytes, size: size);
                },
              ),
            ),
            const SizedBox(height: 24),
            // The camera is not always an option — a cracked lens, a phone
            // across the room, or a friend who has already gone home.
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Code copied. Send it however you like.'),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('COPY AS TEXT INSTEAD'),
            ),
            if (footnote != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: PodWiseColors.caution.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: PodWiseColors.caution,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        footnote!,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: PodWiseColors.caution.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
