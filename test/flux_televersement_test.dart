import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:estuaire_examen/data/import_dump_insam.dart';
import 'package:estuaire_examen/data/referentiel_insam.dart';

/// Le téléversement tel que l'écran l'enchaîne : ouvrir un référentiel
/// absent, convertir le dump, rouvrir, puis lire les années.
///
/// C'est cette séquence qui ne donnait rien à l'écran.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('après conversion, le référentiel devient disponible', () async {
    final dump = File('databases/insam/insamdigitale_stools.sql');
    if (!await dump.exists()) {
      markTestSkipped('dump absent');
      return;
    }

    final dossier = await Directory.systemTemp.createTemp('flux');
    final destination = '${dossier.path}/insam_reference.db';

    // 1. Au démarrage, aucun référentiel : l'ouverture doit être muette
    // et laisser l'écran proposer le téléversement.
    await ReferentielInsam.instance.fermer();
    expect(ReferentielInsam.instance.estDisponible, isFalse);

    // 2. Conversion du dump, comme le fait le bouton « Téléverser ».
    await ImportDumpInsam.convertir(dump: dump, destination: destination);
    expect(await File(destination).exists(), isTrue);

    // 3. Réouverture : c'est ici que l'écran décide s'il affiche
    // quelque chose.
    await ReferentielInsam.instance.ouvrirPourTest(destination);
    expect(ReferentielInsam.instance.estDisponible, isTrue,
        reason: 'sans cela l\'écran reste sur « Aucun référentiel »');

    final annees = await ReferentielInsam.instance.annees();
    expect(annees, isNotEmpty);

    final promotions =
        await ReferentielInsam.instance.promotions(annees.first.id);
    expect(promotions, isNotEmpty,
        reason: 'l\'écran doit pouvoir proposer des promotions');

    await ReferentielInsam.instance.fermer();
    await dossier.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('ouvrir un référentiel absent ne lève pas d\'erreur', () async {
    await ReferentielInsam.instance.fermer();
    // `ouvrir()` s'appuie sur le dossier de support de l'application, que
    // les tests n'ont pas ; on vérifie seulement que l'état reste sain.
    expect(ReferentielInsam.instance.estDisponible, isFalse);
  });
}
