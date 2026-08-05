/// Import d'une promotion INSAM et correspondance des identifiants.
library;

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'base_locale.dart';
import 'magasin.dart';
import 'magasin_campus.dart';
import 'modeles.dart';
import 'referentiel_insam.dart';

/// Entités susceptibles de porter un identifiant INSAM.
class EntiteInsam {
  static const etudiant = 'etudiant';
  static const matiere = 'matiere';
  static const niveau = 'niveau';
}

/// Ce qu'un import a produit dans un campus donné.
class BilanCampus {
  final String campusId;
  final String campusIntitule;
  final int etudiantsAjoutes;
  final int etudiantsExistants;
  final int matieresAjoutees;
  final int matieresExistantes;

  /// Vrai si le campus ne reçoit que la structure, sans les étudiants.
  final bool sansEtudiants;

  const BilanCampus({
    required this.campusId,
    required this.campusIntitule,
    required this.etudiantsAjoutes,
    required this.etudiantsExistants,
    required this.matieresAjoutees,
    required this.matieresExistantes,
    required this.sansEtudiants,
  });

  int get totalEtudiants => etudiantsAjoutes + etudiantsExistants;
  int get totalMatieres => matieresAjoutees + matieresExistantes;
}

/// Résultat d'un import, pour le compte rendu affiché à l'utilisateur.
class BilanImport {
  final List<BilanCampus> campus;

  const BilanImport(this.campus);

  int get etudiantsAjoutes =>
      campus.fold(0, (t, c) => t + c.etudiantsAjoutes);
  int get matieresAjoutees => campus.fold(0, (t, c) => t + c.matieresAjoutees);
  int get campusServis => campus.length;
}

/// Fait le pont entre le référentiel INSAM et notre base de travail.
///
/// L'import ne recopie pas tout INSAM : l'utilisateur choisit une
/// promotion, et seuls ses étudiants et ses matières entrent chez nous.
/// À chaque insertion, l'identifiant INSAM est mémorisé dans
/// `correspondance_insam` — c'est ce qui permettra plus tard de produire
/// un export que le système central accepte tel quel.
class MagasinInsam extends ChangeNotifier {
  static final MagasinInsam instance = MagasinInsam._();
  MagasinInsam._();

  Database get _db => BaseLocale.instance.db;

  // ---------- Correspondances ----------

  /// Identifiant INSAM d'une de nos entités, ou null si elle n'en a pas.
  Future<int?> idDistant(String entite, String idLocal) async {
    final r = await _db.query(
      'correspondance_insam',
      columns: ['id_distant'],
      where: 'entite = ? AND id_local = ?',
      whereArgs: [entite, idLocal],
      limit: 1,
    );
    return r.isEmpty ? null : r.first['id_distant'] as int;
  }

  /// Toutes les correspondances d'un type, indexées par identifiant local.
  ///
  /// L'export en a besoin pour une promotion entière : une requête plutôt
  /// qu'une par étudiant.
  Future<Map<String, int>> correspondances(String entite) async {
    final lignes = await _db.query(
      'correspondance_insam',
      columns: ['id_local', 'id_distant'],
      where: 'entite = ?',
      whereArgs: [entite],
    );
    return {
      for (final l in lignes)
        l['id_local'] as String: l['id_distant'] as int,
    };
  }

