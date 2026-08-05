import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Accès à la base SQLite locale.
///
/// Un seul fichier `estuaire.db` dans le dossier de support de l'application :
/// tout est hors ligne, et la sauvegarde revient à copier ce fichier.
class BaseLocale {
  static final BaseLocale instance = BaseLocale._();
  BaseLocale._();

  static const _versionSchema = 2;
  static const _nomFichier = 'estuaire.db';

  Database? _db;
  String? _chemin;

  Database get db {
    final base = _db;
    if (base == null) {
      throw StateError('La base locale n\'est pas ouverte.');
    }
    return base;
  }

  /// Chemin du fichier de base ; utile pour l'export et l'écran système.
  String get chemin => _chemin ?? '—';

  bool get estOuverte => _db != null;

  /// Prépare le moteur SQLite pour le bureau et ouvre la base.
  /// À appeler une seule fois, avant `runApp`.
  Future<void> ouvrir() async {
    if (_db != null) return;

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dossier = await getApplicationSupportDirectory();
    await dossier.create(recursive: true);
    _chemin = p.join(dossier.path, _nomFichier);

    _db = await databaseFactory.openDatabase(
      _chemin!,
      options: OpenDatabaseOptions(
        version: _versionSchema,
        onConfigure: (db) async {
          // Indispensable : sans ça SQLite ignore les clés étrangères.
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async => _creerSchema(db),
        onUpgrade: (db, ancienne, nouvelle) async {
          if (ancienne < 2) await _creerCorrespondanceInsam(db);
        },
      ),
    );
  }

  /// Ouvre une base à un emplacement imposé, sans passer par le dossier
  /// système. Réservé aux tests, où `path_provider` n'est pas disponible.
  @visibleForTesting
  Future<void> ouvrirPourTest(String chemin) async {
    await fermer();
    _chemin = chemin;
    _db = await databaseFactory.openDatabase(
      chemin,
      options: OpenDatabaseOptions(
        version: _versionSchema,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async => _creerSchema(db),
      ),
    );
  }

  Future<void> fermer() async {
    await _db?.close();
    _db = null;
  }

  /// Ferme, remplace le fichier de base par [source], puis rouvre.
  /// Utilisé par l'import ; la base précédente est perdue.
  Future<void> remplacerPar(File source) async {
    final destination = _chemin;
    if (destination == null) {
      throw StateError('La base locale n\'est pas ouverte.');
    }
    await fermer();
    await source.copy(destination);
    _db = await databaseFactory.openDatabase(
      destination,
      options: OpenDatabaseOptions(
        version: _versionSchema,
        onConfigure: (db) async =>
            db.execute('PRAGMA foreign_keys = ON'),
      ),
    );
  }

  /// Copie le fichier de base vers [destination] (export).
  Future<void> exporterVers(String destination) async {
    final origine = _chemin;
    if (origine == null) {
      throw StateError('La base locale n\'est pas ouverte.');
    }
    // Vide le journal WAL dans le fichier principal, sinon la copie
    // pourrait ne pas contenir les dernières écritures.
    await db.execute('PRAGMA wal_checkpoint(FULL)');
    await File(origine).copy(destination);
  }

  /// Vide toutes les données académiques et pédagogiques.
  ///
  /// Ce qui subsiste : la structure des annexes et des campus — elle est
  /// posée à la création de la base, pas saisie — les paramètres de
  /// l'établissement, et les comptes super administrateur, sans lesquels
  /// plus personne ne pourrait se connecter.
  ///
  /// Sert à repartir d'une base propre avant un import INSAM, quand les
  /// données précédentes proviennent d'un référentiel devenu obsolète.
  Future<void> reinitialiser() async {
    await db.transaction((txn) async {
      // Ordre imposé par les clés étrangères, des feuilles vers la racine.
      for (final table in const [
        'reponse',
        'session_examen',
        'proposition',
        'question',
        'epreuve',
        'affectation',
        'etudiant',
        'matiere',
        'niveau',
        'specialite',
        'correspondance_insam',
      ]) {
        await txn.delete(table);
      }
      await txn.delete('utilisateur', where: 'role <> ?', whereArgs: ['super_admin']);
    });
    // Le fichier garde sa taille tant qu'on ne le compacte pas ; VACUUM
    // ne peut pas s'exécuter dans une transaction.
    await db.execute('VACUUM');
  }

  /// Taille du fichier de base, en octets.
  Future<int> taille() async {
    final chemin = _chemin;
    if (chemin == null) return 0;
    final fichier = File(chemin);
    return await fichier.exists() ? fichier.length() : 0;
  }

  // ---------- Schéma ----------

  Future<void> _creerSchema(Database db) async {
    // Annexe : « Campus annexe de Bafoussam », « ... de Mbouda ».
    await db.execute('''
      CREATE TABLE annexe (
        id       TEXT PRIMARY KEY,
        intitule TEXT NOT NULL,
        ordre    INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Campus rattaché à une annexe : « CAMPUS A », « CAMPUS DE MAKAMBOU ».
    // C'est l'unité de travail : on s'y connecte, et les données y vivent.
    await db.execute('''
      CREATE TABLE campus (
        id        TEXT PRIMARY KEY,
        annexe_id TEXT NOT NULL REFERENCES annexe(id) ON DELETE CASCADE,
        intitule  TEXT NOT NULL,
        ordre     INTEGER NOT NULL DEFAULT 0,
        -- En-tête propre au campus, stocké dans la base plutôt que sur
        -- disque : l'export reste un seul fichier .db transportable.
        entete    BLOB
      )
    ''');

    // La spécialité porte le campus : promotions, matières et étudiants
    // en héritent par leur chaîne de rattachement.
    await db.execute('''
      CREATE TABLE specialite (
        id           TEXT PRIMARY KEY,
        campus_id    TEXT NOT NULL REFERENCES campus(id) ON DELETE CASCADE,
        abreviation  TEXT NOT NULL,
        intitule     TEXT NOT NULL,
        responsable  TEXT NOT NULL DEFAULT ''
      )
    ''');

    // palier : indice de l'enum Palier (0 = BTS 1 … 4 = Master 2).
    // La contrainte d'unicité empêche d'ouvrir deux fois le même palier.
    await db.execute('''
      CREATE TABLE niveau (
        id            TEXT PRIMARY KEY,
        specialite_id TEXT NOT NULL
                      REFERENCES specialite(id) ON DELETE CASCADE,
        palier        INTEGER NOT NULL,
        UNIQUE (specialite_id, palier)
      )
    ''');

    await db.execute('''
      CREATE TABLE matiere (
        id        TEXT PRIMARY KEY,
        code      TEXT NOT NULL,
        intitule  TEXT NOT NULL,
        niveau_id TEXT NOT NULL REFERENCES niveau(id) ON DELETE CASCADE,
        semestre  INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE etudiant (
        id          TEXT PRIMARY KEY,
        matricule   TEXT NOT NULL,
        nom_complet TEXT NOT NULL,
        sexe        TEXT NOT NULL CHECK (sexe IN ('M', 'F')),
        niveau_id   TEXT NOT NULL REFERENCES niveau(id) ON DELETE CASCADE,
        actif       INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE utilisateur (
        id           TEXT PRIMARY KEY,
        identifiant  TEXT NOT NULL UNIQUE COLLATE NOCASE,
        mot_de_passe TEXT NOT NULL,
        nom_complet  TEXT NOT NULL,
        role         TEXT NOT NULL CHECK (role IN ('super_admin', 'enseignant')),
        actif        INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Matières confiées à un enseignant.
    await db.execute('''
      CREATE TABLE affectation (
        utilisateur_id TEXT NOT NULL
                       REFERENCES utilisateur(id) ON DELETE CASCADE,
        matiere_id     TEXT NOT NULL
                       REFERENCES matiere(id) ON DELETE CASCADE,
        PRIMARY KEY (utilisateur_id, matiere_id)
      )
    ''');

    // Paramètres de l'établissement, en clé/valeur : campus, année
    // académique… Ce qui figure sur les documents officiels mais ne
    // dépend d'aucune autre table.
    await db.execute('''
      CREATE TABLE parametre (
        cle    TEXT PRIMARY KEY,
        valeur TEXT NOT NULL DEFAULT ''
      )
    ''');

    // ----- Épreuves -----

    await db.execute('''
      CREATE TABLE epreuve (
        id                     TEXT PRIMARY KEY,
        titre                  TEXT NOT NULL,
        consignes              TEXT NOT NULL DEFAULT '',
        matiere_id             TEXT NOT NULL
                               REFERENCES matiere(id) ON DELETE CASCADE,
        auteur_id              TEXT REFERENCES utilisateur(id) ON DELETE SET NULL,
        debut                  TEXT,
        duree_minutes          INTEGER NOT NULL DEFAULT 60,
        code_acces             TEXT NOT NULL UNIQUE COLLATE NOCASE,
        melanger_questions     INTEGER NOT NULL DEFAULT 0,
        melanger_propositions  INTEGER NOT NULL DEFAULT 0,
        etat                   TEXT NOT NULL DEFAULT 'brouillon',
        -- Colonne de la fiche de report où la note atterrit.
        nature                 TEXT NOT NULL DEFAULT 'controleContinu'
      )
    ''');

    await db.execute('''
      CREATE TABLE question (
        id         TEXT PRIMARY KEY,
        epreuve_id TEXT NOT NULL REFERENCES epreuve(id) ON DELETE CASCADE,
        enonce     TEXT NOT NULL,
        type       TEXT NOT NULL,
        points     REAL NOT NULL DEFAULT 1,
        ordre      INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE proposition (
        id          TEXT PRIMARY KEY,
        question_id TEXT NOT NULL REFERENCES question(id) ON DELETE CASCADE,
        texte       TEXT NOT NULL,
        correcte    INTEGER NOT NULL DEFAULT 0,
        ordre       INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Une copie par étudiant, par épreuve et par passation. La passation
    // porte la date d'ouverture : replanifier une épreuve crée de
    // nouvelles copies sans écraser les précédentes.
    await db.execute('''
      CREATE TABLE session_examen (
        id          TEXT PRIMARY KEY,
        epreuve_id  TEXT NOT NULL REFERENCES epreuve(id) ON DELETE CASCADE,
        etudiant_id TEXT NOT NULL REFERENCES etudiant(id) ON DELETE CASCADE,
        passation   TEXT NOT NULL DEFAULT '',
        debut       TEXT NOT NULL,
        derniere_vue TEXT,
        soumise_le  TEXT,
        note        REAL,
        -- Secret remis au navigateur : sans lui, connaître l'identifiant
        -- de session ne permet pas d'agir dessus.
        jeton       TEXT NOT NULL DEFAULT '',
        annulee     INTEGER NOT NULL DEFAULT 0,
        UNIQUE (epreuve_id, etudiant_id, passation)
      )
    ''');

    // Réponses enregistrées au fil de l'eau, pour ne rien perdre.
    await db.execute('''
      CREATE TABLE reponse (
        session_id     TEXT NOT NULL
                       REFERENCES session_examen(id) ON DELETE CASCADE,
        question_id    TEXT NOT NULL REFERENCES question(id) ON DELETE CASCADE,
        proposition_id TEXT NOT NULL
                       REFERENCES proposition(id) ON DELETE CASCADE,
        PRIMARY KEY (session_id, question_id, proposition_id)
      )
    ''');

    await _creerCorrespondanceInsam(db);

    // Index sur les colonnes de jointure et de filtre les plus sollicitées.
    await db.execute('CREATE INDEX idx_campus_annexe ON campus(annexe_id)');
    await db.execute(
        'CREATE INDEX idx_specialite_campus ON specialite(campus_id)');
    await db.execute(
        'CREATE INDEX idx_niveau_specialite ON niveau(specialite_id)');
    await db.execute('CREATE INDEX idx_matiere_niveau ON matiere(niveau_id)');
    await db.execute('CREATE INDEX idx_etudiant_niveau ON etudiant(niveau_id)');
    await db.execute(
        'CREATE INDEX idx_etudiant_matricule ON etudiant(matricule)');
    await db.execute('CREATE INDEX idx_etudiant_nom ON etudiant(nom_complet)');
    await db.execute('CREATE INDEX idx_epreuve_matiere ON epreuve(matiere_id)');
    await db.execute('CREATE INDEX idx_question_epreuve ON question(epreuve_id)');
    await db.execute(
        'CREATE INDEX idx_proposition_question ON proposition(question_id)');
    await db.execute(
        'CREATE INDEX idx_session_epreuve ON session_examen(epreuve_id)');
    await db.execute('CREATE INDEX idx_reponse_session ON reponse(session_id)');

    await _semer(db);
  }

  /// Table de correspondance avec les identifiants du système INSAM.
  ///
  /// Nos identifiants sont des chaînes (`ETU001`), ceux d'INSAM des
  /// entiers auto-incrémentés (`22713`) : les deux bases ne partagent
  /// aucune clé. Plutôt que d'ajouter une colonne à chaque table — ce qui
  /// imposerait de migrer tout le schéma — on isole la correspondance
  /// ici. Aucune clé étrangère : une entité peut être supprimée sans que
  /// la migration échoue, et le nettoyage se fait à l'import suivant.
  Future<void> _creerCorrespondanceInsam(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS correspondance_insam (
        entite     TEXT NOT NULL,
        id_local   TEXT NOT NULL,
        id_distant INTEGER NOT NULL,
        PRIMARY KEY (entite, id_local)
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_correspondance_distant '
        'ON correspondance_insam(entite, id_distant)');
  }

  // ---------- Compte initial ----------

  /// Aucune donnée académique n'est pré-remplie : la base démarre vide.
  /// Seuls la structure des campus et le compte administrateur sont créés,
  /// sans lui personne ne pourrait se connecter pour saisir les données.
  Future<void> _semer(Database db) async {
    final lot = db.batch();

    void annexe(String id, String intitule, int ordre) {
      lot.insert('annexe', {'id': id, 'intitule': intitule, 'ordre': ordre});
    }

    void campus(String id, String annexeId, String intitule, int ordre) {
      lot.insert('campus', {
        'id': id,
        'annexe_id': annexeId,
        'intitule': intitule,
        'ordre': ordre,
      });
    }

    annexe('ANX001', 'Campus annexe de Bafoussam', 1);
    campus('CMP001', 'ANX001', 'CAMPUS A', 1);
    campus('CMP002', 'ANX001', 'CAMPUS B', 2);
    campus('CMP003', 'ANX001', 'CAMPUS C', 3);
    campus('CMP004', 'ANX001', 'CAMPUS D', 4);
    campus('CMP005', 'ANX001', 'CAMPUS E', 5);
    campus('CMP006', 'ANX001', 'CAMPUS DE MAKAMBOU', 6);

    annexe('ANX002', 'Campus annexe de Mbouda', 2);
    campus('CMP007', 'ANX002', 'CAMPUS DE BAMBOUTOS', 1);

    await lot.commit(noResult: true);

    await db.insert('utilisateur', {
      'id': 'USR001',
      'identifiant': 'admin',
      'mot_de_passe': 'admin',
      'nom_complet': 'Administrateur',
      'role': 'super_admin',
      'actif': 1,
    });
  }
}
