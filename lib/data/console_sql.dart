import 'base_locale.dart';

/// Résultat d'une requête saisie dans la console SQL.
class ResultatSql {
  final List<String> colonnes;
  final List<List<Object?>> lignes;

  /// Nombre de lignes touchées par une écriture (INSERT/UPDATE/DELETE).
  final int? affectees;
  final String? erreur;
  final Duration duree;

  /// Vrai si la requête a modifié la base : l'appelant doit recharger.
  final bool aEcrit;

  const ResultatSql({
    this.colonnes = const [],
    this.lignes = const [],
    this.affectees,
    this.erreur,
    this.duree = Duration.zero,
    this.aEcrit = false,
  });

  bool get ok => erreur == null;
  bool get estLecture => colonnes.isNotEmpty;

  /// Rend le jeu de résultats au format CSV (séparateur point-virgule,
  /// celui qu'attend Excel en configuration française).
  ///
  /// Le BOM en tête évite qu'Excel n'affiche « MbargaÌ » au lieu de « Mbarga ».
  String versCsv({String separateur = ';'}) {
    String champ(Object? valeur) {
      if (valeur == null) return '';
      final texte = valeur.toString();
      // Guillemets obligatoires si le contenu porte séparateur, guillemet
      // ou saut de ligne ; les guillemets internes se doublent.
      if (texte.contains(separateur) ||
          texte.contains('"') ||
          texte.contains('\n') ||
          texte.contains('\r')) {
        return '"${texte.replaceAll('"', '""')}"';
      }
      return texte;
    }

    final tampon = StringBuffer('﻿');
    tampon.writeln(colonnes.map(champ).join(separateur));
    for (final ligne in lignes) {
      tampon.writeln(ligne.map(champ).join(separateur));
    }
    return tampon.toString();
  }
}

/// Exécute les requêtes libres de la rubrique « Base de données ».
class ConsoleSql {
  ConsoleSql._();

  /// Au-delà, on tronque : une console n'a pas à afficher un million de lignes.
  static const limiteLignes = 500;

  /// Mots-clés qui produisent un jeu de résultats plutôt qu'un décompte.
  static const _lectures = {'select', 'with', 'pragma', 'explain'};

  static bool estLecture(String sql) {
    final premier = _premierMot(sql);
    return _lectures.contains(premier);
  }

  static String _premierMot(String sql) {
    // Retire les commentaires de tête pour ne pas se tromper de verbe.
    final nettoye = sql
        .replaceAll(RegExp(r'--[^\n]*'), ' ')
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), ' ')
        .trim();
    final mot = RegExp(r'^\s*([A-Za-z]+)').firstMatch(nettoye);
    return mot?.group(1)?.toLowerCase() ?? '';
  }

  /// Rejoue une requête de lecture sans plafond de lignes.
  /// L'affichage se limite à [limiteLignes], mais un export CSV doit
  /// contenir la totalité du résultat.
  static Future<ResultatSql> executerComplet(String sql) =>
      executer(sql, limite: null);

  /// Exécute [sql] sur la base locale.
  /// Une seule instruction à la fois : c'est ce que permet sqflite.
  static Future<ResultatSql> executer(String sql, {int? limite = limiteLignes}) async {
    final requete = sql.trim().replaceAll(RegExp(r';\s*$'), '');
    if (requete.isEmpty) {
      return const ResultatSql(erreur: 'Saisissez une requête.');
    }

    final db = BaseLocale.instance.db;
    final chrono = Stopwatch()..start();

    try {
      if (estLecture(requete)) {
        final lignes = await db.rawQuery(requete);
        chrono.stop();

        if (lignes.isEmpty) {
          return ResultatSql(
            colonnes: const ['résultat'],
            lignes: const [
              ['Aucune ligne.']
            ],
            duree: chrono.elapsed,
          );
        }

        final colonnes = lignes.first.keys.toList();
        final tronquees = limite == null ? lignes : lignes.take(limite);
        return ResultatSql(
          colonnes: colonnes,
          lignes: [
            for (final l in tronquees) [for (final c in colonnes) l[c]],
          ],
          affectees: lignes.length,
          duree: chrono.elapsed,
        );
      }

      // Écriture : on renvoie le nombre de lignes touchées.
      final verbe = _premierMot(requete);
      int? touchees;
      if (verbe == 'insert') {
        await db.rawInsert(requete);
        touchees = 1;
      } else if (verbe == 'update') {
        touchees = await db.rawUpdate(requete);
      } else if (verbe == 'delete') {
        touchees = await db.rawDelete(requete);
      } else {
        // CREATE, DROP, ALTER, VACUUM…
        await db.execute(requete);
      }
      chrono.stop();

      return ResultatSql(
        affectees: touchees,
        duree: chrono.elapsed,
        aEcrit: true,
      );
    } catch (e) {
      chrono.stop();
      return ResultatSql(erreur: '$e', duree: chrono.elapsed);
    }
  }

  /// Schéma réel de la base, lu depuis SQLite.
  static Future<Map<String, List<String>>> schema() async {
    final db = BaseLocale.instance.db;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );

    final resultat = <String, List<String>>{};
    for (final t in tables) {
      final nom = t['name'] as String;
      final colonnes = await db.rawQuery('PRAGMA table_info($nom)');
      resultat[nom] = [for (final c in colonnes) c['name'] as String];
    }
    return resultat;
  }
}
