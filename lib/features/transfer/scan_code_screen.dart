import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme.dart';
import '../../domain/transfer.dart';

/// Reads a transfer code, by camera or by paste.
///
/// One screen handles both kinds of code. Which one arrived is decided by the
/// payload itself rather than by the user picking a menu item first — from the
/// table's point of view there is only ever "scan the thing they're showing
/// me".
///
/// Pops with a [TransferPayload], or null if the user backed out.
class ScanCodeScreen extends StatefulWidget {
  const ScanCodeScreen({super.key});

  @override
  State<ScanCodeScreen> createState() => _ScanCodeScreenState();
}

class _ScanCodeScreenState extends State<ScanCodeScreen>
    with WidgetsBindingObserver {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  /// Stops a second detection arriving while we are already popping.
  bool _handled = false;

  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Without this the camera keeps its handle while the app is away and the
    // preview comes back black.
    switch (state) {
      case AppLifecycleState.resumed:
        unawaitedStart();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _controller.stop();
    }
  }

  void unawaitedStart() {
    _controller.start().catchError((Object _) {});
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    for (final barcode in capture.barcodes) {
      // Our codes are written in byte mode, so the payload comes back as raw
      // bytes. `rawValue` is the fallback for a code that was produced as
      // text — and for anything that simply is not one of ours, which the
      // decoder will then reject.
      final bytes = switch (barcode.rawDecodedBytes) {
        DecodedBarcodeBytes(:final bytes) => bytes,
        DecodedVisionBarcodeBytes(:final bytes) => bytes,
        _ => null,
      };

      try {
        final payload = bytes != null && bytes.isNotEmpty
            ? TransferCodec.decode(bytes)
            : TransferCodec.decodeText(barcode.rawValue ?? '');
        _handled = true;
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(payload);
        return;
      } on TransferException catch (e) {
        // Keep the camera running: the user is probably still lining it up,
        // and a wrong code in frame should not end the attempt.
        if (mounted) setState(() => _error = e.message);
      }
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      if (mounted) {
        setState(() => _error = 'There is nothing to paste.');
      }
      return;
    }

    try {
      final payload = TransferCodec.decodeText(text);
      if (!mounted) return;
      _handled = true;
      Navigator.of(context).pop(payload);
    } on TransferException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan a code')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _controller,
                    onDetect: _onDetect,
                    errorBuilder: (context, error) =>
                        _CameraUnavailable(error: error),
                  ),
                  const _ViewfinderFrame(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                children: [
                  if (_error != null) ...[
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: PodWiseColors.caution,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Point this at the code on the other phone.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _paste,
                      icon: const Icon(Icons.content_paste_rounded),
                      label: const Text('PASTE A CODE INSTEAD'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the camera cannot be used at all — denied, missing, or in use by
/// something else. Pasting still works, so this is not a dead end.
class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;

    return ColoredBox(
      color: PodWiseColors.surfaceRaised,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.no_photography_rounded,
                size: 42,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                denied
                    ? 'PodWise needs camera access to scan a code. You can '
                          'still paste one below.'
                    : 'The camera is not available. You can still paste a '
                          'code below.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  height: 1.5,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A plain frame, so it is obvious where to aim.
class _ViewfinderFrame extends StatelessWidget {
  const _ViewfinderFrame();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest.shortestSide * 0.7;
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              border: Border.all(
                color: PodWiseColors.accent.withValues(alpha: 0.8),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    ),
  );
}
