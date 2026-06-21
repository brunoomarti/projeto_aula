import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/tasker_colors.dart';

/// Seleciona uma foto da galeria e abre o recorte quadrado (1:1) com guias.
Future<Uint8List?> pickAndCropProfileAvatar(BuildContext context) async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    requestFullMetadata: false,
  );
  if (picked == null) return null;
  if (!context.mounted) return null;

  final cropped = await ImageCropper().cropImage(
    sourcePath: picked.path,
    aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
    maxWidth: 1024,
    maxHeight: 1024,
    compressQuality: 88,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Recortar foto',
        toolbarColor: TaskerColors.primary,
        toolbarWidgetColor: Colors.white,
        activeControlsWidgetColor: TaskerColors.primary,
        backgroundColor: Colors.black,
        dimmedLayerColor: Colors.black54,
        initAspectRatio: CropAspectRatioPreset.square,
        lockAspectRatio: true,
        hideBottomControls: false,
        showCropGrid: true,
        cropGridRowCount: 2,
        cropGridColumnCount: 2,
        cropGridColor: Colors.white70,
        cropGridStrokeWidth: 1,
        cropFrameColor: Colors.white,
        cropFrameStrokeWidth: 2,
        aspectRatioPresets: [CropAspectRatioPreset.square],
      ),
      IOSUiSettings(
        title: 'Recortar foto',
        doneButtonTitle: 'Concluir',
        cancelButtonTitle: 'Cancelar',
        aspectRatioLockEnabled: true,
        aspectRatioPickerButtonHidden: true,
        resetAspectRatioEnabled: false,
        aspectRatioPresets: [CropAspectRatioPreset.square],
      ),
      WebUiSettings(
        context: context,
        guides: true,
        center: true,
        zoomable: true,
        scalable: true,
        movable: true,
        initialAspectRatio: 1,
        presentStyle: WebPresentStyle.dialog,
      ),
    ],
  );

  if (cropped == null) return null;
  return cropped.readAsBytes();
}

String profileAvatarPickErrorMessage(Object error) {
  if (error is PlatformException && error.code == 'channel-error') {
    return 'Galeria indisponível. Pare o app e rode flutter run de novo '
        'para registrar os plugins nativos.';
  }
  return 'Não foi possível escolher a foto: $error';
}
