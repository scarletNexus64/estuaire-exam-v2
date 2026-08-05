import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:estuaire_examen/data/base_locale.dart';
import 'package:estuaire_examen/data/magasin.dart';
import 'package:estuaire_examen/data/magasin_campus.dart';
import 'package:estuaire_examen/data/magasin_insam.dart';
import 'package:estuaire_examen/data/referentiel_insam.dart';

import 'aide_referentiel.dart';

/// Le scénario réel : vider la base depuis les paramètres, puis importer
/// sans quitter l'application.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory dossier;

  setUp(() async {
    dossier = await Directory.systemTemp.createTemp('vider-importer');
    await BaseLocale.instance.ouvrirPourTest('${dossier.path}/estuaire.db');
    await MagasinCampus.instance.charger();
    await ReferentielInsam.instance
        .ouvrirPourTest(await referentielDeTest());
  });

  tearDown(() async {
    await ReferentielInsam.instance.fermer();
    await BaseLocale.instance.fermer();
    await dossier.delete(recursive: true);
  });

  test('vider la base ne doit pas faire perdre le campus actif', () async {
    MagasinCampus.instance.choisir(MagasinCampus.instance.parId('CMP001'));
    await Magasin.instance.charger();
    expect(MagasinCampus.instance.actif, isNotNull);

    await BaseLocale.instance.reinitialiser();
    await MagasinCampus.instance.charger();
    await Magasin.instance.charger();

    // Le campus survit à la remise à zéro : sans lui, `Magasin.charger`
    // ne charge rien et l'application reste vide quoi qu'on importe.
    expect(MagasinCampus.instance.actif, isNotNull,
        reason: 'sans campus actif, rien ne s\'affiche après un import');
  });

  test('importer juste après avoir vidé rend les données visibles',
      () async {
    MagasinCampus.instance.choisir(MagasinCampus.instance.parId('CMP001'));
    await Magasin.instance.charger();

    // 1. Vider depuis l'écran « Base de données ».
    await BaseLocale.instance.reinitialiser();
    await Magasin.instance.charger();
    expect(Magasin.instance.specialites, isEmpty);

    // 2. Importer, sans avoir quitté l'application.
    final campus = MagasinCampus.instance.campus.map((c) => c.id).toSet();
    final bilan = await MagasinInsam.instance.importerAnnee(
      idAnnee: 4,
      campusIds: campus,
      sansEtudiants: MagasinInsam.campusSansEtudiants,
    );
    expect(bilan.matieresAjoutees, greaterThan(0));

    // 3. Les données doivent être visibles immédiatement, sans
    // rechargement manuel : c'est ce que voit l'utilisateur.
    expect(Magasin.instance.specialites, isNotEmpty,
        reason: 'les spécialités doivent apparaître après l\'import');
    expect(Magasin.instance.etudiants, isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
