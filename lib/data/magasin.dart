import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'base_locale.dart';
import 'magasin_campus.dart';
import 'modeles.dart';

/// Magasin de la configuration académique, adossé à la base SQLite locale.
///
/// Les données tiennent en mémoire pour que l'interface reste synchrone ;
/// chaque écriture est appliquée à la base puis répercutée sur le cache.
/// Il faut appeler [charger] après l'ouverture de la base.
class Magasin extends ChangeNotifier {
  static final Magasin instance = Magasin._();
  Magasin._();

  Database get _db => BaseLocale.instance.db;

  final List<Specialite> specialites = [];
  final List<Niveau> niveaux = [];
  final List<Matiere> matieres = [];
  final List<Etudiant> etudiants = [];

  bool _charge = false;
  bool get estCharge => _charge;

  /// Recharge tout le cache depuis la base, **pour le campus actif**.
  ///
  /// Le filtrage se fait ici, à la source : ainsi aucun écran ne peut
  /// afficher par mégarde les données d'un autre campus.
  Future<void> charger() async {
    final campusId = MagasinCampus.instance.actif?.id;

    // Sans campus choisi, on ne charge rien plutôt que de tout mélanger.
    if (campusId == null) {
      specialites.clear();
      niveaux.clear();
      matieres.clear();
      etudiants.clear();
      _charge = false;
      notifyListeners();
      return;
    }

    final lignesSpecialites = await _db.query('specialite',
        where: 'campus_id = ?',
        whereArgs: [campusId],
        orderBy: 'intitule COLLATE NOCASE');

    final idsSpecialites =
        lignesSpecialites.map((l) => l['id'] as String).toSet();

    final lignesNiveaux = await _db.query('niveau');
    final lignesMatieres =
        await _db.query('matiere', orderBy: 'code COLLATE NOCASE');
    final lignesEtudiants =
        await _db.query('etudiant', orderBy: 'nom_complet COLLATE NOCASE');

    specialites
      ..clear()
      ..addAll(lignesSpecialites.map((l) => Specialite(
            id: l['id'] as String,
            campusId: l['campus_id'] as String,
            abreviation: l['abreviation'] as String,
            intitule: l['intitule'] as String,
            responsable: l['responsable'] as String,
          )));

    // Chaîne de rattachement : campus -> spécialité -> niveau -> matière
    // et étudiant. On ne garde que ce qui remonte au campus actif.
    niveaux
      ..clear()
      ..addAll(lignesNiveaux
          .where((l) => idsSpecialites.contains(l['specialite_id'] as String))
          .map((l) => Niveau(
                id: l['id'] as String,
                specialiteId: l['specialite_id'] as String,
                palier: Palier.values[l['palier'] as int],
              )));

    final idsNiveaux = niveaux.map((n) => n.id).toSet();

    matieres
      ..clear()
      ..addAll(lignesMatieres
          .where((l) => idsNiveaux.contains(l['niveau_id'] as String))
          .map((l) => Matiere(
                id: l['id'] as String,
                code: l['code'] as String,
                intitule: l['intitule'] as String,
                niveauId: l['niveau_id'] as String,
                semestre: l['semestre'] as int,
              )));

    etudiants
      ..clear()
      ..addAll(lignesEtudiants
          .where((l) => idsNiveaux.contains(l['niveau_id'] as String))
          .map((l) => Etudiant(
                id: l['id'] as String,
                matricule: l['matricule'] as String,
                nomComplet: l['nom_complet'] as String,
                sexe: (l['sexe'] as String) == 'F' ? Sexe.f : Sexe.m,
                niveauId: l['niveau_id'] as String,
                actif: (l['actif'] as int) == 1,
              )));

    _charge = true;
    notifyListeners();
  }

