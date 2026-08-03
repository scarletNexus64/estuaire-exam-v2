import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estuaire_examen/main.dart';

Future<void> capturer(WidgetTester tester, String nom) async {
  final image = await tester.binding
      .takeScreenshot(nom) as List<int>?;
  if (image != null) {
    File('/tmp/ee_$nom.png').writeAsBytesSync(image);
  }
}

void main() {
  testWidgets('captures des ecrans', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(2880, 1800);

    await tester.pumpWidget(const ApplicationEstuaire());
    await tester.pumpAndSettle();

    final boundary = tester.binding.renderViewElement!.renderObject!;
    debugPrint('>>> rendu ok: ${boundary.runtimeType}');
  });
}
