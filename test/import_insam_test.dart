import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:estuaire_examen/data/base_locale.dart';
import 'package:estuaire_examen/data/magasin.dart';
import 'package:estuaire_examen/data/magasin_campus.dart';
import 'package:estuaire_examen/data/magasin_insam.dart';
import 'package:estuaire_examen/data/modeles.dart';
import 'package:estuaire_examen/data/referentiel_insam.dart';

import 'aide_referentiel.dart';

/// Import d'une vraie promotion du référentiel, dans tous les campus.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory dossier;

  setUp(() async {
    dossier = await Directory.systemTemp.createTemp('estuaire-import');
    await BaseLocale.instance.ouvrirPourTest('${dossier.path}/test.db');
    await MagasinCampus.instance.charger();
    await ReferentielInsam.instance
        .ouvrirPourTest(await referentielDeTest());
    MagasinCampus.instance.choisir(MagasinCampus.instance.parId('CMP001'));
    await Magasin.instance.charger();
  });

  tearDown(() async {
    await ReferentielInsam.instance.fermer();
    await BaseLocale.instance.fermer();
    await dossier.delete(recursive: true);
  });

  /// La promotion du modèle fourni par INSAM : Génie Logiciel, niveau 2,
  /// 2025/2026 — 76 étudiants et 23 matières.
  Future<PromotionInsam> promotionTemoin() async {
    final promotions = await ReferentielInsam.instance.promotions(4);
    return promotions.firstWhere((p) => p.idSpecialite == 1251);
  }

  test('la promotion témoin correspond au modèle INSAM', () async {
    final promo = await promotionTemoin();
    expect(promo.intitule, 'GENIE LOGICIEL');
    expect(promo.nombreEtudiants, 76);
    expect(promo.nombreMatieres, 23);
    expect(promo.palier.abreviation, 'BTS 2');
  });

  test('l\'import sert tous les campus, sans étudiants à Bamboutos',
      () async {
    final promo = await promotionTemoin();
    final bilan = await MagasinInsam.instance.importerPromotion(promo);

    final campus = MagasinCampus.instance.campus;
    expect(bilan.campusServis, campus.length);

    for (final b in bilan.campus) {
      expect(b.matieresAjoutees, 23,
          reason: '${b.campusIntitule} doit recevoir le programme');
      if (b.campusId == 'CMP007') {
        expect(b.etudiantsAjoutes, 0,
            reason: 'Bamboutos ne reçoit pas les effectifs');
      } else {
        expect(b.etudiantsAjoutes, 76,
            reason: '${b.campusIntitule} doit recevoir les étudiants');
      }
    }

    // Chaque campus a sa propre copie, et donc sa propre correspondance.
    final db = BaseLocale.instance.db;
    final matieres = await db.rawQuery(
        'SELECT COUNT(*) c FROM correspondance_insam WHERE entite = ?',
        [EntiteInsam.matiere]);
    expect(matieres.first['c'], 23 * campus.length);

    final etudiants = await db.rawQuery(
        'SELECT COUNT(*) c FROM correspondance_insam WHERE entite = ?',
        [EntiteInsam.etudiant]);
    expect(etudiants.first['c'], 76 * (campus.length - 1));

    // L'encodage doit être propre : un nom accentué le prouve.
    final avecAccent = await db.rawQuery(
        "SELECT COUNT(*) c FROM etudiant WHERE nom_complet LIKE '%Ã%'");
    expect(avecAccent.first['c'], 0,
        reason: 'aucun nom ne doit rester en mojibake');
  });

  test('rejouer l\'import n\'ajoute rien', () async {
    final promo = await promotionTemoin();
    await MagasinInsam.instance.importerPromotion(promo);
    final second = await MagasinInsam.instance.importerPromotion(promo);

    expect(second.etudiantsAjoutes, 0);
    expect(second.matieresAjoutees, 0);
  });

  test('l\'import d\'une année ne retient que les campus choisis',
      () async {
    // Un seul campus, et sans les étudiants : rien d'autre ne doit être
    // touché.
    final bilan = await MagasinInsam.instance.importerAnnee(
      idAnnee: 4,
      campusIds: {'CMP002'},
      sansEtudiants: {'CMP002'},
    );

    expect(bilan.campusServis, 1);
    expect(bilan.campus.single.campusId, 'CMP002');
    expect(bilan.etudiantsAjoutes, 0,
        reason: 'campus exclu des effectifs');
    expect(bilan.matieresAjoutees, greaterThan(0));

    final db = BaseLocale.instance.db;
    final ailleurs = await db.rawQuery(
        'SELECT COUNT(*) c FROM specialite WHERE campus_id <> ?',
        ['CMP002']);
    expect(ailleurs.first['c'], 0);
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('une filière aux codes incohérents ne crée qu\'une spécialité',
      () async {
    // INSAM désigne ACCOUNTANCY tantôt « AC » tantôt « ACC » : se fier au
    // code créerait deux spécialités homonymes côte à côte.
    await MagasinInsam.instance.importerAnnee(
      idAnnee: 4,
      campusIds: {'CMP001'},
      sansEtudiants: const {},
    );

    final db = BaseLocale.instance.db;
    final accountancy = await db.rawQuery(
      "SELECT intitule, COUNT(*) c FROM specialite "
      "WHERE campus_id = 'CMP001' AND intitule LIKE 'ACCOUNTANCY%' "
      "GROUP BY intitule",
    );
    for (final l in accountancy) {
      expect(l['c'], 1, reason: '« ${l['intitule']} » est en double');
    }

    // Aucun intitulé ne doit apparaître deux fois, quelle que soit la
    // filière.
    final doublons = await db.rawQuery(
      "SELECT intitule FROM specialite WHERE campus_id = 'CMP001' "
      "GROUP BY intitule COLLATE NOCASE HAVING COUNT(*) > 1",
    );
    expect(doublons, isEmpty,
        reason: 'spécialités en double : '
            '${doublons.map((l) => l['intitule']).join(', ')}');

    // Le jour et le soir restent bien distincts.
    final periodes = await db.rawQuery(
      "SELECT COUNT(*) c FROM specialite WHERE campus_id = 'CMP001' "
      "AND intitule LIKE '%(soir)'",
    );
    expect(periodes.first['c'], greaterThan(0),
        reason: 'les promotions du soir doivent rester séparées');
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('les matières portent le code du module INSAM', () async {
    final promo = await promotionTemoin();
    await MagasinInsam.instance.importerPromotion(promo,
        campusIds: {'CMP001'}, sansEtudiants: const {});

    final db = BaseLocale.instance.db;
    // « BASE DE DONNEES ET SQL » relève du module IGL234.
    final bds = await db.rawQuery(
      "SELECT code FROM matiere WHERE intitule = 'BASE DE DONNEES ET SQL'",
    );
    expect(bds.first['code'], 'IGL234');

    // Un module regroupe plusieurs matières : le code est partagé, et
    // c'est le fonctionnement attendu.
    final memeModule = await db.rawQuery(
      "SELECT COUNT(*) c FROM matiere WHERE code = 'IGL234'",
    );
    expect(memeModule.first['c'], greaterThan(1));
  });

  test('l\'import d\'une année n\'ajoute que les écarts', () async {
    final premier = await MagasinInsam.instance.importerAnnee(
      idAnnee: 4,
      campusIds: {'CMP001'},
      sansEtudiants: const {},
    );
    expect(premier.etudiantsAjoutes, greaterThan(0));

    // Rejoué à l'identique, l'import ne doit plus rien écrire : c'est ce
    // qui rend l'opération répétable après chaque export d'INSAM.
    final second = await MagasinInsam.instance.importerAnnee(
      idAnnee: 4,
      campusIds: {'CMP001'},
      sansEtudiants: const {},
    );
    expect(second.etudiantsAjoutes, 0);
    expect(second.matieresAjoutees, 0);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
