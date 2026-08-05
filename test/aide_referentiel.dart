import 'dart:io';

import 'package:estuaire_examen/data/import_dump_insam.dart';

/// Référentiel de test, construit depuis le dump du dépôt.
///
/// Il n'est plus embarqué dans l'application — c'est l'administrateur qui
/// téléverse le dump — donc les tests le reconstruisent. La conversion
/// n'est faite qu'une fois par exécution : elle prend quelques secondes,
/// et une dizaine de tests s'en servent.
String? _cache;

Future<String> referentielDeTest() async {
  final connu = _cache;
  if (connu != null && await File(connu).exists()) return connu;

  final dump = File('databases/insam/insamdigitale_stools.sql');
  if (!await dump.exists()) {
    throw StateError('Dump INSAM absent : ${dump.path}');
  }

  final dossier = await Directory.systemTemp.createTemp('referentiel-test');
  final destination = '${dossier.path}/reference.db';
  await ImportDumpInsam.convertir(dump: dump, destination: destination);
  return _cache = destination;
}
