import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'base_locale.dart';
import 'magasin_epreuves.dart';
import 'modeles.dart';

/// Une copie d'étudiant en cours ou terminée.
class SessionExamen {
  final String id;
  final String epreuveId;
  final String etudiantId;

  /// Date d'ouverture de l'épreuve au moment de la composition.
  /// Distingue deux passations successives de la même épreuve.
  final String passation;

  /// Début personnel : le chronomètre part de là, pas de l'heure d'ouverture.
  final DateTime debut;
  DateTime? derniereVue;
  DateTime? soumiseLe;
  double? note;

  /// Propositions cochées, par question.
  Map<String, Set<String>> reponses;

  /// Incidents relevés pendant la composition (sortie de page, copie…).
  int alertes;

  /// Copie annulée pour fraude : note à zéro, plus de reprise possible.
  bool annulee;

  /// Secret partagé avec le navigateur de l'étudiant.
  /// Toute écriture doit le présenter : les identifiants étant
  /// séquentiels, ils ne peuvent pas servir d'autorisation.
  String jeton;

  SessionExamen({
    required this.id,
    required this.epreuveId,
    required this.etudiantId,
    required this.debut,
    this.passation = '',
    this.derniereVue,
    this.soumiseLe,
    this.note,
    Map<String, Set<String>>? reponses,
    this.alertes = 0,
    this.annulee = false,
    this.jeton = '',
  }) : reponses = reponses ?? {};

  bool get estSoumise => soumiseLe != null;

  /// Temps restant, calculé côté serveur : fermer l'onglet ne rend pas
  /// de temps à l'étudiant.
  Duration restant(int dureeMinutes) {
    final fin = debut.add(Duration(minutes: dureeMinutes));
    final reste = fin.difference(DateTime.now());
    return reste.isNegative ? Duration.zero : reste;
  }

  bool tempsEcoule(int dureeMinutes) =>
      restant(dureeMinutes) == Duration.zero;

  /// Considéré présent si un signe de vie a été reçu récemment.
  bool get enLigne {
    final vue = derniereVue;
    if (vue == null) return false;
    return DateTime.now().difference(vue).inSeconds < 30;
  }
}

/// Sessions de composition : ouverture, réponses, soumission et correction.
class MagasinSessions extends ChangeNotifier {
  static final MagasinSessions instance = MagasinSessions._();
  MagasinSessions._();

  Database get _db => BaseLocale.instance.db;

  final List<SessionExamen> sessions = [];

  Future<void> charger() async {
    final lignes = await _db.query('session_examen');
    final reponses = await _db.query('reponse');

    final parSession = <String, Map<String, Set<String>>>{};
    for (final r in reponses) {
      parSession
          .putIfAbsent(r['session_id'] as String, () => {})
          .putIfAbsent(r['question_id'] as String, () => {})
          .add(r['proposition_id'] as String);
    }

    sessions
      ..clear()
      ..addAll(lignes.map((l) {
        final id = l['id'] as String;
        final vue = l['derniere_vue'] as String?;
        final soumise = l['soumise_le'] as String?;
        return SessionExamen(
          id: id,
          epreuveId: l['epreuve_id'] as String,
          etudiantId: l['etudiant_id'] as String,
          passation: (l['passation'] as String?) ?? '',
          debut: DateTime.parse(l['debut'] as String),
          derniereVue: vue == null ? null : DateTime.parse(vue),
          soumiseLe: soumise == null ? null : DateTime.parse(soumise),
          note: (l['note'] as num?)?.toDouble(),
          reponses: parSession[id] ?? {},
          jeton: (l['jeton'] as String?) ?? '',
          annulee: ((l['annulee'] as int?) ?? 0) == 1,
        );
      }));

    notifyListeners();
  }

  // ---------- Lectures ----------

  List<SessionExamen> sessionsDe(String epreuveId) =>
      sessions.where((s) => s.epreuveId == epreuveId).toList();

  /// Copie d'un étudiant pour une passation donnée.
  /// Sans [passation], rend la plus récente toutes passations confondues.
  SessionExamen? sessionDe(String epreuveId, String etudiantId,
      {String? passation}) {
    final candidates = sessions
        .where((s) =>
            s.epreuveId == epreuveId &&
            s.etudiantId == etudiantId &&
            (passation == null || s.passation == passation))
        .toList()
      ..sort((a, b) => b.debut.compareTo(a.debut));
    return candidates.firstOrNull;
  }

