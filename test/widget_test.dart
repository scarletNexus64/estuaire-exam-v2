import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:estuaire_examen/main.dart';

/// Cible un élément de la barre latérale (et non un titre de page
/// portant le même libellé).
Finder elementNav(String titre) => find.descendant(
      of: find.byType(InkWell),
      matching: find.text(titre),
    );

void main() {
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

  testWidgets('Le tableau de bord affiche les rubriques de configuration',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    await tester.pumpWidget(const ApplicationEstuaire());
    await tester.pumpAndSettle();

    for (final rubrique in [
      'Synthèse',
      'Étudiants',
      'Filières',
      'Spécialités',
      'Niveaux',
      'Salles de classe',
      'Matières',
      'Migration',
    ]) {
      expect(elementNav(rubrique), findsOneWidget,
          reason: 'La rubrique « $rubrique » doit être dans la navigation.');
    }
  });

  testWidgets('La navigation bascule d\'un écran à l\'autre',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    await tester.pumpWidget(const ApplicationEstuaire());
    await tester.pumpAndSettle();

    // L'écran de synthèse est affiché au démarrage.
    expect(find.text('Effectifs par niveau'), findsOneWidget);

    await tester.tap(elementNav('Salles de classe'));
    await tester.pumpAndSettle();

    expect(find.text('Effectifs par niveau'), findsNothing);
    expect(find.text('Nouvelle salle'), findsOneWidget);
  });

  testWidgets('La migration propose le niveau suivant automatiquement',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    await tester.pumpWidget(const ApplicationEstuaire());
    await tester.pumpAndSettle();

    await tester.tap(elementNav('Migration'));
    await tester.pumpAndSettle();

    // Seule l'étape 1 est visible tant que la promotion n'est pas choisie.
    expect(find.text('Choisir la promotion'), findsOneWidget);
    expect(find.text('Sélectionner les étudiants'), findsNothing);
  });
}
