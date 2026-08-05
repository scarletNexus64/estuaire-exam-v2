import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

import '../data/magasin.dart';
import '../data/magasin_campus.dart';
import '../data/magasin_epreuves.dart';
import '../data/magasin_sessions.dart';
import '../data/modeles.dart';
import 'page_composition.dart';

/// Incident de surveillance relevé pendant une composition.
class Incident {
  final String sessionId;
  final String type;
  final String detail;
  final DateTime instant;

  Incident({
    required this.sessionId,
    required this.type,
    required this.detail,
    required this.instant,
  });

  String get libelle => switch (type) {
        'onglet' => 'A quitté l\'onglet',
        'focus' => 'Fenêtre en arrière-plan',
        'pleinecran' => 'Sortie du plein écran',
        'souris' => 'Curseur hors de la page',
        'copie' => 'Tentative de copie',
        'raccourci' => 'Raccourci bloqué',
        'fermeture' => 'Tentative de fermeture',
        _ => type,
      };
}

/// Serveur de composition sur le réseau local du campus.
///
/// Sert une page web autonome et l'API que les étudiants appellent.
/// Rien ne sort du réseau local : aucune dépendance à Internet.
class ServeurExamen extends ChangeNotifier {
  static final ServeurExamen instance = ServeurExamen._();
  ServeurExamen._();

  HttpServer? _serveur;
  String? _adresse;
  int _port = 8080;

  /// Journal des incidents, le plus récent en premier.
  final List<Incident> incidents = [];

  bool get actif => _serveur != null;
  int get port => _port;

  /// Adresse à communiquer aux étudiants : http://192.168.x.x:8080
  String? get lien => _adresse == null ? null : 'http://$_adresse:$_port';

