/// Accès au référentiel INSAM : la copie hors ligne des identifiants du
/// système central, servant à produire des exports que celui-ci importe
/// sans retouche.
library;

import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'modeles.dart';

/// Une promotion telle qu'INSAM la conçoit.
///
/// Chez eux, la « spécialité » porte déjà le niveau, l'année et la
/// période : c'est donc l'équivalent exact de notre [Niveau], et non de
/// notre [Specialite].
class PromotionInsam {
  final int idSpecialite;
  final int idAnnee;
  final int idNiveau;
  final String code;
  final String intitule;
  final String periode;
  final String intituleAnnee;
  final String intituleFiliere;
  final String codeCycle;
  final int nombreEtudiants;
  final int nombreMatieres;

  const PromotionInsam({
    required this.idSpecialite,
    required this.idAnnee,
    required this.idNiveau,
    required this.code,
    required this.intitule,
    required this.periode,
    required this.intituleAnnee,
    required this.intituleFiliere,
    required this.codeCycle,
    required this.nombreEtudiants,
    required this.nombreMatieres,
  });

  /// Libellé complet : « GENIE LOGICIEL — NIVEAU 2 — jour (2025/2026) ».
  String get libelle =>
      '$intitule — NIVEAU $idNiveau — $periode ($intituleAnnee)';

  /// Palier correspondant chez nous, déduit du cycle et du niveau INSAM.
  ///
  /// INSAM raisonne en cycle (BTS, Licence, Master) + niveau 1 à 5 ;
  /// nous en palier unique. La correspondance n'est pas bijective : un
  /// BTS niveau 1 est un BTS 1, mais un niveau 3 en cycle BTS n'existe
  /// pas dans notre barème et retombe sur la licence.
  Palier get palier {
    switch (codeCycle.toUpperCase()) {
      case 'MASTER':
        return idNiveau <= 4 ? Palier.master1 : Palier.master2;
      case 'LICENCE':
        return Palier.licence;
      default: // BTS, HND
        if (idNiveau <= 1) return Palier.bts1;
        if (idNiveau == 2) return Palier.bts2;
        return Palier.licence;
    }
  }
}

/// Un étudiant du référentiel, avec son identifiant INSAM.
class EtudiantInsam {
  final int id;
  final String matricule;
  final String nom;
  final String prenom;
  final String sexe;

  const EtudiantInsam({
    required this.id,
    required this.matricule,
    required this.nom,
    required this.prenom,
    required this.sexe,
  });

  /// Nom complet tel que nous le stockons, en une seule chaîne.
  String get nomComplet =>
      prenom.trim().isEmpty ? nom.trim() : '${nom.trim()} ${prenom.trim()}';

  /// INSAM ne renseigne pas systématiquement le sexe ; on retient M par
  /// défaut, l'utilisateur pourra corriger dans la fiche étudiant.
  Sexe get sexeModele =>
      sexe.trim().toUpperCase().startsWith('F') ? Sexe.f : Sexe.m;
}

/// Une matière du référentiel, rattachée à une promotion.
class MatiereInsam {
  final int id;
  final String code;
  final String intitule;
  final int semestre;

  const MatiereInsam({
    required this.id,
    required this.code,
    required this.intitule,
    required this.semestre,
  });
}

/// Base de référence embarquée, ouverte en lecture seule.
///
/// Elle est produite hors ligne par `outils/convertir_dump.py` à partir
/// du dump MySQL d'INSAM, et n'est jamais modifiée par l'application :
/// nos données vivent dans `estuaire.db`, celle-ci ne sert qu'à retrouver
/// les identifiants attendus par le système central.
class ReferentielInsam {
  static final ReferentielInsam instance = ReferentielInsam._();
  ReferentielInsam._();

  Database? _db;
  String? _chemin;

  bool get estDisponible => _db != null;

  /// Emplacement du référentiel sur le disque.
  ///
  /// Il n'est plus embarqué dans l'application : c'est l'administrateur
  /// qui fournit le dump SQL d'INSAM, converti ici même. L'application
  /// démarre donc sans référentiel, jusqu'au premier import.
  Future<String> chemin() async {
    final connu = _chemin;
    if (connu != null) return connu;
    final dossier = await getApplicationSupportDirectory();
    await dossier.create(recursive: true);
    return _chemin = p.join(dossier.path, 'insam_reference.db');
  }

  /// Ouvre le référentiel s'il a déjà été constitué.
  ///
  /// Ne fait rien s'il n'existe pas : l'absence de référentiel n'est pas
  /// une erreur, seulement un import qui reste à faire.
  Future<void> ouvrir() async {
    if (_db != null) return;

    final destination = await chemin();
    if (!await File(destination).exists()) return;

    _db = await databaseFactory.openDatabase(
      destination,
      options: OpenDatabaseOptions(readOnly: true),
    );
  }

  /// Rouvre le référentiel après sa reconstruction depuis un dump.
  Future<void> recharger() async {
    await fermer();
    await ouvrir();
  }

  /// Ouvre le référentiel depuis un fichier déjà présent sur le disque.
  /// Réservé aux tests, où `rootBundle` n'est pas disponible.
  @visibleForTesting
  Future<void> ouvrirPourTest(String chemin) async {
    await fermer();
    _db = await databaseFactory.openDatabase(
      chemin,
      options: OpenDatabaseOptions(readOnly: true),
    );
  }

  Future<void> fermer() async {
    await _db?.close();
    _db = null;
  }

  Database get _base {
    final base = _db;
    if (base == null) {
      throw StateError('Le référentiel INSAM n\'est pas ouvert.');
    }
    return base;
  }

