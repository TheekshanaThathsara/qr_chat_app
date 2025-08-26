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
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String code = barcodes.first.rawValue ?? '';
      if (code.isNotEmpty) {
        Navigator.of(context).pop(code);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
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
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              size: 100,
              color: Colors.white,
            ),
            const SizedBox(height: 24),
            const Text(
              'Camera Permission Required',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please grant camera permission to scan QR codes',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return Container(
      decoration: const ShapeDecoration(
        shape: QrScannerOverlayShape(
          borderColor: Colors.white,
          borderRadius: 10,
          borderLength: 30,
          borderWidth: 10,
          cutOutSize: 250,
        ),
      ),
      child: const Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            'Point your camera at a QR code',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ),
    );
  }
}

class QrScannerOverlayShape extends ShapeBorder {
  const QrScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    double? cutOutSize,
  }) : cutOutSize = cutOutSize ?? 250;

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