  /// Première adresse IPv4 non locale : celle que voient les étudiants.
  static Future<String?> adresseLocale() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      // Le Wi-Fi passe avant : c'est par là que les étudiants arrivent.
      for (final prefere in ['en0', 'en1', 'wlan0']) {
        for (final i in interfaces) {
          if (i.name == prefere && i.addresses.isNotEmpty) {
            return i.addresses.first.address;
          }
        }
      }
      for (final i in interfaces) {
        if (i.addresses.isNotEmpty) return i.addresses.first.address;
      }
    } catch (_) {
      // Interface réseau indisponible : l'appelant affichera le message.
    }
    return null;
  }

  Future<void> demarrer({int port = 8080}) async {
    if (_serveur != null) return;

    _port = port;
    _adresse = await adresseLocale();

    final routeur = Router()
      ..get('/', _pageAccueil)
      ..get('/entete.png', _entete)
      ..get('/logo.png', _logo)
      ..post('/api/identifier', _identifier)
      ..post('/api/demarrer', _demarrer)
      ..post('/api/repondre', _repondre)
      ..post('/api/presence', _presence)
      ..post('/api/incident', _incident)
      ..post('/api/soumettre', _soumettre);

    final pipeline = const Pipeline()
        .addMiddleware(_entetes())
        .addHandler(routeur.call);

    // InternetAddress.anyIPv4 : joignable depuis les postes du réseau.
    _serveur = await io.serve(pipeline, InternetAddress.anyIPv4, _port);
    notifyListeners();
  }

  Future<void> arreter() async {
    await _serveur?.close(force: true);
    _serveur = null;
    notifyListeners();
  }

  /// Empêche la mise en cache : une épreuve modifiée doit être resservie.
  Middleware _entetes() => (innerHandler) => (requete) async {
        final reponse = await innerHandler(requete);
        return reponse.change(headers: {
          'Cache-Control': 'no-store, no-cache, must-revalidate',
          'X-Content-Type-Options': 'nosniff',
        });
      };

  /// Logo de l'application, lu une fois puis conservé en mémoire.
  Uint8List? _logoCache;

  Future<Response> _logo(Request _) async {
    var image = _logoCache;
    if (image == null) {
      final donnees = await rootBundle.load('assets/images/logo.png');
      image = donnees.buffer.asUint8List();
      _logoCache = image;
    }
    return Response.ok(image, headers: {'Content-Type': 'image/png'});
  }

  /// En-tête du campus de travail, servi à la page de composition.
  /// Répond 404 si le campus n'en a pas : la page masque alors l'image.
  Future<Response> _entete(Request _) async {
    final image = MagasinCampus.instance.enteteActif;
    if (image == null || image.isEmpty) return Response.notFound('');
    return Response.ok(image, headers: {'Content-Type': 'image/png'});
  }

  Response _pageAccueil(Request _) => Response.ok(
        pageComposition,
        headers: {'Content-Type': 'text/html; charset=utf-8'},
      );

  Future<Map<String, dynamic>> _corps(Request r) async {
    final texte = await r.readAsString();
    if (texte.isEmpty) return {};
    return jsonDecode(texte) as Map<String, dynamic>;
  }

  Response _json(Map<String, dynamic> donnees) => Response.ok(
        jsonEncode(donnees),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );

  Response _erreur(String message) => _json({'ok': false, 'erreur': message});

  /// Retrouve la session en vérifiant son jeton.
  ///
  /// Les identifiants étant séquentiels, ils ne prouvent rien : seul le
  /// jeton remis au navigateur autorise à agir sur une copie.
  SessionExamen? _sessionAutorisee(Map<String, dynamic> corps) {
    final session = MagasinSessions.instance
        .parId(corps['sessionId'] as String? ?? '');
    if (session == null) return null;
    return MagasinSessions.instance
            .jetonValide(session, corps['jeton'] as String?)
        ? session
        : null;
  }

  // ---------- API ----------

  /// Vérifie le code d'épreuve et le matricule, et renvoie l'identité
  /// pour que l'étudiant confirme que c'est bien lui.
  Future<Response> _identifier(Request requete) async {
    final corps = await _corps(requete);
    final code = (corps['code'] as String? ?? '').trim();
    final matricule = (corps['matricule'] as String? ?? '').trim();

    final epreuve = _epreuveParCode(code);
    if (epreuve == null) {
      return _erreur('Code d\'épreuve inconnu.');
    }
    if (epreuve.etat == EtatEpreuve.brouillon) {
      return _erreur('Cette épreuve n\'est pas encore ouverte.');
    }
    if (epreuve.estClose) {
      return _erreur('Cette épreuve est terminée.');
    }

    final matiere = Magasin.instance.matieres
        .where((m) => m.id == epreuve.matiereId)
        .firstOrNull;
    if (matiere == null) {
      return _erreur('Matière introuvable pour cette épreuve.');
    }

    // L'étudiant doit appartenir à la promotion de la matière : sinon
    // n'importe quel matricule du campus ouvrirait l'épreuve.
    final etudiant = Magasin.instance.etudiants
        .where((e) =>
            e.matricule.toLowerCase() == matricule.toLowerCase() &&
            e.niveauId == matiere.niveauId)
        .firstOrNull;

    if (etudiant == null) {
      return _erreur(
          'Matricule inconnu pour cette épreuve. Vérifiez votre saisie.');
    }
    if (!etudiant.actif) {
      return _erreur('Votre inscription n\'est pas active.');
    }

    return _json({
      'ok': true,
      'etudiant': {
        'nom': etudiant.nomComplet,
        'matricule': etudiant.matricule,
        'promotion': Magasin.instance.nomNiveau(etudiant.niveauId),
      },
      'campus': MagasinCampus.instance.intituleActif,
      'epreuve': {
        'code': epreuve.codeAcces,
        'titre': epreuve.titre,
        'matiere': '${matiere.code} · ${matiere.intitule}',
        'consignes': epreuve.consignes,
        'duree': epreuve.dureeMinutes,
        'nbQuestions': epreuve.questions.length,
        // Secondes avant l'ouverture ; 0 ou moins : l'épreuve est ouverte.
        'avantDebut': epreuve.debut == null
            ? 0
            : epreuve.debut!.difference(DateTime.now()).inSeconds,
      },
    });
  }

  /// Ouvre (ou reprend) la session et renvoie le sujet.
  Future<Response> _demarrer(Request requete) async {
    final corps = await _corps(requete);
    final code = (corps['code'] as String? ?? '').trim();
    final matricule = (corps['matricule'] as String? ?? '').trim();

    final epreuve = _epreuveParCode(code);
    if (epreuve == null) return _erreur('Code d\'épreuve inconnu.');

    final matiere = Magasin.instance.matieres
        .where((m) => m.id == epreuve.matiereId)
        .firstOrNull;
    final etudiant = Magasin.instance.etudiants
        .where((e) =>
            e.matricule.toLowerCase() == matricule.toLowerCase() &&
            e.niveauId == matiere?.niveauId)
        .firstOrNull;
    if (etudiant == null) return _erreur('Matricule inconnu.');

    // L'heure de fin prime sur tout : sans ce contrôle, une session
    // ouverte après la fin repartirait pour la durée complète.
    if (epreuve.estClose) {
      return _erreur('Cette épreuve est terminée.');
    }

    // Avant l'heure : ce n'est pas une erreur, l'étudiant patiente en
    // salle d'attente et le bouton s'active tout seul le moment venu.
    final debut = epreuve.debut;
    if (debut != null && DateTime.now().isBefore(debut)) {
      return _json({
        'ok': true,
        'attente': true,
        'avantDebut': debut.difference(DateTime.now()).inSeconds,
        'debut': debut.toIso8601String(),
      });
    }

    final session = await MagasinSessions.instance
        .ouvrir(epreuve.id, etudiant.id, debutEpreuve: epreuve.debut);

    if (session.estSoumise) {
      return _json({
        'ok': true,
        'soumise': true,
        'note': session.note,
        'bareme': epreuve.bareme,
      });
    }

    // Temps écoulé pendant une déconnexion : la copie est close d'office.
    if (session.tempsEcoule(epreuve.dureeMinutes)) {
      final note =
          await MagasinSessions.instance.soumettre(session, epreuve);
      return _json({
        'ok': true,
        'soumise': true,
        'note': note,
        'bareme': epreuve.bareme,
      });
    }

    await MagasinSessions.instance.signalerPresence(session);

    return _json({
      'ok': true,
      'sessionId': session.id,
      'jeton': session.jeton,
      'restant': session.restant(epreuve.dureeMinutes).inSeconds,
      'questions': _sujet(epreuve, session),
      'reponses': {
        for (final e in session.reponses.entries) e.key: e.value.toList(),
      },
    });
  }

  /// Sujet transmis à l'étudiant — sans jamais la bonne réponse :
  /// elle serait visible dans la console du navigateur.
  List<Map<String, dynamic>> _sujet(Epreuve epreuve, SessionExamen session) {
    final questions = epreuve.questionsTriees;

    // Mélange déterministe : le même étudiant retrouve son ordre après
    // une coupure, mais deux voisins n'ont pas le même sujet.
    if (epreuve.melangerQuestions) {
      questions.shuffle(Random(session.id.hashCode));
    }

    return [
      for (final q in questions)
        {
          'id': q.id,
          'enonce': q.enonce,
          'type': q.type.name,
          'typeLibelle': q.type.libelle,
          'points': q.points == q.points.roundToDouble()
              ? q.points.toInt()
              : q.points,
          'propositions': _propositions(q, epreuve, session),
        }
    ];
  }

  List<Map<String, String>> _propositions(
      Question q, Epreuve epreuve, SessionExamen session) {
    final propositions = q.propositionsTriees;
    // Vrai/faux garde son ordre : inverser « Vrai » et « Faux » déroute
    // sans rien apporter contre la copie.
    if (epreuve.melangerPropositions && q.type != TypeQuestion.vraiFaux) {
      propositions.shuffle(Random('${session.id}-${q.id}'.hashCode));
    }
    return [
      for (final p in propositions) {'id': p.id, 'texte': p.texte}
    ];
  }

  Future<Response> _repondre(Request requete) async {
    final corps = await _corps(requete);
    final session = _sessionAutorisee(corps);
    if (session == null) return _erreur('Session inconnue ou non autorisée.');

    final epreuve = MagasinEpreuves.instance.epreuve(session.epreuveId);
    if (epreuve == null) return _erreur('Épreuve introuvable.');

    // Refuse toute réponse hors délai : le chronomètre du navigateur
    // pourrait avoir été manipulé.
    if (epreuve.estClose || session.tempsEcoule(epreuve.dureeMinutes)) {
      await MagasinSessions.instance.soumettre(session, epreuve);
      return _json({'ok': false, 'terminee': true});
    }

    final propositions =
        (corps['propositions'] as List? ?? []).cast<String>().toSet();
    await MagasinSessions.instance.repondre(
      session,
      corps['questionId'] as String? ?? '',
      propositions,
    );
    return _json({'ok': true});
  }

  Future<Response> _presence(Request requete) async {
    final corps = await _corps(requete);
    final session = _sessionAutorisee(corps);
    if (session == null) return _erreur('Session inconnue ou non autorisée.');

    final epreuve = MagasinEpreuves.instance.epreuve(session.epreuveId);
    if (epreuve == null) return _erreur('Épreuve introuvable.');

    await MagasinSessions.instance.signalerPresence(session);

    // L'épreuve close arrête tout le monde, même en cours de composition.
    final restant =
        epreuve.estClose ? 0 : session.restant(epreuve.dureeMinutes).inSeconds;
    if (restant == 0 && !session.estSoumise) {
      await MagasinSessions.instance.soumettre(session, epreuve);
      return _json({'ok': true, 'restant': 0, 'terminee': true});
    }
    return _json({'ok': true, 'restant': restant});
  }

  /// Dernier incident enregistré par session : borne le débit.
  final Map<String, DateTime> _dernierIncident = {};

  Future<Response> _incident(Request requete) async {
    final corps = await _corps(requete);
    final session = _sessionAutorisee(corps);
    if (session == null) return _erreur('Session inconnue ou non autorisée.');
    final sessionId = session.id;

    // Un incident par seconde au plus : sans cette borne, une boucle
    // noierait le journal et effacerait les incidents des autres.
    final precedent = _dernierIncident[sessionId];
    final maintenant = DateTime.now();
    if (precedent != null &&
        maintenant.difference(precedent).inMilliseconds < 1000) {
      return _json({'ok': true, 'ignore': true, 'alertes': session.alertes});
    }
    _dernierIncident[sessionId] = maintenant;

    incidents.insert(
      0,
      Incident(
        sessionId: sessionId,
        type: corps['type'] as String? ?? 'inconnu',
        detail: corps['detail'] as String? ?? '',
        instant: maintenant,
      ),
    );
    // Journal borné : une session agitée ne doit pas saturer la mémoire.
    if (incidents.length > 500) incidents.removeRange(500, incidents.length);

    final seuilAtteint = MagasinSessions.instance.signalerAlerte(session);
    notifyListeners();

    // Trois incidents : la copie est annulée et notée zéro.
    if (seuilAtteint && !session.estSoumise) {
      await MagasinSessions.instance.annulerPourFraude(session);
      return _json({
        'ok': true,
        'annulee': true,
        'alertes': session.alertes,
        'seuil': MagasinSessions.seuilAlertes,
      });
    }

    return _json({
      'ok': true,
      'alertes': session.alertes,
      'seuil': MagasinSessions.seuilAlertes,
      'restantes': MagasinSessions.seuilAlertes - session.alertes,
    });
  }

  Future<Response> _soumettre(Request requete) async {
    final corps = await _corps(requete);
    final session = _sessionAutorisee(corps);
    if (session == null) return _erreur('Session inconnue ou non autorisée.');

    final epreuve = MagasinEpreuves.instance.epreuve(session.epreuveId);
    if (epreuve == null) return _erreur('Épreuve introuvable.');

    final note = await MagasinSessions.instance.soumettre(session, epreuve);
    return _json({'ok': true, 'note': note, 'bareme': epreuve.bareme});
  }

  Epreuve? _epreuveParCode(String code) => MagasinEpreuves.instance.epreuves
      .where((e) => e.codeAcces.toLowerCase() == code.toLowerCase())
      .firstOrNull;

  /// Incidents d'une session, du plus récent au plus ancien.
  List<Incident> incidentsDe(String sessionId) =>
      incidents.where((i) => i.sessionId == sessionId).toList();
}
