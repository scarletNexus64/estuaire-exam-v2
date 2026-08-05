import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:estuaire_examen/data/base_locale.dart';
import 'package:estuaire_examen/data/magasin.dart';
import 'package:estuaire_examen/data/magasin_campus.dart';
import 'package:estuaire_examen/data/modeles.dart';

/// Le cloisonnement entre campus est la garantie centrale : un enseignant
/// connecté au Campus A ne doit jamais voir les étudiants du Campus B.
void main() {
  late Directory dossier;
  final magasin = Magasin.instance;
  final campus = MagasinCampus.instance;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    dossier = await Directory.systemTemp.createTemp('estuaire_campus');
    await BaseLocale.instance.ouvrirPourTest('${dossier.path}/estuaire.db');
    await campus.charger();
  });

  tearDownAll(() async {
    await BaseLocale.instance.fermer();
    await dossier.delete(recursive: true);
  });

  test('la hiérarchie annexes / campus est créée au démarrage', () {
    expect(campus.annexes, hasLength(2));
    expect(campus.campusDe('ANX001'), hasLength(6));
    expect(campus.campusDe('ANX002'), hasLength(1));

    final makambou =
        campus.campus.firstWhere((c) => c.intitule == 'CAMPUS DE MAKAMBOU');
    expect(campus.nomAnnexeDe(makambou.id), 'Campus annexe de Bafoussam');
  });

  test('sans campus actif, aucune donnée n\'est chargée', () async {
    campus.choisir(null);
    await magasin.charger();
    expect(magasin.specialites, isEmpty);
    expect(magasin.estCharge, isFalse);
  });

  test('créer une spécialité sans campus est refusé', () async {
    campus.choisir(null);
    expect(
      () => magasin.ajouterSpecialite('X', 'Test', 'M. X'),
      throwsA(isA<StateError>()),
    );
  });

  test('chaque campus a ses propres données', () async {
    // Campus A : Génie Logiciel avec un étudiant.
    campus.choisir(campus.parId('CMP001'));
    await magasin.charger();
    await magasin.ajouterSpecialite('GL', 'Génie Logiciel', 'M. KUIMO');
    final glA = magasin.specialites.first;
    await magasin.ajouterNiveau(glA.id, Palier.bts1);
    await magasin.ajouterEtudiant(
        'IUE-A-001', 'Ange Campus A', Sexe.f, magasin.niveaux.first.id);

    expect(magasin.specialites, hasLength(1));
    expect(magasin.etudiants, hasLength(1));

    // Campus B : même intitulé de spécialité, autre étudiant.
    campus.choisir(campus.parId('CMP002'));
    await magasin.charger();

    // Le Campus B ne doit rien voir du Campus A.
    expect(magasin.specialites, isEmpty);
    expect(magasin.niveaux, isEmpty);
    expect(magasin.etudiants, isEmpty);

    await magasin.ajouterSpecialite('GL', 'Génie Logiciel', 'M. TCHOUA');
    final glB = magasin.specialites.first;
    await magasin.ajouterNiveau(glB.id, Palier.bts1);
    await magasin.ajouterEtudiant(
        'IUE-B-001', 'Bertrand Campus B', Sexe.m, magasin.niveaux.first.id);

    expect(magasin.etudiants, hasLength(1));
    expect(magasin.etudiants.first.matricule, 'IUE-B-001');

    // Retour au Campus A : ses données sont intactes et isolées.
    campus.choisir(campus.parId('CMP001'));
    await magasin.charger();
    expect(magasin.etudiants, hasLength(1));
    expect(magasin.etudiants.first.matricule, 'IUE-A-001');
  });

  test('le même intitulé peut exister sur deux campus', () async {
    // Deux « Génie Logiciel » coexistent sans se marcher dessus.
    campus.choisir(campus.parId('CMP001'));
    await magasin.charger();
    final aCampusA = magasin.specialites.first.id;

    campus.choisir(campus.parId('CMP002'));
    await magasin.charger();
    final aCampusB = magasin.specialites.first.id;

    expect(aCampusA, isNot(aCampusB));
  });

  test('supprimer un campus emporte ses données', () async {
    expect(await campus.nbSpecialites('CMP002'), 1);

    await campus.supprimerCampus('CMP002');
    // Le campus actif ayant disparu, il est relâché.
    expect(campus.actif, isNull);
    expect(await campus.nbSpecialites('CMP002'), 0);

    // Le Campus A n'est pas affecté.
    campus.choisir(campus.parId('CMP001'));
    await magasin.charger();
    expect(magasin.etudiants, hasLength(1));
  });

  test('supprimer une annexe emporte ses campus', () async {
    await campus.supprimerAnnexe('ANX002');
    expect(campus.annexes.any((a) => a.id == 'ANX002'), isFalse);
    expect(campus.campusDe('ANX002'), isEmpty);
  });

  test('l\'intitulé complet joint annexe et campus', () {
    expect(campus.intituleComplet('CMP001'),
        'Campus annexe de Bafoussam — CAMPUS A');
  });

  test('chaque campus porte son propre en-tête', () async {
    final a = campus.parId('CMP001')!;
    final c = campus.parId('CMP003')!;

    // Sans image, on retombe sur l'en-tête générique de l'institut.
    expect(a.aEntete, isFalse);
    expect(campus.enteteDe(a.id), isNull);

    final image = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
    await campus.definirEntete(a, image);

    expect(a.aEntete, isTrue);
    expect(campus.enteteDe(a.id), image);
    // Le campus voisin n'hérite pas de l'image.
    expect(campus.enteteDe(c.id), isNull);

    // L'image survit à un rechargement : elle vit dans la base.
    await campus.charger();
    expect(campus.parId('CMP001')!.entete, image);

    // Retrait : retour à l'en-tête générique.
    await campus.definirEntete(campus.parId('CMP001')!, null);
    expect(campus.enteteDe('CMP001'), isNull);
  });

  test('l\'en-tête actif suit le campus sélectionné', () async {
    final image = Uint8List.fromList([1, 2, 3, 4]);
    await campus.definirEntete(campus.parId('CMP004')!, image);

    campus.choisir(campus.parId('CMP004'));
    expect(campus.enteteActif, image);

    campus.choisir(campus.parId('CMP005'));
    expect(campus.enteteActif, isNull);
  });
}
