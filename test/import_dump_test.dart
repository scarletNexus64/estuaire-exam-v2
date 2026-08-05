import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:estuaire_examen/data/import_dump_insam.dart';

/// Conversion du dump MySQL par l'application elle-même.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const dump = 'databases/insam/insamdigitale_stools.sql';

  test('le découpage respecte les apostrophes et les NULL', () {
    expect(
      ImportDumpInsam.decouperValeurs("(1, 'abc', NULL, 2.5),"),
      [1.toString(), 'abc', null, '2.5'],
    );
    // Virgule dans un libellé : elle ne doit pas couper la valeur.
    expect(
      ImportDumpInsam.decouperValeurs("(1, 'COMMERCE, VENTE')"),
      ['1', 'COMMERCE, VENTE'],
    );
    // Apostrophe échappée, dans les deux conventions de MySQL.
    expect(
      ImportDumpInsam.decouperValeurs(r"(1, 'L\'ECOLE')"),
      ['1', "L'ECOLE"],
    );
    expect(
      ImportDumpInsam.decouperValeurs("(1, 'L''ECOLE')"),
      ['1', "L'ECOLE"],
    );
    // Chaîne vide : à distinguer de NULL.
    expect(ImportDumpInsam.decouperValeurs("(1, '', NULL)"),
        ['1', '', null]);
  });

  test('le mojibake est réparé, y compris le double encodage', () {
    expect(ImportDumpInsam.reparerEncodage('GAMBO SALAMATOU SAÃÂDOU'
        .replaceAll('ÃÂ', 'Ã')), 'GAMBO SALAMATOU SAÏDOU');
    // Double encodage, via un caractère propre à cp1252.
    expect(ImportDumpInsam.reparerEncodage('KOUOKAM MAÃÂLLE'),
        'KOUOKAM MAËLLE');
    // Un texte déjà propre n'est pas abîmé.
    expect(ImportDumpInsam.reparerEncodage('MAËLLE'), 'MAËLLE');
    expect(ImportDumpInsam.reparerEncodage('SIMPLE'), 'SIMPLE');
  });

  test('les entités HTML de la saisie web sont décodées', () {
    expect(ImportDumpInsam.decoderEntites('L&#039;ENTREPRISE'),
        "L'ENTREPRISE");
    expect(ImportDumpInsam.decoderEntites('EAU &amp; ENERGIE'),
        'EAU & ENERGIE');
    expect(ImportDumpInsam.decoderEntites('DIT &quot;PRO&quot;'),
        'DIT "PRO"');
    // Un texte sans entité n'est pas touché.
    expect(ImportDumpInsam.decoderEntites('SIMPLE'), 'SIMPLE');
    // Double encodage : « &amp;#039; » doit remonter jusqu'à l'apostrophe.
    expect(ImportDumpInsam.decoderEntites("L&amp;#039;ANALYSE"),
        "L'ANALYSE");
  });

  test('la conversion du dump reproduit le référentiel attendu', () async {
    final fichier = File(dump);
    if (!await fichier.exists()) {
      markTestSkipped('dump absent');
      return;
    }

    final dossier = await Directory.systemTemp.createTemp('dump-test');
    final destination = '${dossier.path}/reference.db';

    final etapes = <double>[];
    final bilan = await ImportDumpInsam.convertir(
      dump: fichier,
      destination: destination,
      progression: (e) => etapes.add(e.progression),
    );

    // Les effectifs relevés dans le dump d'origine.
    expect(bilan.lignes['etudiant'], 5230);
    expect(bilan.lignes['matiere'], 3439);
    expect(bilan.lignes['specialite'], 994);
    expect(bilan.lignes['inscrire'], 7676);
    expect(bilan.lignes['appartenir'], 19150);
    expect(bilan.lignes['annee'], 4);

    // Le loader doit progresser jusqu'au bout.
    expect(etapes.first, lessThan(0.2));
    expect(etapes.last, 1);

    final base = await databaseFactory.openDatabase(destination,
        options: OpenDatabaseOptions(readOnly: true));

    // La promotion du modèle fourni par INSAM.
    final etudiants = await base.rawQuery(
        'SELECT COUNT(*) c FROM inscrire WHERE id_specialite = 1251 '
        'AND id_annee = 4');
    expect(etudiants.first['c'], 76);

    final matiere = await base.rawQuery(
        'SELECT intitule_matiere FROM matiere WHERE id_matiere = 421');
    expect(matiere.first['intitule_matiere'], 'BASE DE DONNEES ET SQL');

    // Les identifiants doivent être numériques, sinon les jointures et
    // les comparaisons de l'export échouent silencieusement.
    final typage = await base.rawQuery(
        'SELECT typeof(id_etudiant) t FROM etudiant LIMIT 1');
    expect(typage.first['t'], 'integer');

    // L'encodage : au plus deux noms résistent, irrécupérables dans le
    // dump lui-même (un octet y a été perdu).
    final mojibake = await base.rawQuery(
        "SELECT COUNT(*) c FROM etudiant WHERE nom_etudiant LIKE '%Ã%'");
    expect(mojibake.first['c'], lessThanOrEqualTo(2));

    final accentue = await base.rawQuery(
        "SELECT nom_etudiant FROM etudiant WHERE id_etudiant = 22740");
    expect(accentue.first['nom_etudiant'], 'KOUOKAM KEMMEGNE MAËLLE TRACY');

    // Aucune entité HTML ne doit subsister : elles s'imprimeraient telles
    // quelles sur les fiches officielles.
    for (final table in const ['specialite', 'matiere', 'module']) {
      final colonne = table == 'module'
          ? 'intitule_module'
          : 'intitule_$table';
      final entites = await base.rawQuery(
          "SELECT COUNT(*) c FROM $table WHERE $colonne LIKE '%&#%' "
          "OR $colonne LIKE '%&amp;%' OR $colonne LIKE '%&quot;%'");
      expect(entites.first['c'], 0, reason: '$table contient des entités');
    }

    await base.close();
    await dossier.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
