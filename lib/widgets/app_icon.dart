import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:reicon_flutter/reicon_flutter.dart';

import '../utils/category_icons.dart';

/// Construye el SVG de un ícono de Reicon con un color concreto.
///
/// flutter_svg no resuelve `currentColor` en el widget, así que se sustituye
/// por el color final para que el ícono se pinte siempre.
String buildIconSvg(String name, {required Color color, int size = 24}) {
  final hex = _hex(color);
  final pathData = (iconPathForName(name) ?? Reicon.outline.moreCircle)
      .replaceAll('currentColor', hex);
  return '<svg xmlns="http://www.w3.org/2000/svg" width="$size" height="$size" '
      'viewBox="0 0 24 24" fill="none">$pathData</svg>';
}

String _hex(Color value) {
  String part(double channel) => (channel * 255.0)
      .round()
      .clamp(0, 255)
      .toRadixString(16)
      .padLeft(2, '0');
  return '#${part(value.r)}${part(value.g)}${part(value.b)}';
}

class AppIcon extends StatelessWidget {
  const AppIcon(this.name, {super.key, this.size = 24, this.color});

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? IconTheme.of(context).color ?? Colors.black;
    return SvgPicture.string(
      buildIconSvg(name, color: resolved, size: size.round()),
      width: size,
      height: size,
    );
  }
}
