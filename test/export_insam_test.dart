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

/// Reproduit la chaîne complète — import du référentiel puis export —
/// et compare le résultat au modèle fourni par INSAM.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory dossier;

  setUp(() async {
    dossier = await Directory.systemTemp.createTemp('estuaire-test');
    await BaseLocale.instance.ouvrirPourTest('${dossier.path}/test.db');
    await MagasinCampus.instance.charger();
    // Le vrai référentiel, tel qu'il sera embarqué : le test vaut aussi
    // vérification que la conversion du dump a produit les bons
    // identifiants.
    await ReferentielInsam.instance
        .ouvrirPourTest(await referentielDeTest());
  });

  tearDown(() async {
    await ReferentielInsam.instance.fermer();
    await BaseLocale.instance.fermer();
    await dossier.delete(recursive: true);
  });

  test('la correspondance INSAM survit à un import rejoué', () async {
    final db = BaseLocale.instance.db;

    // Deux campus, pour vérifier que chacun a sa propre copie.
    MagasinCampus.instance.choisir(MagasinCampus.instance.parId('CMP001'));
    await Magasin.instance.charger();

    // On simule un import : spécialité, promotion, matière, étudiant,
    // chacun lié à son identifiant INSAM.
    await db.insert('specialite', {
      'id': 'SPE001',
      'campus_id': 'CMP001',
      'abreviation': 'GL',
      'intitule': 'GENIE LOGICIEL',
      'responsable': '',
    });
    await db.insert('niveau', {
      'id': 'NIV001',
      'specialite_id': 'SPE001',
      'palier': Palier.bts2.index,
    });
    await db.insert('matiere', {
      'id': 'MAT001',
      'code': 'BDS',
      'intitule': 'BASE DE DONNEES ET SQL',
      'niveau_id': 'NIV001',
      'semestre': 1,
    });
    await db.insert('etudiant', {
      'id': 'ETU001',
      'matricule': '24E529',
      'nom_complet': 'ATSAYO TIOMELE MEGANE',
      'sexe': 'F',
      'niveau_id': 'NIV001',
      'actif': 1,
    });

    final insam = MagasinInsam.instance;
    await db.insert('correspondance_insam',
        {'entite': EntiteInsam.matiere, 'id_local': 'MAT001',
         'id_distant': 421});
    await db.insert('correspondance_insam',
        {'entite': EntiteInsam.etudiant, 'id_local': 'ETU001',
         'id_distant': 22713});
    await db.insert('correspondance_insam',
        {'entite': EntiteInsam.niveau, 'id_local': 'NIV001',
         'id_distant': 1251});

    expect(await insam.idDistant(EntiteInsam.matiere, 'MAT001'), 421);
    expect(await insam.idDistant(EntiteInsam.etudiant, 'ETU001'), 22713);

    final toutes = await insam.correspondances(EntiteInsam.etudiant);
    expect(toutes['ETU001'], 22713);
  });

  test('le classeur exporté reprend les colonnes du modèle INSAM',
      () async {
    final db = BaseLocale.instance.db;
    MagasinCampus.instance.choisir(MagasinCampus.instance.parId('CMP001'));

    await db.insert('specialite', {
      'id': 'SPE001',
      'campus_id': 'CMP001',
      'abreviation': 'GL',
      'intitule': 'GENIE LOGICIEL',
      'responsable': '',
    });
    await db.insert('niveau', {
      'id': 'NIV001',
      'specialite_id': 'SPE001',
      'palier': Palier.bts2.index,
    });
    await db.insert('matiere', {
      'id': 'MAT001',
      'code': 'BDS',
      'intitule': 'BASE DE DONNEES ET SQL',
      'niveau_id': 'NIV001',
      'semestre': 1,
    });
    // Deux étudiants : l'un a composé, l'autre non.
    await db.insert('etudiant', {
      'id': 'ETU001',
      'matricule': '24E529',
      'nom_complet': 'ATSAYO TIOMELE MEGANE',
      'sexe': 'F',
      'niveau_id': 'NIV001',
      'actif': 1,
    });
    await db.insert('etudiant', {
      'id': 'ETU002',
      'matricule': '24E530',
      'nom_complet': 'AWEMBE KEMAYOU MIGUEL PAVEL',
      'sexe': 'M',
      'niveau_id': 'NIV001',
      'actif': 1,
    });

    await db.insert('correspondance_insam',
        {'entite': EntiteInsam.matiere, 'id_local': 'MAT001',
         'id_distant': 421});
    await db.insert('correspondance_insam',
        {'entite': EntiteInsam.etudiant, 'id_local': 'ETU001',
         'id_distant': 22713});
    await db.insert('correspondance_insam',
        {'entite': EntiteInsam.etudiant, 'id_local': 'ETU002',
         'id_distant': 22714});
    await db.insert('correspondance_insam',
        {'entite': EntiteInsam.niveau, 'id_local': 'NIV001',
         'id_distant': 1251});

    // Une épreuve sur 40 points : la note doit ressortir ramenée sur 20.
    final debut = DateTime(2026, 8, 5, 9);
    await db.insert('epreuve', {
      'id': 'EPR001',
      'titre': 'Contrôle continu',
      'consignes': '',
      'matiere_id': 'MAT001',
      'debut': debut.toIso8601String(),
      'duree_minutes': 60,
      'code_acces': 'TEST01',
      'etat': 'terminee',
      'nature': 'controleContinu',
    });
    await db.insert('question', {
      'id': 'QUE001',
      'epreuve_id': 'EPR001',
      'enonce': 'Question',
      'type': 'choixUnique',
      'points': 40,
      'ordre': 0,
    });
    await db.insert('session_examen', {
      'id': 'SES001',
      'epreuve_id': 'EPR001',
      'etudiant_id': 'ETU001',
      'passation': debut.toIso8601String(),
      'debut': debut.toIso8601String(),
      'soumise_le': debut.toIso8601String(),
      'note': 30.0,
      'jeton': 'x',
    });

    await Magasin.instance.charger();
    await MagasinEpreuves.instance.charger();
    await MagasinSessions.instance.charger();

    final matiere = Magasin.instance.matieres.firstWhere(
        (m) => m.id == 'MAT001');

    final export = await ExportNotesInsam.generer(
      matiere: matiere,
      nature: NatureEpreuve.controleContinu,
      dateEpreuve: debut,
    );

    final classeur = Excel.decodeBytes(export.octets);
    final feuille = classeur.tables[classeur.tables.keys.first]!;

    // En-têtes : identiques au modèle, sans quoi l'import INSAM échoue.
    final entetes = feuille.rows.first
        .map((c) => c?.value?.toString() ?? '')
        .toList();
    expect(entetes, ExportNotesInsam.enTetes);

    // Première ligne de données : l'étudiant qui a composé.
    final ligne = feuille.rows[1];
    expect(ligne[0]?.value, isNull, reason: 'id_composer doit rester vide');
    expect(ligne[1]?.value?.toString(), '22713');
    expect(ligne[2]?.value?.toString(), '421');
    expect(ligne[3]?.value?.toString(), '1', reason: 'contrôle continu');
    expect(ligne[4]?.value?.toString(), '4', reason: 'année 2025/2026');
    expect(ligne[5]?.value?.toString(), 'ATSAYO TIOMELE MEGANE');
    // 30 sur un barème de 40 -> 15 sur 20.
    expect(double.parse(ligne[7]!.value.toString()), 15.0);
    expect(ligne[8]?.value?.toString(), '2026-08-05');

    // Deuxième ligne : l'absent figure bien, note vide.
    final absent = feuille.rows[2];
    expect(absent[1]?.value?.toString(), '22714');
    expect(absent[7]?.value, isNull,
        reason: 'un absent ne doit pas ressortir avec 0');

    expect(export.total, 2);
    expect(export.avecNote, 1);
    expect(export.orphelines, isEmpty);
  });
}
