import 'package:flutter/widgets.dart';

/// Ícone Hugeicons 1.x (SVG JSON) ou [IconData] sentinel para ícones customizados.
typedef TaskerIconGlyph = Object;

bool taskerIconIsCustom(TaskerIconGlyph icon) => icon is IconData;

List<List<dynamic>>? taskerIconAsHugeData(TaskerIconGlyph icon) {
  if (icon is List<List<dynamic>>) return icon;
  return null;
}

IconData? taskerIconAsCustomData(TaskerIconGlyph icon) {
  if (icon is IconData) return icon;
  return null;
}