  /// Copies d'une épreuve pour une passation précise.
  List<SessionExamen> sessionsDePassation(String epreuveId, String passation) =>
      sessions
          .where((s) => s.epreuveId == epreuveId && s.passation == passation)
          .toList();

  /// Passations connues d'une épreuve, la plus récente en premier.
  List<String> passationsDe(String epreuveId) =>
      sessionsDe(epreuveId).map((s) => s.passation).toSet().toList()
        ..sort((a, b) => b.compareTo(a));

  SessionExamen? parId(String id) =>
      sessions.where((s) => s.id == id).firstOrNull;

  // ---------- Écritures ----------

  /// Secret imprévisible : 32 caractères tirés d'une source cryptographique.
  static String _nouveauJeton() {
    final hasard = Random.secure();
    final octets = List<int>.generate(24, (_) => hasard.nextInt(256));
    return base64Url.encode(octets);
  }

  /// Vrai si le jeton correspond à celui de la session.
  /// Sans cette vérification, deviner « SES00007 » suffirait à agir sur
  /// la copie d'un camarade.
  bool jetonValide(SessionExamen s, String? jeton) =>
      jeton != null && jeton.isNotEmpty && s.jeton == jeton;

  /// Ouvre la session, ou rend celle qui existe déjà.
  /// C'est ce qui permet à l'étudiant de reprendre après une coupure.
  ///
  /// [debutEpreuve] écarte les sessions d'une session d'examen antérieure :
  /// replanifier une épreuve doit permettre de la recomposer, sinon
  /// l'étudiant se verrait resservir sa note précédente.
  Future<SessionExamen> ouvrir(
    String epreuveId,
    String etudiantId, {
    DateTime? debutEpreuve,
  }) async {
    // La passation identifie l'ouverture de l'épreuve. Replanifier crée
    // une nouvelle copie ; les précédentes restent consultables.
    //
    // À défaut de date fournie, on la lit sur l'épreuve : une copie dont
    // la passation ne correspond pas serait invisible sur la fiche.
    final passation = (debutEpreuve ??
                MagasinEpreuves.instance.epreuve(epreuveId)?.debut)
            ?.toIso8601String() ??
        '';
    final existante =
        sessionDe(epreuveId, etudiantId, passation: passation);

    if (existante != null) {
      // Session d'avant l'introduction des jetons : on lui en attribue un.
      if (existante.jeton.isEmpty) {
        final jeton = _nouveauJeton();
        await _db.update('session_examen', {'jeton': jeton},
            where: 'id = ?', whereArgs: [existante.id]);
        existante.jeton = jeton;
      }
      return existante;
    }

    final maintenant = DateTime.now();
    final r = await _db.rawQuery(
        "SELECT id FROM session_examen WHERE id LIKE 'SES%' "
        'ORDER BY id DESC LIMIT 1');
    var suivant = 1;
    if (r.isNotEmpty) {
      suivant = (int.tryParse((r.first['id'] as String).substring(3)) ?? 0) + 1;
    }
    final id = 'SES${suivant.toString().padLeft(5, '0')}';

    final jeton = _nouveauJeton();
    await _db.insert('session_examen', {
      'id': id,
      'epreuve_id': epreuveId,
      'etudiant_id': etudiantId,
      'passation': passation,
      'debut': maintenant.toIso8601String(),
      'derniere_vue': maintenant.toIso8601String(),
      'jeton': jeton,
    });

    final session = SessionExamen(
      id: id,
      epreuveId: epreuveId,
      etudiantId: etudiantId,
      passation: passation,
      debut: maintenant,
      derniereVue: maintenant,
      jeton: jeton,
    );
    sessions.add(session);
    notifyListeners();
    return session;
  }

  /// Enregistre la réponse à une question, en remplaçant la précédente.
  /// Écrit immédiatement : une coupure ne doit rien faire perdre.
  Future<void> repondre(
    SessionExamen s,
    String questionId,
    Set<String> propositionIds,
  ) async {
    if (s.estSoumise) return;

    await _db.transaction((txn) async {
      await txn.delete('reponse',
          where: 'session_id = ? AND question_id = ?',
          whereArgs: [s.id, questionId]);
      final lot = txn.batch();
      for (final p in propositionIds) {
        lot.insert('reponse', {
          'session_id': s.id,
          'question_id': questionId,
          'proposition_id': p,
        });
      }
      await lot.commit(noResult: true);
    });

    if (propositionIds.isEmpty) {
      s.reponses.remove(questionId);
    } else {
      s.reponses[questionId] = {...propositionIds};
    }
    notifyListeners();
  }

