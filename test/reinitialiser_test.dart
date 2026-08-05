import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:estuaire_examen/data/base_locale.dart';
import 'package:estuaire_examen/data/magasin.dart';
import 'package:estuaire_examen/data/magasin_campus.dart';
import 'package:estuaire_examen/data/magasin_insam.dart';
import 'package:estuaire_examen/data/modeles.dart';

/// Remise à zéro de la base depuis l'écran « Base de données ».
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory dossier;

  setUp(() async {
    dossier = await Directory.systemTemp.createTemp('estuaire-raz');
    await BaseLocale.instance.ouvrirPourTest('${dossier.path}/test.db');
    await MagasinCampus.instance.charger();
    MagasinCampus.instance.choisir(MagasinCampus.instance.parId('CMP001'));
    await Magasin.instance.charger();
  });

  tearDown(() async {
    await BaseLocale.instance.fermer();
    await dossier.delete(recursive: true);
  });

  test('vider la base efface les données mais garde le super admin',
      () async {
    final db = BaseLocale.instance.db;

    // Un jeu de données complet, jusqu'aux réponses d'une copie.
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
      'code': 'IGL234',
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
    await db.insert('utilisateur', {
      'id': 'USR002',
      'identifiant': 'kira',
      'mot_de_passe': 'x',
      'nom_complet': 'Enseignant',
      'role': 'enseignant',
      'actif': 1,
    });
    await db.insert('affectation', {
      'utilisateur_id': 'USR002',
      'matiere_id': 'MAT001',
    });
    await db.insert('correspondance_insam',
        {'entite': EntiteInsam.matiere, 'id_local': 'MAT001',
         'id_distant': 421});

    final debut = DateTime(2026, 8, 5, 9);
    await db.insert('epreuve', {
      'id': 'EPR001',
      'titre': 'Contrôle',
      'consignes': '',
      'matiere_id': 'MAT001',
      'debut': debut.toIso8601String(),
      'duree_minutes': 60,
      'code_acces': 'RAZ001',
      'etat': 'terminee',
      'nature': 'controleContinu',
    });
    await db.insert('question', {
      'id': 'QUE001',
      'epreuve_id': 'EPR001',
      'enonce': 'Question',
      'type': 'choixUnique',
      'points': 20,
      'ordre': 0,
    });
    await db.insert('proposition', {
      'id': 'PRO001',
      'question_id': 'QUE001',
      'texte': 'Vrai',
      'correcte': 1,
      'ordre': 0,
    });
    await db.insert('session_examen', {
      'id': 'SES001',
      'epreuve_id': 'EPR001',
      'etudiant_id': 'ETU001',
      'passation': debut.toIso8601String(),
      'debut': debut.toIso8601String(),
      'note': 15.0,
      'jeton': 'x',
    });
    await db.insert('reponse', {
      'session_id': 'SES001',
      'question_id': 'QUE001',
      'proposition_id': 'PRO001',
    });

    await BaseLocale.instance.reinitialiser();

    Future<int> compter(String table) async {
      final r = await db.rawQuery('SELECT COUNT(*) c FROM $table');
      return r.first['c'] as int;
    }

    for (final table in const [
      'specialite',
      'niveau',
      'matiere',
      'etudiant',
      'affectation',
      'epreuve',
      'question',
      'proposition',
      'session_examen',
      'reponse',
      'correspondance_insam',
    ]) {
      expect(await compter(table), 0, reason: '$table doit être vide');
    }

    // Le compte enseignant part, l'administrateur reste : sans lui plus
    // personne ne pourrait se connecter.
    final comptes = await db.query('utilisateur');
    expect(comptes.length, 1);
    expect(comptes.first['identifiant'], 'admin');
    expect(comptes.first['role'], 'super_admin');

    // La structure des campus survit : ce n'est pas une donnée saisie
    // mais le socle de l'application.
    expect(await compter('campus'), 7);
    expect(await compter('annexe'), 2);
  });

  test('les paramètres de l\'établissement sont conservés', () async {
    final db = BaseLocale.instance.db;
    await db.insert('parametre',
        {'cle': 'annee_academique', 'valeur': '2025-2026'});

    await BaseLocale.instance.reinitialiser();

    final restants = await db.query('parametre');
    expect(restants.length, 1);
    expect(restants.first['valeur'], '2025-2026',
        reason: 'l\'année académique ne doit pas être perdue');
  });

  test('vider une base déjà vide ne casse rien', () async {
    await BaseLocale.instance.reinitialiser();
    await BaseLocale.instance.reinitialiser();

    final comptes = await BaseLocale.instance.db.query('utilisateur');
    expect(comptes.length, 1);
  });
}
