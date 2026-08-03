import 'package:flutter/foundation.dart';

import 'modeles.dart';

/// Magasin en mémoire pour la phase UI/UX.
/// Sera remplacé par la base locale à l'étape suivante.
class Magasin extends ChangeNotifier {
  static final Magasin instance = Magasin._();
  Magasin._() {
    _semer();
  }

  final List<Filiere> filieres = [];
  final List<Specialite> specialites = [];
  final List<Niveau> niveaux = [];
  final List<Salle> salles = [];
  final List<Matiere> matieres = [];
  final List<Etudiant> etudiants = [];

  int _sequence = 0;
  String _id(String prefixe) => '$prefixe${(++_sequence).toString().padLeft(3, '0')}';

  // ---------- Lectures utilitaires ----------

  Filiere? filiere(String id) =>
      filieres.where((f) => f.id == id).firstOrNull;
  Specialite? specialite(String id) =>
      specialites.where((s) => s.id == id).firstOrNull;
  Niveau? niveau(String id) => niveaux.where((n) => n.id == id).firstOrNull;
  Salle? salle(String id) => salles.where((s) => s.id == id).firstOrNull;

  String nomFiliere(String id) => filiere(id)?.intitule ?? '—';
  String nomSpecialite(String id) => specialite(id)?.intitule ?? '—';
  String nomNiveau(String id) => niveau(id)?.intitule ?? '—';
  String nomSalle(String? id) => id == null ? '—' : (salle(id)?.nom ?? '—');

  List<Specialite> specialitesDe(String filiereId) =>
      specialites.where((s) => s.filiereId == filiereId).toList();

  List<Niveau> get niveauxTries =>
      [...niveaux]..sort((a, b) => a.rang.compareTo(b.rang));

  List<Etudiant> etudiantsDe({String? specialiteId, String? niveauId}) =>
      etudiants
          .where((e) =>
              (specialiteId == null || e.specialiteId == specialiteId) &&
              (niveauId == null || e.niveauId == niveauId))
          .toList();

  int effectifSpecialite(String id) =>
      etudiants.where((e) => e.specialiteId == id && e.actif).length;

  int effectifNiveau(String id) =>
      etudiants.where((e) => e.niveauId == id && e.actif).length;

  int nbMatieresSpecialite(String id) =>
      matieres.where((m) => m.specialiteId == id).length;

  /// Niveau immédiatement supérieur, ou null si c'est déjà le dernier.
  Niveau? niveauSuivant(String niveauId) {
    final actuel = niveau(niveauId);
    if (actuel == null) return null;
    final tries = niveauxTries;
    for (final n in tries) {
      if (n.rang > actuel.rang) return n;
    }
    return null;
  }

  // ---------- Écritures ----------

  void ajouterFiliere(String code, String intitule) {
    filieres.add(Filiere(id: _id('FIL'), code: code, intitule: intitule));
    notifyListeners();
  }

  void majFiliere(Filiere f, String code, String intitule) {
    f.code = code;
    f.intitule = intitule;
    notifyListeners();
  }

  void supprimerFiliere(String id) {
    filieres.removeWhere((f) => f.id == id);
    notifyListeners();
  }

  void ajouterSpecialite(
      String code, String intitule, String filiereId, String responsable) {
    specialites.add(Specialite(
      id: _id('SPE'),
      code: code,
      intitule: intitule,
      filiereId: filiereId,
      responsable: responsable,
    ));
    notifyListeners();
  }

  void majSpecialite(Specialite s, String code, String intitule,
      String filiereId, String responsable) {
    s.code = code;
    s.intitule = intitule;
    s.filiereId = filiereId;
    s.responsable = responsable;
    notifyListeners();
  }