  /// Signe de vie : alimente l'indicateur « en ligne » du monitoring.
  Future<void> signalerPresence(SessionExamen s) async {
    final maintenant = DateTime.now();
    s.derniereVue = maintenant;
    await _db.update(
      'session_examen',
      {'derniere_vue': maintenant.toIso8601String()},
      where: 'id = ?',
      whereArgs: [s.id],
    );
    notifyListeners();
  }

  /// Au-delà, la copie est annulée d'office.
  static const seuilAlertes = 3;

  /// Incident de surveillance (sortie de page, tentative de copie…).
  /// Compté en mémoire : le détail vit dans le journal du serveur.
  ///
  /// Rend `true` si le seuil est atteint : l'appelant doit alors annuler
  /// la copie.
  bool signalerAlerte(SessionExamen s) {
    s.alertes++;
    notifyListeners();
    return s.alertes >= seuilAlertes;
  }

  /// Annule la copie pour fraude : note à zéro, session close.
  ///
  /// On enregistre plutôt que de supprimer : la fiche de report doit
  /// montrer un zéro, et l'enseignant garder trace de l'incident.
  Future<void> annulerPourFraude(SessionExamen s) async {
    final maintenant = DateTime.now();
    await _db.update(
      'session_examen',
      {'soumise_le': maintenant.toIso8601String(), 'note': 0.0},
      where: 'id = ?',
      whereArgs: [s.id],
    );
    await _db.update('session_examen', {'annulee': 1},
        where: 'id = ?', whereArgs: [s.id]);
    s.soumiseLe = maintenant;
    s.note = 0;
    s.annulee = true;
    notifyListeners();
  }

  /// Corrige et clôt la copie.
  ///
  /// Barème : une question est juste si l'ensemble coché correspond
  /// exactement aux bonnes réponses — pas de demi-point.
  Future<double> soumettre(SessionExamen s, Epreuve epreuve) async {
    if (s.estSoumise) return s.note ?? 0;

    var note = 0.0;
    for (final q in epreuve.questions) {
      final attendues =
          q.propositions.where((p) => p.correcte).map((p) => p.id).toSet();
      final donnees = s.reponses[q.id] ?? <String>{};
      if (attendues.isNotEmpty &&
          donnees.length == attendues.length &&
          donnees.containsAll(attendues)) {
        note += q.points;
      }
    }

    final maintenant = DateTime.now();
    await _db.update(
      'session_examen',
      {'soumise_le': maintenant.toIso8601String(), 'note': note},
      where: 'id = ?',
      whereArgs: [s.id],
    );

    s.soumiseLe = maintenant;
    s.note = note;
    notifyListeners();
    return note;
  }

  /// Clôt l'épreuve : toutes les copies encore ouvertes sont corrigées
  /// et remises en l'état.
  ///
  /// Sert quand tout le monde a terminé avant l'heure : sans cela les
  /// copies resteraient « en cours » jusqu'à expiration du chronomètre,
  /// et n'auraient aucune note sur la fiche de report.
  Future<int> cloturer(Epreuve epreuve) async {
    // Seule la passation en cours est concernée : les copies des
    // passations précédentes sont déjà closes et notées.
    final ouvertes = sessionsDePassation(
            epreuve.id, epreuve.debut?.toIso8601String() ?? '')
        .where((s) => !s.estSoumise);
    var remises = 0;
    for (final s in ouvertes) {
      await soumettre(s, epreuve);
      remises++;
    }
    return remises;
  }

  /// Réouvre une copie : l'enseignant accorde une seconde chance.
  Future<void> reouvrir(SessionExamen s) async {
    await _db.update(
      'session_examen',
      {'soumise_le': null, 'note': null},
      where: 'id = ?',
      whereArgs: [s.id],
    );
    s.soumiseLe = null;
    s.note = null;
    notifyListeners();
  }

  Future<void> supprimer(String id) async {
    await _db.delete('session_examen', where: 'id = ?', whereArgs: [id]);
    sessions.removeWhere((s) => s.id == id);
    notifyListeners();
  }
}
