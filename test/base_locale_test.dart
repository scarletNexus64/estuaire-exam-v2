import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:estuaire_examen/data/base_locale.dart';
import 'package:estuaire_examen/data/console_sql.dart';
import 'package:estuaire_examen/data/magasin.dart';
import 'package:estuaire_examen/data/magasin_campus.dart';
import 'package:estuaire_examen/data/modeles.dart';
import 'package:estuaire_examen/data/session.dart';

/// Ces tests s'exécutent sur la vraie base SQLite, dans un dossier temporaire.
void main() {
  late Directory dossier;
  final m = Magasin.instance;
  final s = Session.instance;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    dossier = await Directory.systemTemp.createTemp('estuaire_test');
    // Contourne getApplicationSupportDirectory, indisponible sous test :
    // on ouvre directement une base au même schéma.
    await BaseLocale.instance.ouvrirPourTest('${dossier.path}/estuaire.db');
    await MagasinCampus.instance.charger();
    MagasinCampus.instance
        .choisir(MagasinCampus.instance.parId('CMP001'));
    await m.charger();
    await s.charger();
  });

  tearDownAll(() async {
    await BaseLocale.instance.fermer();
    await dossier.delete(recursive: true);
  });

  test('la base démarre vide, avec le seul compte administrateur', () {
    expect(m.specialites, isEmpty);
    expect(m.niveaux, isEmpty);
    expect(m.matieres, isEmpty);
    expect(m.etudiants, isEmpty);

    expect(s.comptes, hasLength(1));
    expect(s.comptes.single.identifiant, 'admin');
    expect(s.comptes.single.role, Role.superAdmin);
  });

  test('connexion : bon mot de passe, mauvais mot de passe, inconnu', () async {
    expect((await s.connecter('admin', 'faux')).ok, isFalse);
    expect((await s.connecter('fantome', 'admin')).ok, isFalse);

    final r = await s.connecter('admin', 'admin');
    expect(r.ok, isTrue);
    expect(s.estSuperAdmin, isTrue);
  });

  test('l\'identifiant est insensible à la casse', () async {
    expect((await s.connecter('ADMIN', 'admin')).ok, isTrue);
  });

  test('les écritures survivent à un rechargement', () async {
    await m.ajouterSpecialite('GL', 'Génie Logiciel', 'M. KUIMO');
    final gl = m.specialites.firstWhere((x) => x.abreviation == 'GL');

    await m.ajouterNiveau(gl.id, Palier.bts1);
    await m.ajouterNiveau(gl.id, Palier.bts2);
    final bts1 = m.niveauxDe(gl.id).firstWhere((n) => n.palier == Palier.bts1);

    await m.ajouterEtudiant('IUE001', 'Ange Tim', Sexe.f, bts1.id);
    await m.ajouterMatiere('ALG201', 'Algorithmique', bts1.id, 1);

    // Relecture complète depuis le disque.
    await m.charger();
    expect(m.specialites.any((x) => x.abreviation == 'GL'), isTrue);
    expect(m.etudiants.any((e) => e.matricule == 'IUE001'), isTrue);
    expect(m.matieres.any((x) => x.code == 'ALG201'), isTrue);
  });

  test('un palier ne peut être ouvert deux fois pour une spécialité', () async {
    final gl = m.specialites.firstWhere((x) => x.abreviation == 'GL');
    expect(
      () => m.ajouterNiveau(gl.id, Palier.bts1),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('la migration déplace les étudiants vers la promotion cible', () async {
    final gl = m.specialites.firstWhere((x) => x.abreviation == 'GL');
    final bts1 = m.niveauxDe(gl.id).firstWhere((n) => n.palier == Palier.bts1);
    final bts2 = m.niveauxDe(gl.id).firstWhere((n) => n.palier == Palier.bts2);

    final avant = m.etudiantsDe(bts1.id).map((e) => e.id).toList();
    expect(avant, isNotEmpty);

    await m.migrer(avant, bts2.id);
    await m.charger();

    expect(m.etudiantsDe(bts1.id), isEmpty);
    for (final id in avant) {
      expect(m.etudiants.firstWhere((e) => e.id == id).niveauId, bts2.id);
    }
  });

  test('supprimer une spécialité efface ses niveaux, matières et étudiants',
      () async {
    final gl = m.specialites.firstWhere((x) => x.abreviation == 'GL');
    final niveauIds = m.niveauxDe(gl.id).map((n) => n.id).toSet();

    await m.supprimerSpecialite(gl.id);
    await m.charger();

    expect(m.specialites.any((x) => x.id == gl.id), isFalse);
    expect(m.niveaux.any((n) => niveauIds.contains(n.id)), isFalse);
    // La cascade SQLite doit avoir emporté l'étudiant et la matière.
    expect(m.etudiants.any((e) => e.matricule == 'IUE001'), isFalse);
    expect(m.matieres.any((x) => x.code == 'ALG201'), isFalse);
  });

  test('console SQL : lecture, écriture et erreur', () async {
    await m.ajouterSpecialite('RS', 'Réseaux', 'M. TCHOUA');

    final lecture = await ConsoleSql.executer('SELECT * FROM specialite');
    expect(lecture.ok, isTrue);
    expect(lecture.estLecture, isTrue);
    expect(lecture.colonnes, contains('abreviation'));

    final erreur = await ConsoleSql.executer('SELECT * FROM table_absente');
    expect(erreur.ok, isFalse);
    expect(erreur.erreur, isNotNull);

    final ecriture = await ConsoleSql.executer(
        "UPDATE specialite SET responsable = 'M. X' WHERE abreviation = 'RS'");
    expect(ecriture.ok, isTrue);
    expect(ecriture.aEcrit, isTrue);
    expect(ecriture.affectees, 1);

    // Le verbe doit être détecté malgré un commentaire en tête.
    expect(ConsoleSql.estLecture('-- un commentaire\nSELECT 1'), isTrue);
    expect(ConsoleSql.estLecture('DELETE FROM etudiant'), isFalse);
  });

  test('export CSV : en-têtes, échappement et lignes complètes', () async {
    // Un intitulé contenant séparateur et guillemet doit rester lisible.
    // campus_id est obligatoire depuis le multi-campus.
    final insertion = await ConsoleSql.executer(
      "INSERT INTO specialite (id, campus_id, abreviation, intitule, responsable) "
      "VALUES ('SPE900', 'CMP001', 'X;Y', 'Dit \"Test\"', 'Mme A')",
    );
    expect(insertion.ok, isTrue);

    final r = await ConsoleSql.executerComplet(
        'SELECT abreviation, intitule FROM specialite ORDER BY id');
    final csv = r.versCsv();
    final lignes = csv.trim().split('\n');

    expect(lignes.first, contains('abreviation;intitule'));
    // Champ contenant le séparateur : entouré de guillemets.
    expect(csv, contains('"X;Y"'));
    // Guillemet interne : doublé.
    expect(csv, contains('"Dit ""Test"""'));
    // En-tête + une ligne par enregistrement.
    expect(lignes.length, r.lignes.length + 1);
  });

  test('l\'export CSV n\'est pas plafonné à l\'affichage', () async {
    // 600 lignes : au-delà de la limite d'affichage de 500.
    for (var i = 0; i < 600; i++) {
      await ConsoleSql.executer(
        "INSERT INTO utilisateur (id, identifiant, mot_de_passe, nom_complet, "
        "role, actif) VALUES ('T$i', 'temoin$i', 'x', 'Témoin $i', "
        "'enseignant', 1)",
      );
    }

    final affiche = await ConsoleSql.executer('SELECT id FROM utilisateur');
    expect(affiche.lignes, hasLength(ConsoleSql.limiteLignes));

    final complet =
        await ConsoleSql.executerComplet('SELECT id FROM utilisateur');
    expect(complet.lignes.length, greaterThan(ConsoleSql.limiteLignes));

    await ConsoleSql.executer("DELETE FROM utilisateur WHERE id LIKE 'T%'");
    await s.charger();
  });

  test('export : le fichier produit est une base lisible', () async {
    final destination = '${dossier.path}/copie.db';
    await BaseLocale.instance.exporterVers(destination);

    expect(File(destination).existsSync(), isTrue);

    final copie = await databaseFactory.openDatabase(destination);
    final lignes = await copie.query('utilisateur');
    expect(lignes, isNotEmpty);
    await copie.close();
  });

  test('un compte désactivé ne peut plus se connecter', () async {
    await s.ajouterCompte('kuimo', 'kuimo', 'Marc Kuimo', Role.enseignant);
    final marc = s.comptes.firstWhere((c) => c.identifiant == 'kuimo');

    await s.majCompte(marc, marc.identifiant, marc.nomComplet, marc.role, false);
    expect((await s.connecter('kuimo', 'kuimo')).ok, isFalse);

    await s.majCompte(marc, marc.identifiant, marc.nomComplet, marc.role, true);
    expect((await s.connecter('kuimo', 'kuimo')).ok, isTrue);
  });

  test('deux comptes ne peuvent pas partager un identifiant', () async {
    expect(
      () => s.ajouterCompte('admin', 'x1234', 'Doublon', Role.enseignant),
      throwsA(isA<DatabaseException>()),
    );
  });
}