  Future<void> _lier(
      DatabaseExecutor db, String entite, String idLocal, int idDistant) {
    return db.insert(
      'correspondance_insam',
      {'entite': entite, 'id_local': idLocal, 'id_distant': idDistant},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---------- Import ----------

  /// Campus qui ne reçoivent pas les étudiants par défaut.
  ///
  /// Bamboutos dépend de l'annexe de Mbouda et n'accueille pas les
  /// promotions de Bafoussam : on y installe le programme — spécialités,
  /// promotions et matières — pour que l'enseignant puisse préparer ses
  /// épreuves, mais les effectifs restent vides. L'écran d'import laisse
  /// revenir sur ce choix.
  static const campusSansEtudiants = {'CMP007'};

  /// Importe toutes les promotions d'une année académique.
  ///
  /// C'est l'opération courante après le téléversement d'un dump : on ne
  /// choisit pas promotion par promotion, on reprend l'année entière.
  /// Seuls les écarts sont écrits — ce qui existe déjà est laissé en
  /// place — si bien qu'un import répété ne coûte que la comparaison.
  Future<BilanImport> importerAnnee({
    required int idAnnee,
    required Set<String> campusIds,
    Set<String>? sansEtudiants,
    void Function(String etape, double progression)? progression,
  }) async {
    final promotions = await ReferentielInsam.instance.promotions(idAnnee);
    if (promotions.isEmpty) {
      throw StateError('Aucune promotion pour cette année académique.');
    }
    if (campusIds.isEmpty) {
      throw StateError('Aucun campus destinataire.');
    }

    final exclus = sansEtudiants ?? campusSansEtudiants;
    final cumul = <String, BilanCampus>{};

    for (var i = 0; i < promotions.length; i++) {
      final promo = promotions[i];
      progression?.call(
        '${promo.intitule} (${i + 1}/${promotions.length})',
        i / promotions.length,
      );

      final bilan = await importerPromotion(
        promo,
        campusIds: campusIds,
        sansEtudiants: exclus,
        rafraichir: false,
      );

      for (final b in bilan.campus) {
        final ancien = cumul[b.campusId];
        cumul[b.campusId] = ancien == null
            ? b
            : BilanCampus(
                campusId: b.campusId,
                campusIntitule: b.campusIntitule,
                etudiantsAjoutes:
                    ancien.etudiantsAjoutes + b.etudiantsAjoutes,
                etudiantsExistants:
                    ancien.etudiantsExistants + b.etudiantsExistants,
                matieresAjoutees:
                    ancien.matieresAjoutees + b.matieresAjoutees,
                matieresExistantes:
                    ancien.matieresExistantes + b.matieresExistantes,
                sansEtudiants: b.sansEtudiants,
              );
      }
    }

    progression?.call('Actualisation…', 1);
    await Magasin.instance.charger();
    notifyListeners();

    return BilanImport(cumul.values.toList());
  }

  /// Importe une promotion INSAM dans tous les campus.
  ///
  /// Tous les campus travaillent sur le même programme : plutôt que de
  /// demander à l'utilisateur de rejouer l'import campus par campus, on
  /// duplique la promotion partout en une passe. Chaque campus reçoit ses
  /// propres lignes — le schéma rattache les données au campus par la
  /// spécialité — et donc ses propres correspondances INSAM, toutes
  /// pointant vers les mêmes identifiants centraux.
  ///
  /// Rejouer l'import est sans danger : ce qui est déjà présent — reconnu
  /// à son identifiant INSAM — est laissé en place, seuls les nouveaux
  /// sont créés. C'est le cas d'usage normal quand INSAM inscrit un
  /// étudiant en cours d'année.
  Future<BilanImport> importerPromotion(
    PromotionInsam promo, {
    Set<String>? campusIds,
    Set<String>? sansEtudiants,
    bool rafraichir = true,
  }) async {
    final exclus = sansEtudiants ?? campusSansEtudiants;
    final tousCampus = MagasinCampus.instance.campus
        .where((c) => campusIds == null || campusIds.contains(c.id))
        .toList();
    if (tousCampus.isEmpty) {
      throw StateError('Aucun campus n\'est configuré.');
    }

    final etudiantsDistants =
        await ReferentielInsam.instance.etudiants(promo);
    final matieresDistantes = await ReferentielInsam.instance.matieres(promo);

    final bilans = <BilanCampus>[];

    // Tout dans une transaction : un import interrompu ne doit pas
    // laisser une promotion à moitié peuplée.
    await _db.transaction((txn) async {
      for (final campus in tousCampus) {
        final campusSans = exclus.contains(campus.id);

        final specialiteId = await _specialite(txn, campus.id, promo);
        final niveauId = await _niveau(txn, specialiteId, promo);

        var matieresAjoutees = 0;
        var matieresExistantes = 0;
        final matieresConnues =
            await _distantsDuNiveau(txn, EntiteInsam.matiere, 'matiere', niveauId);
        for (final m in matieresDistantes) {
          if (matieresConnues.contains(m.id)) {
            matieresExistantes++;
            continue;
          }
          final id = await _nouvelId(txn, 'MAT', 'matiere');
          await txn.insert('matiere', {
            'id': id,
            'code': m.code,
            'intitule': m.intitule,
            'niveau_id': niveauId,
            'semestre': m.semestre,
          });
          await _lier(txn, EntiteInsam.matiere, id, m.id);
          matieresAjoutees++;
        }

        var etudiantsAjoutes = 0;
        var etudiantsExistants = 0;
        if (!campusSans) {
          final etudiantsConnus = await _distantsDuNiveau(
              txn, EntiteInsam.etudiant, 'etudiant', niveauId);
          for (final e in etudiantsDistants) {
            if (etudiantsConnus.contains(e.id)) {
              etudiantsExistants++;
              continue;
            }
            final id = await _nouvelId(txn, 'ETU', 'etudiant');
            await txn.insert('etudiant', {
              'id': id,
              'matricule': e.matricule,
              'nom_complet': e.nomComplet,
              'sexe': e.sexeModele.code,
              'niveau_id': niveauId,
              'actif': 1,
            });
            await _lier(txn, EntiteInsam.etudiant, id, e.id);
            etudiantsAjoutes++;
          }
        }

        bilans.add(BilanCampus(
          campusId: campus.id,
          campusIntitule: campus.intitule,
          etudiantsAjoutes: etudiantsAjoutes,
          etudiantsExistants: etudiantsExistants,
          matieresAjoutees: matieresAjoutees,
          matieresExistantes: matieresExistantes,
          sansEtudiants: campusSans,
        ));
      }
    });

    // Le magasin principal tient les données en mémoire : sans ce
    // rechargement, les écrans continueraient d'afficher l'état d'avant.
    // L'import d'une année entière s'en charge une fois à la fin, plutôt
    // qu'après chacune de ses centaines de promotions.
    if (rafraichir) {
      await Magasin.instance.charger();
      notifyListeners();
    }

    return BilanImport(bilans);
  }

  /// Retrouve ou crée la spécialité correspondant à la promotion.
  ///
  /// Chez INSAM la spécialité porte le niveau ; chez nous elle en est
  /// indépendante. Les différents niveaux d'un même cursus se rangent
  /// donc sous une seule spécialité.
  ///
  /// Le regroupement se fait sur l'intitulé et la période, jamais sur le
  /// code : INSAM désigne la même filière tantôt « AC » tantôt « ACC »
  /// (53 cas dans le dump), et se fier au code créerait deux
  /// « ACCOUNTANCY » côte à côte. La période reste distinguée : le jour
  /// et le soir ont leurs propres enseignants et emplois du temps.
  Future<String> _specialite(
      DatabaseExecutor txn, String campusId, PromotionInsam promo) async {
    final intitule = promo.intitule.trim().isEmpty
        ? promo.code.trim()
        : promo.intitule.trim();
    final periode = promo.periode.trim();

    // La période fait partie du nom retenu chez nous, faute de colonne
    // dédiée : « ACCOUNTANCY (soir) ».
    final nom =
        periode.isEmpty || periode.toLowerCase() == 'jour'
            ? intitule
            : '$intitule ($periode)';

    final existantes = await txn.query(
      'specialite',
      columns: ['id'],
      where: 'campus_id = ? AND intitule = ? COLLATE NOCASE',
      whereArgs: [campusId, nom],
      limit: 1,
    );
    if (existantes.isNotEmpty) return existantes.first['id'] as String;

    final id = await _nouvelId(txn, 'SPE', 'specialite');
    await txn.insert('specialite', {
      'id': id,
      'campus_id': campusId,
      'abreviation':
          promo.code.trim().isEmpty ? intitule : promo.code.trim(),
      'intitule': nom,
      'responsable': '',
    });
    return id;
  }

  /// Retrouve ou crée la promotion (spécialité + palier).
  ///
  /// La contrainte d'unicité `(specialite_id, palier)` interdit d'ouvrir
  /// deux fois le même palier : on réutilise donc celui qui existe.
  Future<String> _niveau(
      DatabaseExecutor txn, String specialiteId, PromotionInsam promo) async {
    final palier = promo.palier;
    final existants = await txn.query(
      'niveau',
      columns: ['id'],
      where: 'specialite_id = ? AND palier = ?',
      whereArgs: [specialiteId, palier.index],
      limit: 1,
    );
    final id = existants.isNotEmpty
        ? existants.first['id'] as String
        : await _nouvelId(txn, 'NIV', 'niveau');

    if (existants.isEmpty) {
      await txn.insert('niveau', {
        'id': id,
        'specialite_id': specialiteId,
        'palier': palier.index,
      });
    }

    // La promotion porte l'identifiant de spécialité INSAM : c'est lui
    // qui identifie le cursus côté central, et l'export s'en sert pour
    // retrouver l'année et le contexte.
    await _lier(txn, EntiteInsam.niveau, id, promo.idSpecialite);
    return id;
  }

  /// Identifiants INSAM déjà présents **dans cette promotion**.
  ///
  /// La restriction au niveau est essentielle : chaque campus détient sa
  /// propre copie de la matière 421, avec un identifiant local distinct
  /// mais la même correspondance INSAM. Chercher globalement ferait
  /// croire, dès le deuxième campus, que tout est déjà importé.
  Future<Set<int>> _distantsDuNiveau(DatabaseExecutor txn, String entite,
      String table, String niveauId) async {
    final lignes = await txn.rawQuery('''
      SELECT c.id_distant
        FROM correspondance_insam c
        JOIN $table t ON t.id = c.id_local
       WHERE c.entite = ? AND t.niveau_id = ?
    ''', [entite, niveauId]);
    return {for (final l in lignes) l['id_distant'] as int};
  }

  /// Même convention que le magasin principal : préfixe + compteur.
  ///
  /// Le tri porte sur la partie numérique, pas sur la chaîne : en ordre
  /// alphabétique « MAT999 » passe après « MAT1000 », et le compteur
  /// repartirait à 1000 en écrasant l'existant. L'import d'une année
  /// entière dépasse largement le millier de matières.
  Future<String> _nouvelId(
      DatabaseExecutor txn, String prefixe, String table) async {
    final r = await txn.rawQuery(
      'SELECT id FROM $table WHERE id LIKE ? '
      'ORDER BY CAST(SUBSTR(id, ?) AS INTEGER) DESC LIMIT 1',
      ['$prefixe%', prefixe.length + 1],
    );
    var suivant = 1;
    if (r.isNotEmpty) {
      final dernier = r.first['id'] as String;
      suivant = (int.tryParse(dernier.substring(prefixe.length)) ?? 0) + 1;
    }
    return '$prefixe${suivant.toString().padLeft(3, '0')}';
  }
}
