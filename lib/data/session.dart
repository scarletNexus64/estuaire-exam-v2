import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'base_locale.dart';
import 'modeles.dart';

/// Résultat d'une opération d'authentification.
class ResultatConnexion {
  final bool ok;
  final String? erreur;
  const ResultatConnexion.reussie() : ok = true, erreur = null;
  const ResultatConnexion.echouee(this.erreur) : ok = false;
}

/// Comptes et session courante, adossés à la base SQLite locale.
class Session extends ChangeNotifier {
  static final Session instance = Session._();
  Session._();

  Database get _db => BaseLocale.instance.db;

  final List<Utilisateur> comptes = [];

  Utilisateur? _courant;
  Utilisateur? get courant => _courant;

  bool get estConnecte => _courant != null;
  bool get estSuperAdmin => _courant?.role == Role.superAdmin;
  bool get estEnseignant => _courant?.role == Role.enseignant;

  static const _roleAdmin = 'super_admin';

  Utilisateur _depuisLigne(Map<String, Object?> l) => Utilisateur(
        id: l['id'] as String,
        identifiant: l['identifiant'] as String,
        motDePasse: l['mot_de_passe'] as String,
        nomComplet: l['nom_complet'] as String,
        role: (l['role'] as String) == _roleAdmin
            ? Role.superAdmin
            : Role.enseignant,
        actif: (l['actif'] as int) == 1,
      );

  /// Recharge la liste des comptes et leurs affectations depuis la base.
  Future<void> charger() async {
    final lignes =
        await _db.query('utilisateur', orderBy: 'identifiant COLLATE NOCASE');
    comptes
      ..clear()
      ..addAll(lignes.map(_depuisLigne));

    // Matières confiées, rattachées à chaque compte.
    final affectations = await _db.query('affectation');
    for (final a in affectations) {
      final compte = comptes
          .where((c) => c.id == a['utilisateur_id'] as String)
          .firstOrNull;
      compte?.matiereIds.add(a['matiere_id'] as String);
    }

    // Après un import, le compte connecté peut ne plus exister.
    final id = _courant?.id;
    if (id != null) {
      _courant = comptes.where((c) => c.id == id).firstOrNull;
    }
    notifyListeners();
  }

  /// Vérification en clair : la base est locale et le poste est celui du
  /// campus. À renforcer par un hachage si le poste devient partagé.
  Future<ResultatConnexion> connecter(
    String identifiant,
    String motDePasse,
  ) async {
    // Petite latence pour rendre l'état de chargement visible à l'écran.
    await Future.delayed(const Duration(milliseconds: 350));

    final lignes = await _db.query(
      'utilisateur',
      where: 'identifiant = ? COLLATE NOCASE',
      whereArgs: [identifiant.trim()],
      limit: 1,
    );

    if (lignes.isEmpty) {
      return const ResultatConnexion.echouee('Identifiant inconnu.');
    }

    final compte = _depuisLigne(lignes.first);
    if (!compte.actif) {
      return const ResultatConnexion.echouee('Ce compte est désactivé.');
    }
    if (compte.motDePasse != motDePasse) {
      return const ResultatConnexion.echouee('Mot de passe incorrect.');
    }

    _courant = comptes.where((c) => c.id == compte.id).firstOrNull ?? compte;
    notifyListeners();
    return const ResultatConnexion.reussie();
  }

  void deconnecter() {
    _courant = null;
    notifyListeners();
  }

  // ---------- Gestion des comptes ----------

  Future<String> _id() async {
    final r = await _db.rawQuery(
        'SELECT id FROM utilisateur ORDER BY id DESC LIMIT 1');
    var suivant = 1;
    if (r.isNotEmpty) {
      final dernier = r.first['id'] as String;
      suivant = (int.tryParse(dernier.substring(3)) ?? 0) + 1;
    }
    return 'USR${suivant.toString().padLeft(3, '0')}';
  }

  /// Vrai si l'identifiant est déjà pris par un autre compte.
  bool identifiantPris(String identifiant, {String? saufId}) {
    final saisie = identifiant.trim().toLowerCase();
    return comptes
        .any((c) => c.identifiant.toLowerCase() == saisie && c.id != saufId);
  }

  /// Nombre de super administrateurs encore actifs.
  int get nbAdminsActifs =>
      comptes.where((c) => c.role == Role.superAdmin && c.actif).length;

