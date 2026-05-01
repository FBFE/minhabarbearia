import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

/// Abre ecrã completo para o utilizador ajustar a foto a um **quadrado 1:1**
/// (igual ao catálogo). Devolve os bytes JPEG recortados ou `null` se cancelar.
Future<Uint8List?> showServiceSquareCropDialog(
  BuildContext context, {
  required Uint8List imageBytes,
}) {
  return showDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ServiceSquareCropDialog(imageBytes: imageBytes),
  );
}

class _ServiceSquareCropDialog extends StatefulWidget {
  const _ServiceSquareCropDialog({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<_ServiceSquareCropDialog> createState() => _ServiceSquareCropDialogState();
}

class _ServiceSquareCropDialogState extends State<_ServiceSquareCropDialog> {
  final _cropController = CropController();
  var _cropping = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Ajustar ao quadrado'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _cropping ? null : () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _cropping
                ? null
                : () {
                    setState(() => _cropping = true);
                    _cropController.crop();
                  },
            child: Text(
              'Usar foto',
              style: TextStyle(
                color: _cropping ? Colors.white38 : const Color(0xFFFFC107),
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Pinça para zoom. Arraste a moldura quadrada. O resultado é o que aparece no app.',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13, height: 1.35),
              ),
            ),
            Expanded(
              child: Crop(
                image: widget.imageBytes,
                controller: _cropController,
                aspectRatio: 1,
                interactive: true,
                fixCropRect: false,
                initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
                  size: 0.88,
                  aspectRatio: 1,
                ),
                baseColor: Colors.black,
                maskColor: Colors.black.withValues(alpha: 0.65),
                radius: 4,
                onCropped: (result) {
                  setState(() => _cropping = false);
                  switch (result) {
                    case CropSuccess(:final croppedImage):
                      Navigator.of(context).pop(croppedImage);
                    case CropFailure(:final cause):
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Não foi possível recortar: $cause')),
                        );
                      }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
