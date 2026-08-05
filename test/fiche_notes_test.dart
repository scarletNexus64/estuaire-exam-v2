import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:estuaire_examen/data/base_locale.dart';
import 'package:estuaire_examen/data/magasin.dart';
import 'package:estuaire_examen/data/magasin_campus.dart';
import 'package:estuaire_examen/data/magasin_epreuves.dart';
import 'package:estuaire_examen/data/magasin_sessions.dart';
import 'package:estuaire_examen/data/modeles.dart';
import 'package:estuaire_examen/data/parametres.dart';
import 'package:estuaire_examen/documents/fiche_notes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dossier;
  final magasin = Magasin.instance;
  final magasinEpreuves = MagasinEpreuves.instance;
  late Matiere matiere;
  late Etudiant ange;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    dossier = await Directory.systemTemp.createTemp('estuaire_fiche');
    await BaseLocale.instance.ouvrirPourTest('${dossier.path}/estuaire.db');
    await MagasinCampus.instance.charger();
    MagasinCampus.instance
        .choisir(MagasinCampus.instance.parId('CMP001'));
    await magasin.charger();
    await magasinEpreuves.charger();
    await MagasinSessions.instance.charger();
    await Parametres.instance.charger();

    await magasin.ajouterSpecialite('GL', 'Génie Logiciel', 'M.KUIMO');
    final gl = magasin.specialites.first;
    await magasin.ajouterNiveau(gl.id, Palier.bts1);
    final bts1 = magasin.niveauxDe(gl.id).first;
    await magasin.ajouterMatiere(
        'RO1234', 'Recherche Operationnelle II', bts1.id, 1);
    matiere = magasin.matieres.first;

    await magasin.ajouterEtudiant('IUE26TEST92', 'Ange Tim', Sexe.f, bts1.id);
    ange = magasin.etudiants.first;
  });

  tearDownAll(() async {
    await BaseLocale.instance.fermer();
    await dossier.delete(recursive: true);
  });

  test('l\'année académique est proposée par défaut', () {
    // Format « 2025-2026 ».
    expect(Parametres.instance.annee, matches(r'^\d{4}-\d{4}$'));
  });

  test('sans note, les colonnes restent vides', () {
    final lignes = FicheNotes.lignesDe(matiere);
    expect(lignes, hasLength(1));
    expect(lignes.first.nom, 'Ange Tim');
    expect(lignes.first.matricule, 'IUE26TEST92');
    expect(lignes.first.sexe, 'F');
    expect(lignes.first.controleContinu, isNull);
  });

  test('la note est ramenée sur 20 dans la bonne colonne', () async {
    // Épreuve de 5 points en contrôle continu ; 2 points obtenus.
    final e = await magasinEpreuves.creerEpreuve('CC n°1', matiere.id);
    await magasinEpreuves.majEpreuve(e,
        debut: DateTime.now(), nature: NatureEpreuve.controleContinu);

    final q = await magasinEpreuves.ajouterQuestion(
        e, 'Question', TypeQuestion.choixUnique, points: 5);
    await magasinEpreuves.ajouterProposition(q, 'Bonne', correcte: true);
    await magasinEpreuves.ajouterProposition(q, 'Mauvaise');

    final session = await MagasinSessions.instance.ouvrir(e.id, ange.id);
    final bonne = q.propositions.firstWhere((p) => p.correcte);
    await MagasinSessions.instance.repondre(session, q.id, {bonne.id});
    await MagasinSessions.instance.soumettre(session, e);

    final lignes = FicheNotes.lignesDe(matiere);
    // 5/5 devient 20/20.
    expect(lignes.first.controleContinu, 20);
    // Les autres colonnes ne sont pas alimentées.
    expect(lignes.first.sessionNormale, isNull);
    expect(lignes.first.rattrapage, isNull);
  });

  test('chaque nature alimente sa propre colonne', () async {
    final e = await magasinEpreuves.creerEpreuve('Session normale', matiere.id);
    await magasinEpreuves.majEpreuve(e,
        debut: DateTime.now(), nature: NatureEpreuve.sessionNormale);

    final q = await magasinEpreuves.ajouterQuestion(
        e, 'Q', TypeQuestion.choixUnique, points: 4);
    await magasinEpreuves.ajouterProposition(q, 'A', correcte: true);
    await magasinEpreuves.ajouterProposition(q, 'B');

    final session = await MagasinSessions.instance.ouvrir(e.id, ange.id);
    // Aucune réponse : 0 sur 4, soit 0/20.
    await MagasinSessions.instance.soumettre(session, e);

    final lignes = FicheNotes.lignesDe(matiere);
    expect(lignes.first.controleContinu, 20);
    expect(lignes.first.sessionNormale, 0);
  });

  test('la fiche de notes produit un PDF valide', () async {
    final pdf = await FicheNotes.fiche(
      matiere: matiere,
      enseignant: 'Ing. BOUSSA Steve',
      lignes: FicheNotes.lignesDe(matiere),
    );

    expect(pdf.length, greaterThan(1000));
    // En-tête de fichier PDF.
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
  });

  test('la liste de présence distingue présents et absents', () async {
    final epreuve = magasinEpreuves.epreuvesDe(matiere.id).first;
    await magasin.ajouterEtudiant(
        'IUE26ABS01', 'Absent Test', Sexe.m, matiere.niveauId);

    final pdf = await FicheNotes.listePresence(
      epreuve: epreuve,
      matiere: matiere,
      enseignant: 'Ing. BOUSSA Steve',
    );

    expect(pdf.length, greaterThan(1000));
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');

    // L'étudiant sans session doit être compté absent.
    final sansSession =
        MagasinSessions.instance.sessionDe(epreuve.id, magasin.etudiants
            .firstWhere((e) => e.matricule == 'IUE26ABS01')
            .id);
    expect(sansSession, isNull);
  });
}
