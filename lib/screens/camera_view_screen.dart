import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';

class CameraViewScreen extends StatefulWidget {
  const CameraViewScreen({super.key});

  @override
  State<CameraViewScreen> createState() => _CameraViewScreenState();
}

class _CameraViewScreenState extends State<CameraViewScreen> {
  String? _errorMessage;
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  FlashMode _flashMode = FlashMode.off;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _controller = CameraController(_cameras![0], ResolutionPreset.medium);
        await _controller!.initialize();
        await _controller!.setFlashMode(_flashMode);
        setState(() {
          _isInitialized = true;
        });
      } else {
        setState(() {
          _errorMessage = 'No camera found on device.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Camera error: $e';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera'),
        actions: [
          IconButton(
            icon: Icon(
              _flashMode == FlashMode.torch ? Icons.flash_on : Icons.flash_off,
              color: _flashMode == FlashMode.torch
                  ? Colors.yellow
                  : Colors.white,
            ),
            onPressed: _isInitialized && _controller != null
                ? () async {
                    FlashMode newMode = _flashMode == FlashMode.torch
                        ? FlashMode.off
                        : FlashMode.torch;
                    await _controller!.setFlashMode(newMode);
                    setState(() {
                      _flashMode = newMode;
                    });
                  }
                : null,
            tooltip: _flashMode == FlashMode.torch ? 'Flash On' : 'Flash Off',
          ),
        ],
      ),
      body: _errorMessage != null
          ? Center(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            )
          : _isInitialized && _controller != null
          ? Stack(
              children: [
                CameraPreview(_controller!),
                Positioned(
                  bottom: 32,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FloatingActionButton(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      child: const Icon(Icons.camera_alt, size: 32),
                      onPressed: () async {
                        try {
                          final file = await _controller!.takePicture();
                          if (!mounted) return;
                          showDialog(
                            context: context,
                            builder: (context) => Dialog(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.file(
                                    File(file.path),
                                    fit: BoxFit.contain,
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                    ),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