  /// Années académiques, la plus récente d'abord.
  Future<List<({int id, String intitule})>> annees() async {
    final lignes = await _base.query('annee', orderBy: 'id_annee DESC');
    return lignes
        .map((l) => (
              id: l['id_annee'] as int,
              intitule: l['intitule_annee'] as String,
            ))
        .toList();
  }

  /// Promotions d'une année, avec leurs effectifs.
  ///
  /// Les sous-requêtes de comptage évitent un aller-retour par promotion :
  /// l'écran d'import affiche directement « 76 étudiants, 23 matières ».
  Future<List<PromotionInsam>> promotions(int idAnnee) async {
    final lignes = await _base.rawQuery('''
      SELECT s.id_specialite, s.id_annee, s.id_niveau, s.code_specialite,
             s.intitule_specialite, s.periode_specialite,
             a.intitule_annee, f.intitule_filiere, c.code_cycle,
             (SELECT COUNT(*) FROM inscrire i
               WHERE i.id_specialite = s.id_specialite
                 AND i.id_annee = s.id_annee) AS n_etudiants,
             (SELECT COUNT(*) FROM appartenir ap
               WHERE ap.id_specialite = s.id_specialite
                 AND ap.id_annee = s.id_annee) AS n_matieres
        FROM specialite s
        JOIN annee a ON a.id_annee = s.id_annee
        LEFT JOIN filiere f ON f.id_filiere = s.id_filiere
        LEFT JOIN cycle c ON c.id_cycle = f.id_cycle
       WHERE s.id_annee = ?
       ORDER BY f.intitule_filiere, s.intitule_specialite, s.periode_specialite
    ''', [idAnnee]);

    return lignes
        .map((l) => PromotionInsam(
              idSpecialite: l['id_specialite'] as int,
              idAnnee: l['id_annee'] as int,
              idNiveau: l['id_niveau'] as int,
              code: (l['code_specialite'] as String?) ?? '',
              intitule: (l['intitule_specialite'] as String?) ?? '',
              periode: (l['periode_specialite'] as String?) ?? '',
              intituleAnnee: (l['intitule_annee'] as String?) ?? '',
              intituleFiliere: (l['intitule_filiere'] as String?) ?? '',
              codeCycle: (l['code_cycle'] as String?) ?? 'BTS',
              nombreEtudiants: l['n_etudiants'] as int,
              nombreMatieres: l['n_matieres'] as int,
            ))
        .toList();
  }

  /// Année académique d'une spécialité INSAM.
  ///
  /// L'export a besoin de `id_annee`, que la promotion importée porte
  /// déjà : plutôt que de demander l'année à l'utilisateur et risquer un
  /// écart, on la relit ici.
  Future<({int id, String intitule})?> anneeDeSpecialite(
      int idSpecialite) async {
    final lignes = await _base.rawQuery('''
      SELECT a.id_annee, a.intitule_annee
        FROM specialite s
        JOIN annee a ON a.id_annee = s.id_annee
       WHERE s.id_specialite = ?
       LIMIT 1
    ''', [idSpecialite]);
    if (lignes.isEmpty) return null;
    return (
      id: lignes.first['id_annee'] as int,
      intitule: lignes.first['intitule_annee'] as String,
    );
  }

  /// Étudiants inscrits dans une promotion.
  Future<List<EtudiantInsam>> etudiants(PromotionInsam promo) async {
    final lignes = await _base.rawQuery('''
      SELECT e.id_etudiant, e.matricule_etudiant, e.nom_etudiant,
             e.prenom_etudiant, e.sexe_etudiant
        FROM inscrire i
        JOIN etudiant e ON e.id_etudiant = i.id_etudiant
       WHERE i.id_specialite = ? AND i.id_annee = ?
       ORDER BY e.nom_etudiant COLLATE NOCASE
    ''', [promo.idSpecialite, promo.idAnnee]);

    return lignes
        .map((l) => EtudiantInsam(
              id: l['id_etudiant'] as int,
              matricule: (l['matricule_etudiant'] as String?) ?? '',
              nom: (l['nom_etudiant'] as String?) ?? '',
              prenom: (l['prenom_etudiant'] as String?) ?? '',
              sexe: (l['sexe_etudiant'] as String?) ?? '',
            ))
        .toList();
  }

  /// Matières au programme d'une promotion.
  ///
  /// Le code retenu est celui du **module** (« IGL234 ») : c'est le code
  /// officiel du cursus chez INSAM, celui qui figure sur les documents.
  /// Un module regroupe plusieurs matières — « IGL234 » couvre à la fois
  /// BDS et SDA — donc plusieurs matières partagent le même code, et
  /// c'est normal.
  Future<List<MatiereInsam>> matieres(PromotionInsam promo) async {
    final lignes = await _base.rawQuery('''
      SELECT m.id_matiere,
             COALESCE(mo.code_module, ap.code_matiere) AS code_matiere,
             m.intitule_matiere, ap.semestre_matiere
        FROM appartenir ap
        JOIN matiere m ON m.id_matiere = ap.id_matiere
        LEFT JOIN module mo ON mo.id_module = ap.id_module
       WHERE ap.id_specialite = ? AND ap.id_annee = ?
       ORDER BY ap.semestre_matiere, m.intitule_matiere COLLATE NOCASE
    ''', [promo.idSpecialite, promo.idAnnee]);

    return lignes
        .map((l) => MatiereInsam(
              id: l['id_matiere'] as int,
              code: (l['code_matiere'] as String?) ?? '',
              intitule: (l['intitule_matiere'] as String?) ?? '',
              semestre: (l['semestre_matiere'] as int?) ?? 1,
            ))
        .toList();
  }
}