  /// Identifiant lisible et unique : préfixe + compteur au-delà de l'existant.
  ///
  /// Le tri porte sur la partie numérique : en ordre alphabétique
  /// « MAT999 » passerait après « MAT1000 », et le compteur repartirait
  /// à 1000 en heurtant un identifiant déjà pris.
  Future<String> _id(String prefixe, String table) async {
    final r = await _db.rawQuery(
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

  // ---------- Lectures utilitaires ----------

  Specialite? specialite(String id) =>
      specialites.where((s) => s.id == id).firstOrNull;
  Niveau? niveau(String id) => niveaux.where((n) => n.id == id).firstOrNull;

  String nomSpecialite(String id) => specialite(id)?.intitule ?? '—';

  /// Palier d'une promotion : « BTS 1 ».
  String nomPalier(String niveauId) =>
      niveau(niveauId)?.palier.abreviation ?? '—';

  /// Libellé complet d'une promotion : « Génie Logiciel — BTS 1 ».
  String nomNiveau(String niveauId) {
    final n = niveau(niveauId);
    if (n == null) return '—';
    return '${nomSpecialite(n.specialiteId)} — ${n.palier.abreviation}';
  }

  /// Promotions d'une spécialité, du palier le plus bas au plus élevé.
  List<Niveau> niveauxDe(String specialiteId) =>
      niveaux.where((n) => n.specialiteId == specialiteId).toList()
        ..sort((a, b) => a.rang.compareTo(b.rang));

  /// Toutes les promotions, groupées par spécialité puis par palier.
  List<Niveau> get niveauxTries {
    final ordre = {
      for (var i = 0; i < specialites.length; i++) specialites[i].id: i
    };
    return [...niveaux]..sort((a, b) {
        final parSpecialite = (ordre[a.specialiteId] ?? 999)
            .compareTo(ordre[b.specialiteId] ?? 999);
        return parSpecialite != 0 ? parSpecialite : a.rang.compareTo(b.rang);
      });
  }

  /// Vrai si le palier est déjà ouvert pour cette spécialité.
  bool niveauExiste(String specialiteId, Palier palier, {String? saufId}) =>
      niveaux.any((n) =>
          n.specialiteId == specialiteId &&
          n.palier == palier &&
          n.id != saufId);

  List<Etudiant> etudiantsDe(String niveauId) =>
      etudiants.where((e) => e.niveauId == niveauId).toList();

  int effectifNiveau(String niveauId) =>
      etudiants.where((e) => e.niveauId == niveauId && e.actif).length;

  int effectifSpecialite(String specialiteId) {
    final ids = niveauxDe(specialiteId).map((n) => n.id).toSet();
    return etudiants.where((e) => ids.contains(e.niveauId) && e.actif).length;
  }

  int nbMatieresNiveau(String niveauId) =>
      matieres.where((m) => m.niveauId == niveauId).length;

  int nbMatieresSpecialite(String specialiteId) {
    final ids = niveauxDe(specialiteId).map((n) => n.id).toSet();
    return matieres.where((m) => ids.contains(m.niveauId)).length;
  }

  /// Promotion suivante dans la même spécialité, ou null si le palier
  /// supérieur n'est pas ouvert (ou n'existe pas).
  Niveau? niveauSuivant(String niveauId) {
    final actuel = niveau(niveauId);
    final apres = actuel?.palier.suivant;
    if (actuel == null || apres == null) return null;
    return niveaux
        .where(
            (n) => n.specialiteId == actuel.specialiteId && n.palier == apres)
        .firstOrNull;
  }

  // ---------- Spécialités ----------

  Future<void> ajouterSpecialite(
      String abreviation, String intitule, String responsable) async {
    final campusId = MagasinCampus.instance.actif?.id;
    if (campusId == null) {
      throw StateError('Aucun campus sélectionné.');
    }

    final id = await _id('SPE', 'specialite');
    await _db.insert('specialite', {
      'id': id,
      'campus_id': campusId,
      'abreviation': abreviation,
      'intitule': intitule,
      'responsable': responsable,
    });
    specialites.add(Specialite(
      id: id,
      campusId: campusId,
      abreviation: abreviation,
      intitule: intitule,
      responsable: responsable,
    ));
    _trierSpecialites();
    notifyListeners();
  }

  Future<void> majSpecialite(Specialite s, String abreviation, String intitule,
      String responsable) async {
    await _db.update(
      'specialite',
      {
        'abreviation': abreviation,
        'intitule': intitule,
        'responsable': responsable,
      },
      where: 'id = ?',
      whereArgs: [s.id],
    );
    s.abreviation = abreviation;
    s.intitule = intitule;
    s.responsable = responsable;
    _trierSpecialites();
    notifyListeners();
  }

  /// Supprime la spécialité ; SQLite propage aux promotions, matières
  /// et étudiants via ON DELETE CASCADE.
  Future<void> supprimerSpecialite(String id) async {
    await _db.delete('specialite', where: 'id = ?', whereArgs: [id]);

    final promotions = niveauxDe(id).map((n) => n.id).toSet();
    etudiants.removeWhere((e) => promotions.contains(e.niveauId));
    matieres.removeWhere((m) => promotions.contains(m.niveauId));
    niveaux.removeWhere((n) => n.specialiteId == id);
    specialites.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  void _trierSpecialites() => specialites
      .sort((a, b) => a.intitule.toLowerCase().compareTo(b.intitule.toLowerCase()));

  // ---------- Niveaux ----------

  Future<void> ajouterNiveau(String specialiteId, Palier palier) async {
    final id = await _id('NIV', 'niveau');
    await _db.insert('niveau', {
      'id': id,
      'specialite_id': specialiteId,
      'palier': palier.index,
    });
    niveaux.add(Niveau(id: id, specialiteId: specialiteId, palier: palier));
    notifyListeners();
  }

  Future<void> majNiveau(Niveau n, String specialiteId, Palier palier) async {
    await _db.update(
      'niveau',
      {'specialite_id': specialiteId, 'palier': palier.index},
      where: 'id = ?',
      whereArgs: [n.id],
    );
    n.specialiteId = specialiteId;
    n.palier = palier;
    notifyListeners();
  }

  Future<void> supprimerNiveau(String id) async {
    await _db.delete('niveau', where: 'id = ?', whereArgs: [id]);
    etudiants.removeWhere((e) => e.niveauId == id);
    matieres.removeWhere((m) => m.niveauId == id);
    niveaux.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  // ---------- Matières ----------

  Future<void> ajouterMatiere(
      String code, String intitule, String niveauId, int semestre) async {
    final id = await _id('MAT', 'matiere');
    await _db.insert('matiere', {
      'id': id,
      'code': code,
      'intitule': intitule,
      'niveau_id': niveauId,
      'semestre': semestre,
    });
    matieres.add(Matiere(
      id: id,
      code: code,
      intitule: intitule,
      niveauId: niveauId,
      semestre: semestre,
    ));
    _trierMatieres();
    notifyListeners();
  }

  Future<void> majMatiere(Matiere m, String code, String intitule,
      String niveauId, int semestre) async {
    await _db.update(
      'matiere',
      {
        'code': code,
        'intitule': intitule,
        'niveau_id': niveauId,
        'semestre': semestre,
      },
      where: 'id = ?',
      whereArgs: [m.id],
    );
    m.code = code;
    m.intitule = intitule;
    m.niveauId = niveauId;
    m.semestre = semestre;
    _trierMatieres();
    notifyListeners();
  }

  Future<void> supprimerMatiere(String id) async {
    await _db.delete('matiere', where: 'id = ?', whereArgs: [id]);
    matieres.removeWhere((m) => m.id == id);
    notifyListeners();
  }

  void _trierMatieres() => matieres
      .sort((a, b) => a.code.toLowerCase().compareTo(b.code.toLowerCase()));

  // ---------- Étudiants ----------

  Future<void> ajouterEtudiant(
      String matricule, String nom, Sexe sexe, String niveauId) async {
    final id = await _id('ETU', 'etudiant');
    await _db.insert('etudiant', {
      'id': id,
      'matricule': matricule,
      'nom_complet': nom,
      'sexe': sexe.code,
      'niveau_id': niveauId,
      'actif': 1,
    });
    etudiants.add(Etudiant(
      id: id,
      matricule: matricule,
      nomComplet: nom,
      sexe: sexe,
      niveauId: niveauId,
    ));
    _trierEtudiants();
    notifyListeners();
  }

  Future<void> majEtudiant(Etudiant e, String matricule, String nom, Sexe sexe,
      String niveauId, bool actif) async {
    await _db.update(
      'etudiant',
      {
        'matricule': matricule,
        'nom_complet': nom,
        'sexe': sexe.code,
        'niveau_id': niveauId,
        'actif': actif ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [e.id],
    );
    e.matricule = matricule;
    e.nomComplet = nom;
    e.sexe = sexe;
    e.niveauId = niveauId;
    e.actif = actif;
    _trierEtudiants();
    notifyListeners();
  }

  Future<void> supprimerEtudiant(String id) async {
    await _db.delete('etudiant', where: 'id = ?', whereArgs: [id]);
    etudiants.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  void _trierEtudiants() => etudiants.sort(
      (a, b) => a.nomComplet.toLowerCase().compareTo(b.nomComplet.toLowerCase()));

  /// Migration : fait passer les étudiants à la promotion cible,
  /// en une seule transaction.
  Future<void> migrer(List<String> etudiantIds, String niveauCibleId) async {
    if (etudiantIds.isEmpty) return;

    await _db.transaction((txn) async {
      final lot = txn.batch();
      for (final id in etudiantIds) {
        lot.update('etudiant', {'niveau_id': niveauCibleId},
            where: 'id = ?', whereArgs: [id]);
      }
      await lot.commit(noResult: true);
    });

    final cibles = etudiantIds.toSet();
    for (final e in etudiants) {
      if (cibles.contains(e.id)) e.niveauId = niveauCibleId;
    }
    notifyListeners();
  }
}
