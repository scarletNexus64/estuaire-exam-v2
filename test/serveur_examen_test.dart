import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:estuaire_examen/data/base_locale.dart';
import 'package:estuaire_examen/data/magasin.dart';
import 'package:estuaire_examen/data/magasin_campus.dart';
import 'package:estuaire_examen/data/magasin_epreuves.dart';
import 'package:estuaire_examen/data/magasin_sessions.dart';
import 'package:estuaire_examen/data/modeles.dart';
import 'package:estuaire_examen/serveur/serveur_examen.dart';

/// Parcours complet d'une épreuve, sur la vraie base et le vrai serveur HTTP.
void main() {
  late Directory dossier;
  final magasin = Magasin.instance;
  final magasinEpreuves = MagasinEpreuves.instance;
  final serveur = ServeurExamen.instance;

  late Epreuve epreuve;
  late Matiere matiere;
  late String matriculeAnge;
  const port = 8099;
  final base = Uri.parse('http://127.0.0.1:$port');

  Future<Map<String, dynamic>> poster(
      String chemin, Map<String, dynamic> corps) async {
    final client = HttpClient();
    final requete = await client.postUrl(base.resolve(chemin));
    requete.headers.contentType = ContentType.json;
    requete.write(jsonEncode(corps));
    final reponse = await requete.close();
    final texte = await reponse.transform(utf8.decoder).join();
    client.close();
    return jsonDecode(texte) as Map<String, dynamic>;
  }

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    dossier = await Directory.systemTemp.createTemp('estuaire_serveur');
    await BaseLocale.instance.ouvrirPourTest('${dossier.path}/estuaire.db');
    await MagasinCampus.instance.charger();
    MagasinCampus.instance
        .choisir(MagasinCampus.instance.parId('CMP001'));
    await magasin.charger();
    await magasinEpreuves.charger();
    await MagasinSessions.instance.charger();

    // Jeu minimal : une promotion, une matière, deux étudiants.
    await magasin.ajouterSpecialite('GL', 'Génie Logiciel', 'M. KUIMO');
    final gl = magasin.specialites.first;
    await magasin.ajouterNiveau(gl.id, Palier.bts1);
    final bts1 = magasin.niveauxDe(gl.id).first;
    await magasin.ajouterMatiere('ALG201', 'Algorithmique', bts1.id, 1);
    matiere = magasin.matieres.first;

    await magasin.ajouterEtudiant('IUE001', 'Ange Tim', Sexe.f, bts1.id);
    matriculeAnge = 'IUE001';

    // Une autre promotion, pour vérifier le cloisonnement.
    await magasin.ajouterNiveau(gl.id, Palier.bts2);
    final bts2 = magasin.niveauxDe(gl.id).last;
    await magasin.ajouterEtudiant('IUE999', 'Intrus Autre', Sexe.m, bts2.id);

    epreuve = await magasinEpreuves.creerEpreuve('Contrôle 1', matiere.id);
    await magasinEpreuves.majEpreuve(epreuve,
        debut: DateTime.now().subtract(const Duration(minutes: 1)),
        dureeMinutes: 60);

    // Q1 choix unique : une bonne réponse.
    final q1 = await magasinEpreuves.ajouterQuestion(
        epreuve, 'Capitale du Cameroun ?', TypeQuestion.choixUnique,
        points: 2);
    await magasinEpreuves.ajouterProposition(q1, 'Yaoundé', correcte: true);
    await magasinEpreuves.ajouterProposition(q1, 'Douala');

    // Q2 choix multiple : deux bonnes réponses.
    final q2 = await magasinEpreuves.ajouterQuestion(
        epreuve, 'Langages compilés ?', TypeQuestion.choixMultiple,
        points: 3);
    await magasinEpreuves.ajouterProposition(q2, 'C', correcte: true);
    await magasinEpreuves.ajouterProposition(q2, 'Rust', correcte: true);
    await magasinEpreuves.ajouterProposition(q2, 'Python');

    await magasinEpreuves.majEpreuve(epreuve, etat: EtatEpreuve.planifiee);
    await serveur.demarrer(port: port);
  });

  tearDownAll(() async {
    await serveur.arreter();
    await BaseLocale.instance.fermer();
    await dossier.delete(recursive: true);
  });

  test('la page de composition est servie', () async {
    final client = HttpClient();
    final reponse = await (await client.getUrl(base)).close();
    final corps = await reponse.transform(utf8.decoder).join();
    client.close();

    expect(reponse.statusCode, 200);
    expect(corps, contains('Estuaire Examen'));
    expect(corps, contains('requestFullscreen'));
  });

  test('identification : code inconnu refusé', () async {
    final r = await poster(
        '/api/identifier', {'code': 'ZZZZZZ', 'matricule': matriculeAnge});
    expect(r['ok'], isFalse);
  });

  test('identification : matricule d\'une autre promotion refusé', () async {
    // Cloisonnement : un étudiant de BTS 2 ne compose pas l'épreuve de BTS 1.
    final r = await poster('/api/identifier',
        {'code': epreuve.codeAcces, 'matricule': 'IUE999'});
    expect(r['ok'], isFalse);
  });

  test('identification : renvoie l\'identité à confirmer', () async {
    final r = await poster('/api/identifier',
        {'code': epreuve.codeAcces, 'matricule': matriculeAnge});

    expect(r['ok'], isTrue);
    expect(r['etudiant']['nom'], 'Ange Tim');
    expect(r['epreuve']['nbQuestions'], 2);
  });

  test('le sujet ne révèle jamais les bonnes réponses', () async {
    final r = await poster('/api/demarrer',
        {'code': epreuve.codeAcces, 'matricule': matriculeAnge});

    expect(r['ok'], isTrue);
    final questions = r['questions'] as List;
    expect(questions, hasLength(2));

    // Une clé « correcte » exposée permettrait de tricher via la console.
    final brut = jsonEncode(questions);
    expect(brut.contains('correcte'), isFalse);
  });

  test('les réponses sont enregistrées et la copie reprend après coupure',
      () async {
    final demarrage = await poster('/api/demarrer',
        {'code': epreuve.codeAcces, 'matricule': matriculeAnge});
    final sessionId = demarrage['sessionId'] as String;

    final q1 = epreuve.questionsTriees.first;
    final bonne = q1.propositions.firstWhere((p) => p.correcte);

    final jeton = demarrage['jeton'] as String;
    final r = await poster('/api/repondre', {
      'sessionId': sessionId,
      'jeton': jeton,
      'questionId': q1.id,
      'propositions': [bonne.id],
    });
    expect(r['ok'], isTrue);

    // Simule une reconnexion : la réponse déjà donnée doit revenir.
    final reprise = await poster('/api/demarrer',
        {'code': epreuve.codeAcces, 'matricule': matriculeAnge});
    expect(reprise['sessionId'], sessionId);
    expect((reprise['reponses'] as Map)[q1.id], contains(bonne.id));
  });

  test('les incidents de surveillance sont journalisés', () async {
    final session = MagasinSessions.instance.sessionsDe(epreuve.id).first;
    final avant = session.alertes;

    await poster('/api/incident', {
      'sessionId': session.id,
      'jeton': session.jeton,
      'type': 'onglet',
      'detail': 'page masquée',
    });

    expect(session.alertes, avant + 1);
    expect(serveur.incidentsDe(session.id).first.libelle,
        'A quitté l\'onglet');
  });

  test('correction : tout ou rien par question', () async {
    final session = MagasinSessions.instance.sessionsDe(epreuve.id).first;
    final q2 = epreuve.questionsTriees[1];
    final bonnes =
        q2.propositions.where((p) => p.correcte).map((p) => p.id).toList();

    // Une seule des deux bonnes réponses : la question ne rapporte rien.
    await poster('/api/repondre', {
      'sessionId': session.id,
      'jeton': session.jeton,
      'questionId': q2.id,
      'propositions': [bonnes.first],
    });

    final partielle = await poster(
        '/api/soumettre', {'sessionId': session.id, 'jeton': session.jeton});
    expect(partielle['bareme'], 5);
    // Seule Q1 (2 pts) est juste.
    expect(partielle['note'], 2);
  });

  test('une copie remise ne peut plus être modifiée', () async {
    final session = MagasinSessions.instance.sessionsDe(epreuve.id).first;
    expect(session.estSoumise, isTrue);

    final avant = Map.of(session.reponses);
    await MagasinSessions.instance
        .repondre(session, epreuve.questionsTriees.first.id, {});
    expect(session.reponses.length, avant.length);
  });

  test('la reconnexion après remise renvoie la note', () async {
    final r = await poster('/api/demarrer',
        {'code': epreuve.codeAcces, 'matricule': matriculeAnge});
    expect(r['soumise'], isTrue);
    expect(r['note'], 2);
  });

  test('sans jeton, on ne peut agir sur aucune copie', () async {
    // Les identifiants sont séquentiels : les deviner ne doit rien donner.
    final session = MagasinSessions.instance.sessionsDe(epreuve.id).first;

    final sansJeton =
        await poster('/api/soumettre', {'sessionId': session.id});
    expect(sansJeton['ok'], isFalse);

    final mauvaisJeton = await poster('/api/repondre', {
      'sessionId': session.id,
      'jeton': 'jeton-invente',
      'questionId': epreuve.questionsTriees.first.id,
      'propositions': <String>[],
    });
    expect(mauvaisJeton['ok'], isFalse);

    final incident = await poster('/api/incident', {
      'sessionId': session.id,
      'jeton': 'jeton-invente',
      'type': 'onglet',
    });
    expect(incident['ok'], isFalse);
  });

  test('après l\'heure de fin, l\'épreuve n\'est plus diffusée', () async {
    // Épreuve d'une minute, démarrée il y a deux heures.
    await magasinEpreuves.majEpreuve(epreuve,
        debut: DateTime.now().subtract(const Duration(hours: 2)),
        dureeMinutes: 1);

    expect(epreuve.estClose, isTrue);

    final identification = await poster('/api/identifier',
        {'code': epreuve.codeAcces, 'matricule': matriculeAnge});
    expect(identification['ok'], isFalse);

    // Et surtout : impossible d'ouvrir une session neuve à durée pleine.
    final demarrage = await poster('/api/demarrer',
        {'code': epreuve.codeAcces, 'matricule': matriculeAnge});
    expect(demarrage['ok'], isFalse);

    // Remise en état pour les tests suivants.
    await magasinEpreuves.majEpreuve(epreuve,
        debut: DateTime.now().subtract(const Duration(minutes: 1)),
        dureeMinutes: 60);
  });

  test('trois incidents annulent la copie', () async {
    await magasin.ajouterEtudiant(
        'IUE-FRAUDE', 'Tricheur Test', Sexe.m, matiere.niveauId);

    final r = await poster('/api/demarrer',
        {'code': epreuve.codeAcces, 'matricule': 'IUE-FRAUDE'});
    final sessionId = r['sessionId'] as String;
    final jeton = r['jeton'] as String;

    Map<String, dynamic> incident() => {
          'sessionId': sessionId,
          'jeton': jeton,
          'type': 'onglet',
          'detail': 'sortie',
        };

    // La limitation de débit impose d'espacer les envois.
    final premier = await poster('/api/incident', incident());
    expect(premier['annulee'], isNot(true));

    await Future.delayed(const Duration(milliseconds: 1100));
    final deuxieme = await poster('/api/incident', incident());
    expect(deuxieme['annulee'], isNot(true));

    await Future.delayed(const Duration(milliseconds: 1100));
    final troisieme = await poster('/api/incident', incident());
    expect(troisieme['annulee'], isTrue);

    final session = MagasinSessions.instance.parId(sessionId)!;
    expect(session.annulee, isTrue);
    expect(session.note, 0);
    expect(session.estSoumise, isTrue);
  });

  test('les incidents rapprochés sont ignorés', () async {
    final session = MagasinSessions.instance
        .sessionsDe(epreuve.id)
        .firstWhere((s) => !s.annulee);
    final avant = session.alertes;

    // Deux envois consécutifs : le second ne doit pas compter.
    await poster('/api/incident',
        {'sessionId': session.id, 'jeton': session.jeton, 'type': 'focus'});
    await poster('/api/incident',
        {'sessionId': session.id, 'jeton': session.jeton, 'type': 'focus'});

    expect(session.alertes, lessThanOrEqualTo(avant + 1));
  });

  test('replanifier une épreuve permet de la recomposer', () async {
    await magasin.ajouterEtudiant(
        'IUE-REJOUE', 'Rejoue Test', Sexe.m, matiere.niveauId);

    // Première passation : l'étudiant compose et obtient une note.
    final premiere = await poster('/api/demarrer',
        {'code': epreuve.codeAcces, 'matricule': 'IUE-REJOUE'});
    final sessionId = premiere['sessionId'] as String;
    final jeton = premiere['jeton'] as String;

    final q1 = epreuve.questionsTriees.first;
    final bonne = q1.propositions.firstWhere((p) => p.correcte);
    await poster('/api/repondre', {
      'sessionId': sessionId,
      'jeton': jeton,
      'questionId': q1.id,
      'propositions': [bonne.id],
    });
    final remise =
        await poster('/api/soumettre', {'sessionId': sessionId, 'jeton': jeton});
    expect(remise['note'], greaterThan(0));

    // L'enseignant replanifie la même épreuve pour une nouvelle session.
    // Le nouveau début est postérieur à la copie déjà remise : c'est ce
    // qui distingue une reprise après coupure d'une nouvelle passation.
    await Future.delayed(const Duration(milliseconds: 20));
    await magasinEpreuves.majEpreuve(epreuve, debut: DateTime.now());
    await Future.delayed(const Duration(milliseconds: 20));

    // L'étudiant doit repartir d'une copie vierge, pas revoir son ancienne
    // note : c'est le bug constaté en salle.
    final seconde = await poster('/api/demarrer',
        {'code': epreuve.codeAcces, 'matricule': 'IUE-REJOUE'});

    expect(seconde['soumise'], isNot(true),
        reason: 'l\'ancienne note ne doit pas être resservie');
    // Copie vierge : aucune réponse de la passation précédente.
    expect((seconde['reponses'] as Map?) ?? {}, isEmpty);

    final session =
        MagasinSessions.instance.parId(seconde['sessionId'] as String)!;
    expect(session.estSoumise, isFalse);
    expect(session.note, isNull);

    // Les deux passations coexistent : l'historique n'est pas perdu.
    final etudiant =
        magasin.etudiants.firstWhere((e) => e.matricule == 'IUE-REJOUE');
    final toutes = MagasinSessions.instance.sessions
        .where((s) => s.epreuveId == epreuve.id && s.etudiantId == etudiant.id);
    expect(toutes.length, 2);
    expect(toutes.map((s) => s.passation).toSet().length, 2);
  });

  test('une épreuve terminée puis replanifiée se rouvre', () async {
    await magasinEpreuves.majEpreuve(epreuve, etat: EtatEpreuve.terminee);
    expect(epreuve.estClose, isTrue);

    // Replanifier dans le futur doit lever la clôture.
    await magasinEpreuves.majEpreuve(epreuve,
        debut: DateTime.now().add(const Duration(minutes: 10)));
    expect(epreuve.etat, EtatEpreuve.planifiee);
    expect(epreuve.estClose, isFalse);

    // Remise en état pour les tests suivants.
    await magasinEpreuves.majEpreuve(epreuve,
        debut: DateTime.now().subtract(const Duration(minutes: 1)));
  });

  test('les codes d\'accès sont uniques, même après duplication', () async {
    final copie = await magasinEpreuves.dupliquerEpreuve(epreuve);
    expect(copie.codeAcces, isNot(epreuve.codeAcces));

    final codes =
        magasinEpreuves.epreuves.map((e) => e.codeAcces.toLowerCase()).toList();
    expect(codes.toSet().length, codes.length,
        reason: 'deux épreuves ne doivent jamais partager un code');

    await magasinEpreuves.supprimerEpreuve(copie.id);
  });

  test('une épreuve en brouillon n\'est pas diffusable', () async {
    await magasinEpreuves.majEpreuve(epreuve, etat: EtatEpreuve.brouillon);
    final r = await poster('/api/identifier',
        {'code': epreuve.codeAcces, 'matricule': matriculeAnge});
    expect(r['ok'], isFalse);
    await magasinEpreuves.majEpreuve(epreuve, etat: EtatEpreuve.planifiee);
  });
}
