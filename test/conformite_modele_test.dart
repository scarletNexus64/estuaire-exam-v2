import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:estuaire_examen/data/base_locale.dart';
import 'package:estuaire_examen/data/magasin.dart';
import 'package:estuaire_examen/data/magasin_campus.dart';
import 'package:estuaire_examen/data/magasin_epreuves.dart';
import 'package:estuaire_examen/data/magasin_insam.dart';
import 'package:estuaire_examen/data/magasin_sessions.dart';
import 'package:estuaire_examen/data/modeles.dart';
import 'package:estuaire_examen/data/referentiel_insam.dart';

import 'aide_referentiel.dart';
import 'package:estuaire_examen/documents/export_notes_insam.dart';

/// Confronte le fichier produit au modèle fourni par INSAM.
///
/// C'est le test qui compte : si la structure diverge, leur import
/// échoue, et aucun autre contrôle ne le rattraperait.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const modele = 'assets/templates/Examen De Controle Continu En BASE DE '
      'DONNEES ET SQL Pour GENIE LOGICIEL En NIVEAU 2.xlsx';

  late Directory dossier;

  setUp(() async {
    dossier = await Directory.systemTemp.createTemp('estuaire-conformite');
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

  test('l\'export reproduit la structure du modèle INSAM', () async {
    // ----- La promotion du modèle, importée pour de vrai -----
    final promo = (await ReferentielInsam.instance.promotions(4))
        .firstWhere((p) => p.idSpecialite == 1251);
    await MagasinInsam.instance.importerPromotion(promo);

    final matiere = Magasin.instance.matieres.firstWhere(
        (m) => m.intitule == 'BASE DE DONNEES ET SQL');

    // Une épreuve de contrôle continu, comme celle du modèle.
    final debut = DateTime(2026, 8, 5, 9);
    final db = BaseLocale.instance.db;
    await db.insert('epreuve', {
      'id': 'EPR001',
      'titre': 'Contrôle continu',
      'consignes': '',
      'matiere_id': matiere.id,
      'debut': debut.toIso8601String(),
      'duree_minutes': 60,
      'code_acces': 'CONF01',
      'etat': 'terminee',
      'nature': 'controleContinu',
    });
    await MagasinEpreuves.instance.charger();
    await MagasinSessions.instance.charger();

    final export = await ExportNotesInsam.generer(
      matiere: matiere,
      nature: NatureEpreuve.controleContinu,
      dateEpreuve: debut,
    );

    // ----- Le modèle de référence -----
    final attendu = Excel.decodeBytes(await File(modele).readAsBytes());
    final feuilleAttendue = attendu.tables[attendu.tables.keys.first]!;

    final obtenu = Excel.decodeBytes(export.octets);
    final feuilleObtenue = obtenu.tables[obtenu.tables.keys.first]!;

    String? texte(List<Data?> ligne, int i) =>
        i < ligne.length ? ligne[i]?.value?.toString() : null;

    // Les en-têtes, au caractère près.
    final enTetesAttendus = [
      for (var i = 0; i < 9; i++) texte(feuilleAttendue.rows.first, i),
    ];
    final enTetesObtenus = [
      for (var i = 0; i < 9; i++) texte(feuilleObtenue.rows.first, i),
    ];
    expect(enTetesObtenus, enTetesAttendus);

    // Le même effectif : 76 étudiants, donc 77 lignes avec l'en-tête.
    expect(feuilleObtenue.rows.length, feuilleAttendue.rows.length);
    expect(export.total, 76);

    // Chaque étudiant du modèle se retrouve, avec le même identifiant.
    final attendus = <String, String?>{};
    for (var i = 1; i < feuilleAttendue.rows.length; i++) {
      final l = feuilleAttendue.rows[i];
      final id = texte(l, 1);
      if (id != null) attendus[id] = texte(l, 5);
    }

    final obtenus = <String, String?>{};
    for (var i = 1; i < feuilleObtenue.rows.length; i++) {
      final l = feuilleObtenue.rows[i];
      final id = texte(l, 1);
      if (id != null) obtenus[id] = texte(l, 5);
    }

    expect(obtenus.keys.toSet(), attendus.keys.toSet(),
        reason: 'les identifiants étudiants doivent être identiques');

    // Colonnes constantes : matière, examen, année.
    for (var i = 1; i < feuilleObtenue.rows.length; i++) {
      final l = feuilleObtenue.rows[i];
      expect(texte(l, 0), isNull, reason: 'id_composer reste vide');
      expect(texte(l, 2), '421', reason: 'BASE DE DONNEES ET SQL');
      expect(texte(l, 3), '1', reason: 'contrôle continu');
      expect(texte(l, 4), '4', reason: '2025/2026');
      expect(texte(l, 8), '2026-08-05');
      // Personne n'a composé : toutes les notes sont vides, comme dans
      // le modèle qu'INSAM nous remet à remplir.
      expect(texte(l, 7), isNull);
    }
  });
}
