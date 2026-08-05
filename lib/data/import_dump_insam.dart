/// Lecture d'un dump MySQL d'INSAM et reconstruction du référentiel local.
library;

import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Tables retenues du dump, avec les colonnes conservées.
///
/// `composer` est volontairement exclue : elle porte les notes
/// historiques — 85 % du fichier — dont nous n'avons aucun usage, et son
/// exclusion fait tomber un dump de 15 Mo à moins de 2 Mo utiles.
const _tables = <String, List<String>>{
  'annee': ['id_annee', 'intitule_annee', 'etat_annee'],
  'cycle': ['id_cycle', 'code_cycle', 'intitule_cycle'],
  'ecole': ['id_ecole', 'code_ecole', 'intitule_ecole'],
  'niveau': ['id_niveau', 'code_niveau', 'intitule_niveau'],
  'examen': ['id_examen', 'code_examen', 'intitule_examen'],
  'filiere': [
    'id_filiere', 'id_ecole', 'id_cycle', 'code_filiere', 'intitule_filiere',
  ],
  'specialite': [
    'id_specialite', 'id_filiere', 'id_niveau', 'id_annee',
    'code_specialite', 'intitule_specialite', 'periode_specialite',
  ],
  'matiere': ['id_matiere', 'code_matiere', 'intitule_matiere'],
  'module': ['id_module', 'code_module', 'intitule_module', 'categorie'],
  'appartenir': [
    'id_appartenir', 'id_specialite', 'id_annee', 'id_matiere', 'id_module',
    'code_matiere', 'credit_matiere', 'heures_matieres', 'semestre_matiere',
  ],
  'inscrire': ['id_inscrire', 'id_etudiant', 'id_specialite', 'id_annee'],
  'etudiant': [
    'id_etudiant', 'matricule_etudiant', 'nom_etudiant', 'prenom_etudiant',
    'sexe_etudiant', 'date_naissance_etudiant', 'lieu_naissance_etudiant',
  ],
};

/// Colonnes stockées en entier ; sans typage explicite SQLite les
/// garderait en texte et `WHERE id_etudiant = 22713` ne trouverait rien.
bool _estEntier(String colonne) =>
    colonne.startsWith('id_') || colonne == 'semestre_matiere';

bool _estReel(String colonne) =>
    colonne == 'credit_matiere' || colonne == 'heures_matieres';

/// Avancement de la conversion, pour le loader de l'écran d'import.
class EtapeDump {
  final String libelle;
  final double progression;

  const EtapeDump(this.libelle, this.progression);
}

/// Ce qu'un dump a livré, table par table.
class BilanDump {
  final Map<String, int> lignes;

  const BilanDump(this.lignes);

  int get total => lignes.values.fold(0, (t, n) => t + n);
}

/// Convertit un dump MySQL en base SQLite de référence.
///
/// Le travail se fait dans un isolat : le fichier pèse une quinzaine de
/// mégaoctets, et l'analyser sur le fil principal figerait l'interface.
class ImportDumpInsam {
  ImportDumpInsam._();

  /// Répare le mojibake du dump.
  ///
  /// Le dump contient de l'UTF-8 relu comme du cp1252 puis ré-encodé :
  /// « SAÃDOU » au lieu de « SAÏDOU ». Certains noms ont subi le tour
  /// deux fois (« MAÃ‹LLE » pour « MAËLLE »), d'où la répétition. Sans ce
  /// passage, les noms partiraient corrompus dans l'Excel remis à INSAM.
  static String reparerEncodage(String texte) {
    for (var i = 0; i < 3; i++) {
      if (texte.isEmpty || !(texte.contains('Ã') || texte.contains('Â'))) {
        break;
      }
      final repare = _decoder(texte);
      if (repare == null || repare == texte || repare.contains('�')) {
        break;
      }
      texte = repare;
    }
    return texte;
  }

