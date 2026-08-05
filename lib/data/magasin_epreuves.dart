import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'base_locale.dart';
import 'modeles.dart';

/// Épreuves, questions et propositions, adossées à la base SQLite locale.
class MagasinEpreuves extends ChangeNotifier {
  static final MagasinEpreuves instance = MagasinEpreuves._();
  MagasinEpreuves._();

  Database get _db => BaseLocale.instance.db;

  final List<Epreuve> epreuves = [];

  /// Recharge les épreuves avec leurs questions et propositions.
  Future<void> charger() async {
    final lignesEpreuves = await _db.query('epreuve', orderBy: 'debut DESC');
    final lignesQuestions = await _db.query('question', orderBy: 'ordre');
    final lignesPropositions = await _db.query('proposition', orderBy: 'ordre');

    // Regroupement en mémoire : trois requêtes suffisent, inutile d'en
    // lancer une par question.
    final propositionsParQuestion = <String, List<Proposition>>{};
    for (final l in lignesPropositions) {
      propositionsParQuestion
          .putIfAbsent(l['question_id'] as String, () => [])
          .add(Proposition(
            id: l['id'] as String,
            texte: l['texte'] as String,
            correcte: (l['correcte'] as int) == 1,
            ordre: l['ordre'] as int,
          ));
    }

    final questionsParEpreuve = <String, List<Question>>{};
    for (final l in lignesQuestions) {
      final id = l['id'] as String;
      questionsParEpreuve
          .putIfAbsent(l['epreuve_id'] as String, () => [])
          .add(Question(
            id: id,
            epreuveId: l['epreuve_id'] as String,
            enonce: l['enonce'] as String,
            type: TypeQuestion.values.byName(l['type'] as String),
            points: (l['points'] as num).toDouble(),
            ordre: l['ordre'] as int,
            propositions: propositionsParQuestion[id] ?? [],
          ));
    }

    epreuves
      ..clear()
      ..addAll(lignesEpreuves.map((l) {
        final id = l['id'] as String;
        final debut = l['debut'] as String?;
        return Epreuve(
          id: id,
          titre: l['titre'] as String,
          consignes: l['consignes'] as String,
          matiereId: l['matiere_id'] as String,
          codeAcces: l['code_acces'] as String,
          debut: debut == null ? null : DateTime.parse(debut),
          dureeMinutes: l['duree_minutes'] as int,
          melangerQuestions: (l['melanger_questions'] as int) == 1,
          melangerPropositions: (l['melanger_propositions'] as int) == 1,
          etat: EtatEpreuve.values.byName(l['etat'] as String),
          nature: NatureEpreuve.values.byName(l['nature'] as String),
          questions: questionsParEpreuve[id] ?? [],
        );
      }));

    notifyListeners();
  }

  // ---------- Lectures ----------

  Epreuve? epreuve(String id) => epreuves.where((e) => e.id == id).firstOrNull;

  /// Épreuves d'une matière, la plus récente en premier.
  List<Epreuve> epreuvesDe(String matiereId) =>
      epreuves.where((e) => e.matiereId == matiereId).toList();

  /// Épreuves des matières confiées à un enseignant.
  List<Epreuve> epreuvesDeEnseignant(List<String> matiereIds) =>
      epreuves.where((e) => matiereIds.contains(e.matiereId)).toList();

  // ---------- Identifiants et codes ----------

  Future<String> _id(String prefixe, String table) async {
    final r = await _db.rawQuery(
      'SELECT id FROM $table WHERE id LIKE ? ORDER BY id DESC LIMIT 1',
      ['$prefixe%'],
    );
    var suivant = 1;
    if (r.isNotEmpty) {
      final dernier = r.first['id'] as String;
      suivant = (int.tryParse(dernier.substring(prefixe.length)) ?? 0) + 1;
    }
    return '$prefixe${suivant.toString().padLeft(4, '0')}';
  }

  /// Code d'accès court, lisible et sans ambiguïté à l'oral.
  /// Les caractères confondables (0/O, 1/I/L) sont écartés.
  Future<String> _codeAcces() async {
    const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final hasard = Random.secure();

    // Boucle bornée : en pratique une collision est très improbable.
    for (var tentative = 0; tentative < 20; tentative++) {
      final code = List.generate(
          6, (_) => alphabet[hasard.nextInt(alphabet.length)]).join();
      final existe = await _db.query('epreuve',
          where: 'code_acces = ? COLLATE NOCASE', whereArgs: [code], limit: 1);
      if (existe.isEmpty) return code;
    }
    throw StateError('Impossible de générer un code d\'accès unique.');
  }

  // ---------- Épreuves ----------

  Future<Epreuve> creerEpreuve(String titre, String matiereId,
      {String? auteurId}) async {
    final id = await _id('EPR', 'epreuve');
    final code = await _codeAcces();

    await _db.insert('epreuve', {
      'id': id,
      'titre': titre.trim(),
      'consignes': '',
      'matiere_id': matiereId,
      'auteur_id': auteurId,
      'debut': null,
      'duree_minutes': 60,
      'code_acces': code,
      'melanger_questions': 0,
      'melanger_propositions': 0,
      'etat': EtatEpreuve.brouillon.name,
      'nature': NatureEpreuve.controleContinu.name,
    });

    final creee = Epreuve(
      id: id,
      titre: titre.trim(),
      matiereId: matiereId,
      codeAcces: code,
    );
    epreuves.insert(0, creee);
    notifyListeners();
    return creee;
  }

