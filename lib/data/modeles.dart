/// Modèles de la configuration académique.
/// Phase UI/UX : objets en mémoire, aucune persistance.
library;

enum Sexe { m, f }

extension SexeLibelle on Sexe {
  String get code => this == Sexe.m ? 'M' : 'F';
  String get libelle => this == Sexe.m ? 'Masculin' : 'Féminin';
}

class Filiere {
  final String id;
  String code;
  String intitule;

  Filiere({required this.id, required this.code, required this.intitule});
}

class Specialite {
  final String id;
  String code;
  String intitule;
  String filiereId;
  String responsable;

  Specialite({
    required this.id,
    required this.code,
    required this.intitule,
    required this.filiereId,
    required this.responsable,
  });
}

class Niveau {
  final String id;
  String code;
  String intitule;
  int rang;

  Niveau({
    required this.id,
    required this.code,
    required this.intitule,
    required this.rang,
  });
}

class Salle {
  final String id;
  String nom;
  String batiment;
  int capacite;

  Salle({
    required this.id,
    required this.nom,
    required this.batiment,
    required this.capacite,
  });
}

class Matiere {
  final String id;
  String code;
  String intitule;
  String specialiteId;
  String niveauId;
  int semestre;
  int credits;

  Matiere({
    required this.id,
    required this.code,
    required this.intitule,
    required this.specialiteId,
    required this.niveauId,
    required this.semestre,
    required this.credits,
  });
}

class Etudiant {
  final String id;
  String matricule;
  String nomComplet;
  Sexe sexe;
  String specialiteId;
  String niveauId;
  String? salleId;
  bool actif;

  Etudiant({
    required this.id,
    required this.matricule,
    required this.nomComplet,
    required this.sexe,
    required this.specialiteId,
    required this.niveauId,
    this.salleId,
    this.actif = true,
  });
}