  /// Réinterprète la chaîne comme de l'UTF-8 mal décodé.
  static String? _decoder(String texte) {
    final octets = <int>[];
    for (final unite in texte.runes) {
      if (unite < 0x100) {
        octets.add(unite);
        continue;
      }
      // Caractères propres à cp1252, absents de latin-1 : « ‹ » (U+2039)
      // apparaît dans le mojibake et doit retrouver son octet d'origine.
      final octet = _cp1252[unite];
      if (octet == null) return null;
      octets.add(octet);
    }
    try {
      return const Utf8Decoder(allowMalformed: false).convert(octets);
    } catch (_) {
      return null;
    }
  }

  /// Correspondance inverse des caractères cp1252 hors latin-1.
  static const _cp1252 = <int, int>{
    0x20AC: 0x80, 0x201A: 0x82, 0x0192: 0x83, 0x201E: 0x84,
    0x2026: 0x85, 0x2020: 0x86, 0x2021: 0x87, 0x02C6: 0x88,
    0x2030: 0x89, 0x0160: 0x8A, 0x2039: 0x8B, 0x0152: 0x8C,
    0x017D: 0x8E, 0x2018: 0x91, 0x2019: 0x92, 0x201C: 0x93,
    0x201D: 0x94, 0x2022: 0x95, 0x2013: 0x96, 0x2014: 0x97,
    0x02DC: 0x98, 0x2122: 0x99, 0x0161: 0x9A, 0x203A: 0x9B,
    0x0153: 0x9C, 0x017E: 0x9E, 0x0178: 0x9F,
  };

  /// Découpe une ligne `(1, 'abc', NULL, 2.5)` en valeurs.
  ///
  /// Un simple découpage sur la virgule ne suffit pas : les libellés en
  /// contiennent, ainsi que des apostrophes échappées (`\'` et `''`).
  static List<String?> decouperValeurs(String ligne) {
    var l = ligne.trim();
    while (l.endsWith(',') || l.endsWith(';')) {
      l = l.substring(0, l.length - 1);
    }
    if (!l.startsWith('(') || !l.endsWith(')')) return const [];
    final corps = l.substring(1, l.length - 1);

    final valeurs = <String?>[];
    final courant = StringBuffer();
    var dansChaine = false;
    var estChaine = false;
    var i = 0;

    while (i < corps.length) {
      final c = corps[i];
      if (dansChaine) {
        if (c == r'\' && i + 1 < corps.length) {
          final suivant = corps[i + 1];
          courant.write(switch (suivant) {
            'n' => '\n',
            't' => '\t',
            'r' => '\r',
            '0' => '',
            _ => suivant,
          });
          i += 2;
          continue;
        }
        if (c == "'") {
          // '' à l'intérieur d'une chaîne : une apostrophe littérale.
          if (i + 1 < corps.length && corps[i + 1] == "'") {
            courant.write("'");
            i += 2;
            continue;
          }
          dansChaine = false;
          i++;
          continue;
        }
        courant.write(c);
        i++;
        continue;
      }
      if (c == "'") {
        dansChaine = true;
        estChaine = true;
        // Le dump sépare les valeurs par « , » : l'espace qui précède
        // l'apostrophe ouvrante n'appartient pas au libellé.
        courant.clear();
        i++;
        continue;
      }
      if (c == ',') {
        valeurs.add(_valeur(courant.toString(), estChaine));
        courant.clear();
        estChaine = false;
        i++;
        continue;
      }
      courant.write(c);
      i++;
    }
    valeurs.add(_valeur(courant.toString(), estChaine));
    return valeurs;
  }

  static String? _valeur(String brut, bool estChaine) {
    if (estChaine) return brut;
    final net = brut.trim();
    return net == 'NULL' || net.isEmpty ? null : net;
  }