  Future<void> ajouterCompte(String identifiant, String motDePasse,
      String nomComplet, Role role) async {
    final id = await _id();
    await _db.insert('utilisateur', {
      'id': id,
      'identifiant': identifiant.trim(),
      'mot_de_passe': motDePasse,
      'nom_complet': nomComplet.trim(),
      'role': role == Role.superAdmin ? _roleAdmin : 'enseignant',
      'actif': 1,
    });
    comptes.add(Utilisateur(
      id: id,
      identifiant: identifiant.trim(),
      motDePasse: motDePasse,
      nomComplet: nomComplet.trim(),
      role: role,
    ));
    _trier();
    notifyListeners();
  }

  /// Met à jour un compte. Un mot de passe vide laisse l'ancien inchangé.
  Future<void> majCompte(Utilisateur u, String identifiant, String nomComplet,
      Role role, bool actif, {String motDePasse = ''}) async {
    final valeurs = <String, Object?>{
      'identifiant': identifiant.trim(),
      'nom_complet': nomComplet.trim(),
      'role': role == Role.superAdmin ? _roleAdmin : 'enseignant',
      'actif': actif ? 1 : 0,
    };
    if (motDePasse.isNotEmpty) valeurs['mot_de_passe'] = motDePasse;

    await _db
        .update('utilisateur', valeurs, where: 'id = ?', whereArgs: [u.id]);

    u.identifiant = identifiant.trim();
    u.nomComplet = nomComplet.trim();
    u.role = role;
    u.actif = actif;
    if (motDePasse.isNotEmpty) u.motDePasse = motDePasse;
    _trier();
    notifyListeners();
  }

  Future<void> supprimerCompte(String id) async {
    await _db.delete('utilisateur', where: 'id = ?', whereArgs: [id]);
    comptes.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  /// Enseignants, dans l'ordre alphabétique de leur nom.
  List<Utilisateur> get enseignants =>
      comptes.where((c) => c.role == Role.enseignant).toList()
        ..sort((a, b) => a.nomComplet
            .toLowerCase()
            .compareTo(b.nomComplet.toLowerCase()));

  /// Remplace la liste des matières confiées à [u].
  Future<void> definirAffectations(
      Utilisateur u, Set<String> matiereIds) async {
    await _db.transaction((txn) async {
      await txn.delete('affectation',
          where: 'utilisateur_id = ?', whereArgs: [u.id]);
      final lot = txn.batch();
      for (final id in matiereIds) {
        lot.insert('affectation', {
          'utilisateur_id': u.id,
          'matiere_id': id,
        });
      }
      await lot.commit(noResult: true);
    });

    u.matiereIds
      ..clear()
      ..addAll(matiereIds);
    notifyListeners();
  }

  /// Enseignants à qui la matière [matiereId] est confiée.
  List<Utilisateur> enseignantsDe(String matiereId) =>
      comptes.where((c) => c.matiereIds.contains(matiereId)).toList();

  /// Changement de mot de passe par l'utilisateur lui-même.
  Future<ResultatConnexion> changerMotDePasse(
      String actuel, String nouveau) async {
    final u = _courant;
    if (u == null) return const ResultatConnexion.echouee('Aucune session.');
    if (u.motDePasse != actuel) {
      return const ResultatConnexion.echouee(
          'Le mot de passe actuel est incorrect.');
    }
    if (nouveau.length < 4) {
      return const ResultatConnexion.echouee(
          'Le nouveau mot de passe doit faire au moins 4 caractères.');
    }

    await _db.update('utilisateur', {'mot_de_passe': nouveau},
        where: 'id = ?', whereArgs: [u.id]);
    u.motDePasse = nouveau;
    notifyListeners();
    return const ResultatConnexion.reussie();
  }

  /// Mise à jour de l'identité du compte connecté.
  Future<void> majProfil(String nomComplet) async {
    final u = _courant;
    if (u == null) return;
    await _db.update('utilisateur', {'nom_complet': nomComplet.trim()},
        where: 'id = ?', whereArgs: [u.id]);
    u.nomComplet = nomComplet.trim();
    notifyListeners();
  }

  void _trier() => comptes.sort((a, b) =>
      a.identifiant.toLowerCase().compareTo(b.identifiant.toLowerCase()));
}
