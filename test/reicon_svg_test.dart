import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_gasto/widgets/app_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('buildIconSvg pinta píxeles para un ícono válido', () async {
    final info = await vg.loadPicture(
      SvgStringLoader(
          buildIconSvg('foodTray', color: Colors.black, size: 48)),
      null,
    );
    final image = await info.picture.toImage(48, 48);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

    var paintedPixels = 0;
    for (var i = 3; i < data!.lengthInBytes; i += 4) {
      if (data.getUint8(i) > 0) paintedPixels++;
    }
    expect(paintedPixels, greaterThan(0),
        reason: 'El SVG se parseó pero no pintó ningún píxel');
  });

  test('buildIconSvg usa el fallback con un nombre inválido', () async {
    final info = await vg.loadPicture(
      SvgStringLoader(buildIconSvg('nombre_que_no_existe',
          color: Colors.black, size: 48)),
      null,
    );
    final image = await info.picture.toImage(48, 48);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

    var paintedPixels = 0;
    for (var i = 3; i < data!.lengthInBytes; i += 4) {
      if (data.getUint8(i) > 0) paintedPixels++;
    }
    expect(paintedPixels, greaterThan(0),
        reason: 'El fallback no pintó ningún píxel');
  });
}