  /// Analyse [dump] et écrit la base de référence à [destination].
  ///
  /// [progression] est appelée au fil de l'eau pour alimenter le loader.
  static Future<BilanDump> convertir({
    required File dump,
    required String destination,
    void Function(EtapeDump)? progression,
  }) async {
    progression?.call(const EtapeDump('Lecture du fichier…', 0.05));
    final contenu = await dump.readAsString();

    // On écrit à côté puis on renomme : si la conversion échoue, le
    // référentiel précédent reste intact.
    final provisoire = '$destination.nouveau';
    final ancien = File(provisoire);
    if (await ancien.exists()) await ancien.delete();

    final base = await databaseFactory.openDatabase(provisoire);
    final compte = <String, int>{};

    try {
      await base.execute('PRAGMA journal_mode = OFF');

      var faites = 0;
      for (final entree in _tables.entries) {
        final table = entree.key;
        final colonnes = entree.value;

        progression?.call(EtapeDump(
          'Lecture de « $table »…',
          0.05 + 0.8 * (faites / _tables.length),
        ));

        final lignes = _lireTable(contenu, table, colonnes);
        compte[table] = lignes.length;

        final declarations = colonnes
            .map((c) => '$c ${_estEntier(c) ? 'INTEGER' : _estReel(c) ? 'REAL' : 'TEXT'}')
            .join(', ');
        await base.execute('CREATE TABLE $table ($declarations)');

        final lot = base.batch();
        for (final ligne in lignes) {
          lot.insert(table, ligne);
        }
        await lot.commit(noResult: true);
        faites++;
      }

      progression?.call(const EtapeDump('Indexation…', 0.9));
      for (final requete in const [
        'CREATE INDEX i_spec_filiere ON specialite(id_filiere)',
        'CREATE INDEX i_spec_annee ON specialite(id_annee, id_niveau)',
        'CREATE INDEX i_appartenir_spec ON appartenir(id_specialite, id_annee)',
        'CREATE INDEX i_inscrire_spec ON inscrire(id_specialite, id_annee)',
        'CREATE INDEX i_inscrire_etudiant ON inscrire(id_etudiant)',
        'CREATE INDEX i_etudiant_nom ON etudiant(nom_etudiant)',
      ]) {
        await base.execute(requete);
      }
    } finally {
      await base.close();
    }

    progression?.call(const EtapeDump('Enregistrement…', 0.97));
    final cible = File(destination);
    if (await cible.exists()) await cible.delete();
    await File(provisoire).rename(destination);

    progression?.call(const EtapeDump('Terminé', 1));
    return BilanDump(compte);
  }

  /// Extrait les lignes d'une table, tous blocs INSERT confondus.
  ///
  /// Le dump découpe chaque table en plusieurs INSERT — jusqu'à 231 pour
  /// `composer` — et ne lire que le premier ferait perdre la quasi-
  /// totalité des données.
  static List<Map<String, Object?>> _lireTable(
      String dump, String table, List<String> voulues) {
    final resultat = <Map<String, Object?>>[];
    final motif = RegExp(
      'INSERT INTO `$table` \\(([^)]*)\\) VALUES\\s*\\n',
      caseSensitive: false,
    );

    for (final entete in motif.allMatches(dump)) {
      final colonnes = entete
          .group(1)!
          .split(',')
          .map((c) => c.trim().replaceAll('`', ''))
          .toList();

      // Position de chaque colonne voulue : l'ordre n'est pas garanti
      // d'un dump à l'autre.
      final indices = <int>[];
      var complet = true;
      for (final v in voulues) {
        final i = colonnes.indexOf(v);
        if (i < 0) {
          complet = false;
          break;
        }
        indices.add(i);
      }
      if (!complet) continue;

      // Le bloc court jusqu'au point-virgule en fin de ligne.
      var debut = entete.end;
      while (debut < dump.length) {
        final finLigne = dump.indexOf('\n', debut);
        final ligne =
            (finLigne < 0 ? dump.substring(debut) : dump.substring(debut, finLigne))
                .trim();

        if (ligne.isNotEmpty && ligne.startsWith('(')) {
          final valeurs = decouperValeurs(ligne);
          if (valeurs.length == colonnes.length) {
            final enregistrement = <String, Object?>{};
            for (var k = 0; k < voulues.length; k++) {
              enregistrement[voulues[k]] =
                  _convertir(voulues[k], valeurs[indices[k]]);
            }
            resultat.add(enregistrement);
          }
        }

        final termine = ligne.endsWith(';');
        if (finLigne < 0 || termine) break;
        debut = finLigne + 1;
      }
    }
    return resultat;
  }