  void supprimerSpecialite(String id) {
    specialites.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  void ajouterNiveau(String code, String intitule, int rang) {
    niveaux.add(
        Niveau(id: _id('NIV'), code: code, intitule: intitule, rang: rang));
    notifyListeners();
  }

  void majNiveau(Niveau n, String code, String intitule, int rang) {
    n.code = code;
    n.intitule = intitule;
    n.rang = rang;
    notifyListeners();
  }

  void supprimerNiveau(String id) {
    niveaux.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  void ajouterSalle(String nom, String batiment, int capacite) {
    salles.add(Salle(
        id: _id('SAL'), nom: nom, batiment: batiment, capacite: capacite));
    notifyListeners();
  }

  void majSalle(Salle s, String nom, String batiment, int capacite) {
    s.nom = nom;
    s.batiment = batiment;
    s.capacite = capacite;
    notifyListeners();
  }

  void supprimerSalle(String id) {
    salles.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  void ajouterMatiere(String code, String intitule, String specialiteId,
      String niveauId, int semestre, int credits) {
    matieres.add(Matiere(
      id: _id('MAT'),
      code: code,
      intitule: intitule,
      specialiteId: specialiteId,
      niveauId: niveauId,
      semestre: semestre,
      credits: credits,
    ));
    notifyListeners();
  }

  void majMatiere(Matiere m, String code, String intitule, String specialiteId,
      String niveauId, int semestre, int credits) {
    m.code = code;
    m.intitule = intitule;
    m.specialiteId = specialiteId;
    m.niveauId = niveauId;
    m.semestre = semestre;
    m.credits = credits;
    notifyListeners();
  }

  void supprimerMatiere(String id) {
    matieres.removeWhere((m) => m.id == id);
    notifyListeners();
  }

  void ajouterEtudiant(String matricule, String nom, Sexe sexe,
      String specialiteId, String niveauId, String? salleId) {
    etudiants.add(Etudiant(
      id: _id('ETU'),
      matricule: matricule,
      nomComplet: nom,
      sexe: sexe,
      specialiteId: specialiteId,
      niveauId: niveauId,
      salleId: salleId,
    ));
    notifyListeners();
  }

  void majEtudiant(Etudiant e, String matricule, String nom, Sexe sexe,
      String specialiteId, String niveauId, String? salleId, bool actif) {
    e.matricule = matricule;
    e.nomComplet = nom;
    e.sexe = sexe;
    e.specialiteId = specialiteId;
    e.niveauId = niveauId;
    e.salleId = salleId;
    e.actif = actif;
    notifyListeners();
  }

  void supprimerEtudiant(String id) {
    etudiants.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  /// Migration : fait passer les étudiants au niveau supérieur.
  void migrer(List<String> etudiantIds, String niveauCibleId, String? salleId) {
    for (final e in etudiants) {
      if (etudiantIds.contains(e.id)) {
        e.niveauId = niveauCibleId;
        if (salleId != null) e.salleId = salleId;
      }
    }
    notifyListeners();
  }

  // ---------- Données de démonstration ----------

  void _semer() {
    final genie = Filiere(
        id: _id('FIL'), code: 'GI', intitule: 'Génie Informatique');
    final gestion =
        Filiere(id: _id('FIL'), code: 'GE', intitule: 'Gestion');
    filieres.addAll([genie, gestion]);

    final gl = Specialite(
      id: _id('SPE'),
      code: 'GL',
      intitule: 'Génie Logiciel',
      filiereId: genie.id,
      responsable: 'M. KUIMO',
    );
    final rs = Specialite(
      id: _id('SPE'),
      code: 'RS',
      intitule: 'Réseaux et Sécurité',
      filiereId: genie.id,
      responsable: 'M. TCHOUA',
    );
    final cg = Specialite(
      id: _id('SPE'),
      code: 'CG',
      intitule: 'Comptabilité et Gestion',
      filiereId: gestion.id,
      responsable: 'Mme NGOUNOU',
    );
    specialites.addAll([gl, rs, cg]);

    final bts1 =
        Niveau(id: _id('NIV'), code: 'BTS1', intitule: 'BTS 1', rang: 1);
    final bts2 =
        Niveau(id: _id('NIV'), code: 'BTS2', intitule: 'BTS 2', rang: 2);
    final lic3 =
        Niveau(id: _id('NIV'), code: 'LIC3', intitule: 'Licence 3', rang: 3);
    niveaux.addAll([bts1, bts2, lic3]);

    final a101 = Salle(
        id: _id('SAL'), nom: 'Salle A101', batiment: 'Bâtiment A', capacite: 45);
    final a102 = Salle(
        id: _id('SAL'), nom: 'Salle A102', batiment: 'Bâtiment A', capacite: 40);
    final b201 = Salle(
        id: _id('SAL'), nom: 'Salle B201', batiment: 'Bâtiment B', capacite: 60);
    salles.addAll([a101, a102, b201]);

    matieres.addAll([
      Matiere(
        id: _id('MAT'),
        code: 'RO1234',
        intitule: 'Recherche Opérationnelle II',
        specialiteId: gl.id,
        niveauId: bts1.id,
        semestre: 1,
        credits: 4,
      ),
      Matiere(
        id: _id('MAT'),
        code: 'ALG201',
        intitule: 'Algorithmique avancée',
        specialiteId: gl.id,
        niveauId: bts1.id,
        semestre: 1,
        credits: 5,
      ),
      Matiere(
        id: _id('MAT'),
        code: 'BDD210',
        intitule: 'Bases de données',
        specialiteId: gl.id,
        niveauId: bts2.id,
        semestre: 2,
        credits: 4,
      ),
      Matiere(
        id: _id('MAT'),
        code: 'RES150',
        intitule: 'Administration réseaux',
        specialiteId: rs.id,
        niveauId: bts1.id,
        semestre: 1,
        credits: 4,
      ),
      Matiere(
        id: _id('MAT'),
        code: 'CPT110',
        intitule: 'Comptabilité générale',
        specialiteId: cg.id,
        niveauId: bts1.id,
        semestre: 1,
        credits: 3,
      ),
    ]);

    const noms = [
      ['Ange Tim', Sexe.f],
      ['Bertrand Nkolo', Sexe.m],
      ['Chantal Mbarga', Sexe.f],
      ['David Fotso', Sexe.m],
      ['Estelle Ndongo', Sexe.f],
      ['Franck Talla', Sexe.m],
      ['Gisèle Awono', Sexe.f],
      ['Hervé Kamga', Sexe.m],
      ['Irène Foning', Sexe.f],
      ['Joseph Manga', Sexe.m],
      ['Karine Ebode', Sexe.f],
      ['Landry Sop', Sexe.m],
    ];

    final repartition = [
      [gl.id, bts1.id, a101.id],
      [gl.id, bts2.id, a102.id],
      [rs.id, bts1.id, b201.id],
      [cg.id, bts1.id, a101.id],
    ];

    var i = 0;
    for (final r in repartition) {
      for (var k = 0; k < 3; k++) {
        final n = noms[i % noms.length];
        etudiants.add(Etudiant(
          id: _id('ETU'),
          matricule: 'IUE26${(1000 + i * 7).toString()}',
          nomComplet: n[0] as String,
          sexe: n[1] as Sexe,
          specialiteId: r[0],
          niveauId: r[1],
          salleId: r[2],
        ));
        i++;
      }
    }
  }
}
