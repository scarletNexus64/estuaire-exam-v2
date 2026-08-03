import 'package:flutter/material.dart';

import 'app/coquille_admin.dart';
import 'app/theme.dart';

void main() {
  runApp(const ApplicationEstuaire());
}

class ApplicationEstuaire extends StatelessWidget {
  const ApplicationEstuaire({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Estuaire Examen',
      debugShowCheckedModeBanner: false,
      theme: construireTheme(),
      home: const CoquilleAdmin(),
    );
  }
}