  Future<void> majEpreuve(
    Epreuve e, {
    String? titre,
    String? consignes,
    DateTime? debut,
    int? dureeMinutes,
    bool? melangerQuestions,
    bool? melangerPropositions,
    EtatEpreuve? etat,
    NatureEpreuve? nature,
  }) async {
    final valeurs = <String, Object?>{};
    if (titre != null) valeurs['titre'] = titre.trim();
    if (consignes != null) valeurs['consignes'] = consignes;
    if (debut != null) valeurs['debut'] = debut.toIso8601String();
    if (dureeMinutes != null) valeurs['duree_minutes'] = dureeMinutes;
    if (melangerQuestions != null) {
      valeurs['melanger_questions'] = melangerQuestions ? 1 : 0;
    }
    if (melangerPropositions != null) {
      valeurs['melanger_propositions'] = melangerPropositions ? 1 : 0;
    }
    // Replanifier une épreuve terminée la rouvre : sans cela, la nouvelle
    // date serait enregistrée mais l'épreuve resterait close.
    if (debut != null &&
        etat == null &&
        e.etat == EtatEpreuve.terminee &&
        debut.isAfter(DateTime.now())) {
      valeurs['etat'] = EtatEpreuve.planifiee.name;
      etat = EtatEpreuve.planifiee;
    }

    if (etat != null) valeurs['etat'] = etat.name;
    if (nature != null) valeurs['nature'] = nature.name;
    if (valeurs.isEmpty) return;

    await _db.update('epreuve', valeurs, where: 'id = ?', whereArgs: [e.id]);

    if (titre != null) e.titre = titre.trim();
    if (consignes != null) e.consignes = consignes;
    if (debut != null) e.debut = debut;
    if (dureeMinutes != null) e.dureeMinutes = dureeMinutes;
    if (melangerQuestions != null) e.melangerQuestions = melangerQuestions;
    if (melangerPropositions != null) {
      e.melangerPropositions = melangerPropositions;
    }
    if (etat != null) e.etat = etat;
    if (nature != null) e.nature = nature;
    notifyListeners();
  }