  static Object? _convertir(String colonne, String? valeur) {
    if (valeur == null) return null;
    if (_estEntier(colonne)) return int.tryParse(valeur.trim());
    if (_estReel(colonne)) return double.tryParse(valeur.trim());
    return decoderEntites(reparerEncodage(valeur));
  }

  /// Décode les entités HTML laissées par la saisie web d'INSAM.
  ///
  /// Le dump contient « L&#039;ENTREPRISE » là où il faut lire
  /// « L'ENTREPRISE » : sans ce passage, l'entité s'imprimerait telle
  /// quelle sur les fiches de notes et dans l'export.
  ///
  /// Certains libellés ont été encodés deux fois — « L&amp;#039;ANALYSE »
  /// — d'où la répétition jusqu'à stabilisation.
  static String decoderEntites(String texte) {
    for (var i = 0; i < 3; i++) {
      final decode = _decoderUnePasse(texte);
      if (decode == texte) break;
      texte = decode;
    }
    return texte;
  }

  static String _decoderUnePasse(String texte) {
    if (!texte.contains('&')) return texte;

    // La casse varie dans le dump : « &amp; » comme « &AMP; ».
    return texte
        .replaceAllMapped(
          RegExp(r'&#(\d+);'),
          (m) {
            final point = int.tryParse(m.group(1)!);
            return point == null ? m.group(0)! : String.fromCharCode(point);
          },
        )
        .replaceAllMapped(
          RegExp(r'&#x([0-9a-fA-F]+);', caseSensitive: false),
          (m) {
            final point = int.tryParse(m.group(1)!, radix: 16);
            return point == null ? m.group(0)! : String.fromCharCode(point);
          },
        )
        .replaceAll(RegExp('&quot;', caseSensitive: false), '"')
        .replaceAll(RegExp('&apos;', caseSensitive: false), "'")
        .replaceAll(RegExp('&nbsp;', caseSensitive: false), ' ')
        .replaceAll(RegExp('&lt;', caseSensitive: false), '<')
        .replaceAll(RegExp('&gt;', caseSensitive: false), '>')
        // En dernier : sinon « &amp;#039; » se décoderait en une passe,
        // alors que la répétition s'en charge proprement.
        .replaceAll(RegExp('&amp;', caseSensitive: false), '&');
  }
}

/// Décodeur UTF-8 minimal, pour réparer le mojibake sans dépendance.
class Utf8Decoder {
  final bool allowMalformed;
  const Utf8Decoder({this.allowMalformed = false});

  String convert(List<int> octets) {
    final sortie = StringBuffer();
    var i = 0;
    while (i < octets.length) {
      final o = octets[i];
      int point;
      int suite;

      if (o < 0x80) {
        point = o;
        suite = 0;
      } else if (o >= 0xC2 && o <= 0xDF) {
        point = o & 0x1F;
        suite = 1;
      } else if (o >= 0xE0 && o <= 0xEF) {
        point = o & 0x0F;
        suite = 2;
      } else if (o >= 0xF0 && o <= 0xF4) {
        point = o & 0x07;
        suite = 3;
      } else {
        throw const FormatException('octet de tête invalide');
      }

      if (i + suite >= octets.length) {
        throw const FormatException('séquence tronquée');
      }
      for (var k = 1; k <= suite; k++) {
        final s = octets[i + k];
        if (s < 0x80 || s > 0xBF) {
          throw const FormatException('octet de continuation invalide');
        }
        point = (point << 6) | (s & 0x3F);
      }

      sortie.writeCharCode(point);
      i += suite + 1;
    }
    return sortie.toString();
  }
}
