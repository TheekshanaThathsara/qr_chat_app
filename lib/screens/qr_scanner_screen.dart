import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _permissionGranted = false;
  bool _isInitialized = false;
  bool _scanned = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final status = await Permission.camera.request();
    setState(() {
      _permissionGranted = status == PermissionStatus.granted;
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return; // ignore duplicates
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String code = barcodes.first.rawValue ?? '';
      if (code.isNotEmpty) {
        _scanned = true;
        // stop camera to reduce duplicate detections
        try {
          cameraController.stop();
        } catch (_) {}

        // Safely try to pop passing the code. maybePop is safer than pop.
        try {
          Navigator.of(context).maybePop(code);
        } catch (e) {
          try {
            Navigator.of(context, rootNavigator: true).maybePop(code);
          } catch (e2) {
            debugPrint('Warning: unable to pop scanner route with code: $e2');
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Scan QR Code',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF9800), Color(0xFFD84315)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.flash_on, color: Colors.white, size: 20),
              onPressed: () => cameraController.toggleTorch(),
              tooltip: 'Toggle Flash',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 20),
              onPressed: () => cameraController.switchCamera(),
              tooltip: 'Switch Camera',
            ),
          ),
        ],
      ),
      body: !_isInitialized
          ? Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1A1A1A),
                    Color(0xFF000000),
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF9800), Color(0xFFD84315)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF9800).withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Initializing Camera...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : !_permissionGranted
          ? _buildPermissionDenied()
          : Stack(
              children: [
                MobileScanner(
                  controller: cameraController,
                  onDetect: _onDetect,
                ),
                _buildOverlay(),
              ],
            ),
    );
  }

  Widget _buildPermissionDenied() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A1A1A),
            Color(0xFF000000),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFF9800),
                      Color(0xFFD84315),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF9800).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Camera Permission Required',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Please grant camera permission to scan QR codes and connect with friends',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFF9800),
                      Color(0xFFD84315),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF9800).withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () async {
                    await openAppSettings();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Open Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return Container(
      decoration: const ShapeDecoration(
        shape: QrScannerOverlayShape(
          borderColor: Color(0xFFFF9800),
          borderRadius: 20,
          borderLength: 40,
          borderWidth: 4,
          cutOutSize: 280,
        ),
      ),
      child: Column(
        children: [
          const Spacer(),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFF9800).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF9800), Color(0xFFD84315)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Scanning for QR Code',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Point your camera at a QR code to connect with friends',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Flexible(
                      child: _buildHintItem(Icons.flash_on, 'Flash'),
                    ),
                    Flexible(
                      child: _buildHintItem(Icons.flip_camera_ios, 'Flip'),
                    ),
                    Flexible(
                      child: _buildHintItem(Icons.center_focus_strong, 'Focus'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHintItem(IconData icon, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFFFF9800).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 14,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 9,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class QrScannerOverlayShape extends ShapeBorder {
  const QrScannerOverlayShape({
    this.borderColor = const Color(0xFFFF9800),
    this.borderWidth = 4.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 120),
    this.borderRadius = 20,
    this.borderLength = 40,
    double? cutOutSize,
  }) : cutOutSize = cutOutSize ?? 280;

  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top + borderRadius)
        ..quadraticBezierTo(
          rect.left,
          rect.top,
          rect.left + borderRadius,
          rect.top,
        )
        ..lineTo(rect.right, rect.top);
    }

    return getLeftTopPath(rect)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final borderOffset = borderWidth / 2;
    final mCutOutWidth = cutOutSize;
    final mCutOutHeight = cutOutSize;

    final mCutOutX = (width - mCutOutWidth) / 2;
    final mCutOutY = (height - mCutOutHeight) / 2;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final backgroundRect = Rect.fromLTWH(0, 0, width, height);
    final cutOutRect = Rect.fromLTWH(
      mCutOutX,
      mCutOutY,
      mCutOutWidth,
      mCutOutHeight,
    );

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(backgroundRect),
        Path()
          ..addRRect(
            RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)),
          )
          ..close(),
      ),
      backgroundPaint,
    );

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final path = Path()
      // Top left
      ..moveTo(mCutOutX - borderOffset, mCutOutY + borderLength)
      ..quadraticBezierTo(
        mCutOutX - borderOffset,
        mCutOutY - borderOffset,
        mCutOutX + borderRadius,
        mCutOutY - borderOffset,
      )
      ..lineTo(mCutOutX + borderLength, mCutOutY - borderOffset)
      // Top right
      ..moveTo(mCutOutX + mCutOutWidth - borderLength, mCutOutY - borderOffset)
      ..lineTo(mCutOutX + mCutOutWidth - borderRadius, mCutOutY - borderOffset)
      ..quadraticBezierTo(
        mCutOutX + mCutOutWidth + borderOffset,
        mCutOutY - borderOffset,
        mCutOutX + mCutOutWidth + borderOffset,
        mCutOutY + borderRadius,
      )
      ..lineTo(mCutOutX + mCutOutWidth + borderOffset, mCutOutY + borderLength)
      // Bottom right
      ..moveTo(
        mCutOutX + mCutOutWidth + borderOffset,
        mCutOutY + mCutOutHeight - borderLength,
      )
      ..lineTo(
        mCutOutX + mCutOutWidth + borderOffset,
        mCutOutY + mCutOutHeight - borderRadius,
      )
      ..quadraticBezierTo(
        mCutOutX + mCutOutWidth + borderOffset,
        mCutOutY + mCutOutHeight + borderOffset,
        mCutOutX + mCutOutWidth - borderRadius,
        mCutOutY + mCutOutHeight + borderOffset,
      )
      ..lineTo(
        mCutOutX + mCutOutWidth - borderLength,
        mCutOutY + mCutOutHeight + borderOffset,
      )
      // Bottom left
      ..moveTo(mCutOutX + borderLength, mCutOutY + mCutOutHeight + borderOffset)
      ..lineTo(mCutOutX + borderRadius, mCutOutY + mCutOutHeight + borderOffset)
      ..quadraticBezierTo(
        mCutOutX - borderOffset,
        mCutOutY + mCutOutHeight + borderOffset,
        mCutOutX - borderOffset,
        mCutOutY + mCutOutHeight - borderRadius,
      )
      ..lineTo(
        mCutOutX - borderOffset,
        mCutOutY + mCutOutHeight - borderLength,
      );

    canvas.drawPath(path, borderPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }
}