  Future<void> supprimerEpreuve(String id) async {
    await _db.delete('epreuve', where: 'id = ?', whereArgs: [id]);
    epreuves.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  /// Duplique une épreuve avec ses questions : utile d'une session à l'autre.
  Future<Epreuve> dupliquerEpreuve(Epreuve source) async {
    final copie = await creerEpreuve('${source.titre} (copie)', source.matiereId);
    await majEpreuve(copie,
        consignes: source.consignes,
        dureeMinutes: source.dureeMinutes,
        melangerQuestions: source.melangerQuestions,
        melangerPropositions: source.melangerPropositions,
        nature: source.nature);

    for (final q in source.questionsTriees) {
      final nouvelle = await ajouterQuestion(copie, q.enonce, q.type,
          points: q.points);
      // La question créée porte déjà les propositions par défaut du type :
      // on repart de zéro pour recopier fidèlement l'original.
      await _viderPropositions(nouvelle);
      for (final p in q.propositionsTriees) {
        await ajouterProposition(nouvelle, p.texte, correcte: p.correcte);
      }
    }
    return copie;
  }

  // ---------- Questions ----------

  Future<Question> ajouterQuestion(
    Epreuve e,
    String enonce,
    TypeQuestion type, {
    double points = 1,
  }) async {
    final id = await _id('QST', 'question');
    final ordre = e.questions.length;

    await _db.insert('question', {
      'id': id,
      'epreuve_id': e.id,
      'enonce': enonce.trim(),
      'type': type.name,
      'points': points,
      'ordre': ordre,
    });

    final question = Question(
      id: id,
      epreuveId: e.id,
      enonce: enonce.trim(),
      type: type,
      points: points,
      ordre: ordre,
    );
    e.questions.add(question);

    // Vrai/faux a des propositions imposées : les créer d'emblée évite
    // que l'enseignant ait à les saisir à chaque question.
    if (type == TypeQuestion.vraiFaux) {
      await ajouterProposition(question, 'Vrai', correcte: true);
      await ajouterProposition(question, 'Faux');
    }

    notifyListeners();
    return question;
  }

  Future<void> majQuestion(
    Question q, {
    String? enonce,
    TypeQuestion? type,
    double? points,
  }) async {
    final valeurs = <String, Object?>{};
    if (enonce != null) valeurs['enonce'] = enonce.trim();
    if (type != null) valeurs['type'] = type.name;
    if (points != null) valeurs['points'] = points;
    if (valeurs.isEmpty) return;

    await _db.update('question', valeurs, where: 'id = ?', whereArgs: [q.id]);

    if (enonce != null) q.enonce = enonce.trim();
    if (points != null) q.points = points;

    if (type != null && type != q.type) {
      final ancien = q.type;
      q.type = type;
      // Passer en choix unique alors que plusieurs cases sont cochées
      // laisserait une question incorrigeable : on ne garde que la première.
      if (!type.multiple) {
        var vue = false;
        for (final p in q.propositionsTriees) {
          if (p.correcte && vue) {
            await majProposition(p, correcte: false);
          } else if (p.correcte) {
            vue = true;
          }
        }
      }
      // Vrai/faux impose ses deux propositions.
      if (type == TypeQuestion.vraiFaux && ancien != TypeQuestion.vraiFaux) {
        await _viderPropositions(q);
        await ajouterProposition(q, 'Vrai', correcte: true);
        await ajouterProposition(q, 'Faux');
      }
    }
    notifyListeners();
  }

  Future<void> supprimerQuestion(Epreuve e, String questionId) async {
    await _db.delete('question', where: 'id = ?', whereArgs: [questionId]);
    e.questions.removeWhere((q) => q.id == questionId);
    await _renumeroterQuestions(e);
    notifyListeners();
  }

  /// Déplace une question d'un cran vers le haut ou vers le bas.
  Future<void> deplacerQuestion(Epreuve e, Question q, int delta) async {
    final triees = e.questionsTriees;
    final index = triees.indexOf(q);
    final cible = index + delta;
    if (index < 0 || cible < 0 || cible >= triees.length) return;

    triees.removeAt(index);
    triees.insert(cible, q);
    for (var i = 0; i < triees.length; i++) {
      triees[i].ordre = i;
    }
    await _ecrireOrdreQuestions(triees);
    notifyListeners();
  }

  Future<void> _renumeroterQuestions(Epreuve e) async {
    final triees = e.questionsTriees;
    for (var i = 0; i < triees.length; i++) {
      triees[i].ordre = i;
    }
    await _ecrireOrdreQuestions(triees);
  }

  Future<void> _ecrireOrdreQuestions(List<Question> questions) async {
    await _db.transaction((txn) async {
      final lot = txn.batch();
      for (final q in questions) {
        lot.update('question', {'ordre': q.ordre},
            where: 'id = ?', whereArgs: [q.id]);
      }
      await lot.commit(noResult: true);
    });
  }

  // ---------- Propositions ----------

  Future<Proposition> ajouterProposition(
    Question q,
    String texte, {
    bool correcte = false,
  }) async {
    final id = await _id('PRP', 'proposition');
    final ordre = q.propositions.length;

    await _db.insert('proposition', {
      'id': id,
      'question_id': q.id,
      'texte': texte.trim(),
      'correcte': correcte ? 1 : 0,
      'ordre': ordre,
    });

    final proposition = Proposition(
      id: id,
      texte: texte.trim(),
      correcte: correcte,
      ordre: ordre,
    );
    q.propositions.add(proposition);
    notifyListeners();
    return proposition;
  }

  Future<void> majProposition(
    Proposition p, {
    String? texte,
    bool? correcte,
  }) async {
    final valeurs = <String, Object?>{};
    if (texte != null) valeurs['texte'] = texte.trim();
    if (correcte != null) valeurs['correcte'] = correcte ? 1 : 0;
    if (valeurs.isEmpty) return;

    await _db.update('proposition', valeurs, where: 'id = ?', whereArgs: [p.id]);
    if (texte != null) p.texte = texte.trim();
    if (correcte != null) p.correcte = correcte;
    notifyListeners();
  }

  /// Coche une bonne réponse en respectant le type de la question :
  /// en choix unique, cocher l'une décoche les autres.
  Future<void> basculerCorrecte(Question q, Proposition p) async {
    if (q.type.multiple) {
      await majProposition(p, correcte: !p.correcte);
      return;
    }
    await _db.transaction((txn) async {
      final lot = txn.batch();
      for (final autre in q.propositions) {
        final valeur = autre.id == p.id ? 1 : 0;
        lot.update('proposition', {'correcte': valeur},
            where: 'id = ?', whereArgs: [autre.id]);
      }
      await lot.commit(noResult: true);
    });
    for (final autre in q.propositions) {
      autre.correcte = autre.id == p.id;
    }
    notifyListeners();
  }

  Future<void> supprimerProposition(Question q, String propositionId) async {
    await _db.delete('proposition', where: 'id = ?', whereArgs: [propositionId]);
    q.propositions.removeWhere((p) => p.id == propositionId);

    final triees = q.propositionsTriees;
    for (var i = 0; i < triees.length; i++) {
      triees[i].ordre = i;
    }
    await _db.transaction((txn) async {
      final lot = txn.batch();
      for (final p in triees) {
        lot.update('proposition', {'ordre': p.ordre},
            where: 'id = ?', whereArgs: [p.id]);
      }
      await lot.commit(noResult: true);
    });
    notifyListeners();
  }

  Future<void> _viderPropositions(Question q) async {
    await _db.delete('proposition',
        where: 'question_id = ?', whereArgs: [q.id]);
    q.propositions.clear();
  }
}
