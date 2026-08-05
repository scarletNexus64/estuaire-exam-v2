import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:estuaire_examen/data/base_locale.dart';
import 'package:estuaire_examen/data/import_dump_insam.dart';
import 'package:estuaire_examen/data/magasin.dart';
import 'package:estuaire_examen/data/magasin_campus.dart';
import 'package:estuaire_examen/data/magasin_insam.dart';
import 'package:estuaire_examen/data/referentiel_insam.dart';

/// Rejoue la séquence complète de l'utilisateur : vider la base, puis
/// téléverser un dump, puis tout importer.
///
/// C'est l'enchaînement qui n'avait rien produit : le test le fige pour
/// qu'il ne puisse plus redevenir silencieux.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('vider puis téléverser puis importer remplit bien la base',
      () async {
    final dump = File('databases/insam/insamdigitale_stools.sql');
    if (!await dump.exists()) {
      markTestSkipped('dump absent');
      return;
    }

    final dossier = await Directory.systemTemp.createTemp('sequence');
    await BaseLocale.instance.ouvrirPourTest('${dossier.path}/estuaire.db');
    await MagasinCampus.instance.charger();
    MagasinCampus.instance.choisir(MagasinCampus.instance.parId('CMP001'));
    await Magasin.instance.charger();

    // 1. Vider la base, comme depuis l'écran « Base de données ».
    await BaseLocale.instance.reinitialiser();
    await Magasin.instance.charger();

    // Les campus doivent survivre : c'est d'eux que dépend l'import.
    expect(MagasinCampus.instance.campus, isNotEmpty,
        reason: 'sans campus, l\'import n\'a aucune destination');

    // 2. Téléverser le dump.
    final reference = '${dossier.path}/insam_reference.db';
    await ImportDumpInsam.convertir(dump: dump, destination: reference);
    await ReferentielInsam.instance.ouvrirPourTest(reference);

    final annees = await ReferentielInsam.instance.annees();
    expect(annees, isNotEmpty);
    final derniere = annees.first;

    final promotions =
        await ReferentielInsam.instance.promotions(derniere.id);
    expect(promotions, isNotEmpty,
        reason: 'l\'année la plus récente doit avoir des promotions');

    // 3. Tout importer, avec la sélection par défaut de l'écran.
    final campus = MagasinCampus.instance.campus.map((c) => c.id).toSet();
    final bilan = await MagasinInsam.instance.importerAnnee(
      idAnnee: derniere.id,
      campusIds: campus,
      sansEtudiants: MagasinInsam.campusSansEtudiants,
    );

    expect(bilan.campusServis, campus.length);
    expect(bilan.matieresAjoutees, greaterThan(0));
    expect(bilan.etudiantsAjoutes, greaterThan(0));

    // Et surtout : les données doivent être visibles dans le magasin,
    // c'est-à-dire à l'écran.
    await Magasin.instance.charger();
    expect(Magasin.instance.specialites, isNotEmpty,
        reason: 'les spécialités doivent apparaître pour le campus actif');
    expect(Magasin.instance.matieres, isNotEmpty);
    expect(Magasin.instance.etudiants, isNotEmpty);

    await ReferentielInsam.instance.fermer();
    await BaseLocale.instance.fermer();
    await dossier.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
