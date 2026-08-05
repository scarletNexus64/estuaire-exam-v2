/// Modèles de la configuration académique.
library;

import 'dart:typed_data';

enum Sexe { m, f }

extension SexeLibelle on Sexe {
  String get code => this == Sexe.m ? 'M' : 'F';
  String get libelle => this == Sexe.m ? 'Masculin' : 'Féminin';
}

enum Role { superAdmin, enseignant }

extension RoleLibelle on Role {
  String get libelle =>
      this == Role.superAdmin ? 'Super administrateur' : 'Enseignant';
  String get libelleCourt =>
      this == Role.superAdmin ? 'Administration' : 'Enseignant';
}

/// Barème des paliers d'étude — liste fermée, non modifiable par l'utilisateur.
enum Palier { bts1, bts2, licence, master1, master2 }

extension PalierLibelle on Palier {
  /// Intitulé complet, tel qu'il apparaît sur les documents officiels.
  String get libelle => switch (this) {
        Palier.bts1 => 'Brevet de Technicien Supérieur 1',
        Palier.bts2 => 'Brevet de Technicien Supérieur 2',
        Palier.licence => 'Licence',
        Palier.master1 => 'Master 1',
        Palier.master2 => 'Master 2',
      };

  /// Forme abrégée, utilisée dans les tableaux et les cartes.
  String get abreviation => switch (this) {
        Palier.bts1 => 'BTS 1',
        Palier.bts2 => 'BTS 2',
        Palier.licence => 'Licence',
        Palier.master1 => 'Master 1',
        Palier.master2 => 'Master 2',
      };

  /// Libellé du sélecteur : « Brevet de Technicien Supérieur 1 (BTS 1) ».
  String get libelleComplet =>
      libelle == abreviation ? libelle : '$libelle ($abreviation)';

  /// Ordre de progression ; sert aux migrations.
  int get rang => index + 1;

  /// Palier immédiatement supérieur, ou null au sommet du cursus.
  Palier? get suivant =>
      index + 1 < Palier.values.length ? Palier.values[index + 1] : null;
}

/// Regroupement de campus : « Campus annexe de Bafoussam ».
class Annexe {
  final String id;
  String intitule;
  int ordre;

  Annexe({required this.id, required this.intitule, this.ordre = 0});
}

/// Lieu de travail : on s'y connecte, et les données y sont rattachées.
class Campus {
  final String id;
  String annexeId;
  String intitule;
  int ordre;

  /// En-tête propre au campus, imprimé sur ses documents.
  /// Null : l'en-tête générique de l'institut est utilisé.
  Uint8List? entete;

  Campus({
    required this.id,
    required this.annexeId,
    required this.intitule,
    this.ordre = 0,
    this.entete,
  });

  bool get aEntete => entete != null && entete!.isNotEmpty;
}

class Specialite {
  final String id;
  String campusId;
  String abreviation;
  String intitule;
  String responsable;

  Specialite({
    required this.id,
    required this.campusId,
    required this.abreviation,
    required this.intitule,
    required this.responsable,
  });
}

/// Ouverture d'un palier pour une spécialité — autrement dit une promotion.
/// Exemple : « Génie Logiciel — BTS 1 ».
class Niveau {
  final String id;
  String specialiteId;
  Palier palier;

  Niveau({
    required this.id,
    required this.specialiteId,
    required this.palier,
  });

  int get rang => palier.rang;
}

class Matiere {
  final String id;
  String code;
  String intitule;
  String niveauId;
  int semestre;

  Matiere({
    required this.id,
    required this.code,
    required this.intitule,
    required this.niveauId,
    required this.semestre,
  });
}

/// Types de questions proposés par l'éditeur d'épreuve.
enum TypeQuestion { choixUnique, choixMultiple, listeDeroulante, vraiFaux }

extension TypeQuestionLibelle on TypeQuestion {
  String get libelle => switch (this) {
        TypeQuestion.choixUnique => 'Choix unique',
        TypeQuestion.choixMultiple => 'Choix multiple',
        TypeQuestion.listeDeroulante => 'Liste déroulante',
        TypeQuestion.vraiFaux => 'Vrai ou faux',
      };

  String get description => switch (this) {
        TypeQuestion.choixUnique => 'Boutons radio, une seule bonne réponse',
        TypeQuestion.choixMultiple =>
          'Cases à cocher, plusieurs bonnes réponses',
        TypeQuestion.listeDeroulante => 'Menu déroulant, une seule réponse',
        TypeQuestion.vraiFaux => 'Deux options : Vrai ou Faux',
      };

  /// Vrai si l'étudiant peut cocher plusieurs propositions.
  bool get multiple => this == TypeQuestion.choixMultiple;

  /// Vrai si les propositions sont figées et non modifiables.
  bool get propositionsFigees => this == TypeQuestion.vraiFaux;
}

/// Nature de l'évaluation : détermine la colonne de la fiche de report.
enum NatureEpreuve { controleContinu, sessionNormale, rattrapage }

extension NatureEpreuveLibelle on NatureEpreuve {
  String get libelle => switch (this) {
        NatureEpreuve.controleContinu => 'Contrôle continu',
        NatureEpreuve.sessionNormale => 'Session normale',
        NatureEpreuve.rattrapage => 'Rattrapage',
      };
}

/// État d'une épreuve dans son cycle de vie.
enum EtatEpreuve { brouillon, planifiee, enCours, terminee }

extension EtatEpreuveLibelle on EtatEpreuve {
  String get libelle => switch (this) {
        EtatEpreuve.brouillon => 'Brouillon',
        EtatEpreuve.planifiee => 'Planifiée',
        EtatEpreuve.enCours => 'En cours',
        EtatEpreuve.terminee => 'Terminée',
      };
}

/// Une proposition de réponse.
class Proposition {
  final String id;
  String texte;
  bool correcte;
  int ordre;

  Proposition({
    required this.id,
    required this.texte,
    this.correcte = false,
    this.ordre = 0,
  });
}

class Question {
  final String id;
  String epreuveId;
  String enonce;
  TypeQuestion type;
  double points;
  int ordre;
  List<Proposition> propositions;

  Question({
    required this.id,
    required this.epreuveId,
    required this.enonce,
    required this.type,
    this.points = 1,
    this.ordre = 0,
    List<Proposition>? propositions,
  }) : propositions = propositions ?? [];

  List<Proposition> get propositionsTriees =>
      [...propositions]..sort((a, b) => a.ordre.compareTo(b.ordre));

  /// Une question sans bonne réponse ne peut pas être corrigée.
  bool get aUneBonneReponse => propositions.any((p) => p.correcte);

  /// Anomalies qui empêchent de publier l'épreuve.
  List<String> get anomalies {
    final problemes = <String>[];
    if (enonce.trim().isEmpty) problemes.add('énoncé vide');
    if (propositions.length < 2) problemes.add('moins de deux propositions');
    if (propositions.any((p) => p.texte.trim().isEmpty)) {
      problemes.add('proposition vide');
    }
    if (!aUneBonneReponse) problemes.add('aucune bonne réponse');
    if (!type.multiple && propositions.where((p) => p.correcte).length > 1) {
      problemes.add('plusieurs bonnes réponses pour un choix unique');
    }
    return problemes;
  }
}

class Epreuve {
  final String id;
  String titre;
  String consignes;
  String matiereId;

  /// Début planifié ; la fin se déduit de la durée.
  DateTime? debut;
  int dureeMinutes;

  /// Code que l'étudiant saisit pour accéder à l'épreuve.
  String codeAcces;

  /// Mélange l'ordre des questions pour limiter la copie entre voisins.
  bool melangerQuestions;
  bool melangerPropositions;

  EtatEpreuve etat;
  NatureEpreuve nature;
  List<Question> questions;

  Epreuve({
    required this.id,
    required this.titre,
    required this.matiereId,
    required this.codeAcces,
    this.consignes = '',
    this.debut,
    this.dureeMinutes = 60,
    this.melangerQuestions = false,
    this.melangerPropositions = false,
    this.etat = EtatEpreuve.brouillon,
    this.nature = NatureEpreuve.controleContinu,
    List<Question>? questions,
  }) : questions = questions ?? [];

  /// Convertit une note du barème de l'épreuve vers /20.
  /// Les fiches officielles sont toujours sur 20, quel que soit le QCM.
  double? sur20(double? note) {
    final total = bareme;
    if (note == null || total <= 0) return null;
    return note / total * 20;
  }

  List<Question> get questionsTriees =>
      [...questions]..sort((a, b) => a.ordre.compareTo(b.ordre));

  /// Fin déduite du début et de la durée.
  DateTime? get fin => debut?.add(Duration(minutes: dureeMinutes));

  /// Vrai si l'heure de fin est dépassée, ou l'épreuve clôturée à la main.
  ///
  /// Fait autorité sur le chronomètre individuel : sans cette borne, un
  /// étudiant se connectant après la fin ouvrirait une session neuve et
  /// disposerait de la durée complète.
  bool get estClose {
    if (etat == EtatEpreuve.terminee) return true;
    final limite = fin;
    return limite != null && DateTime.now().isAfter(limite);
  }

  /// Vrai si l'épreuve accepte les compositions à cet instant.
  bool get estOuverte {
    if (etat == EtatEpreuve.brouillon || estClose) return false;
    final ouverture = debut;
    return ouverture == null || !DateTime.now().isBefore(ouverture);
  }

  double get bareme =>
      questions.fold(0, (total, q) => total + q.points);

  /// Vrai si l'épreuve peut être publiée aux étudiants.
  bool get estPubliable =>
      titre.trim().isNotEmpty &&
      debut != null &&
      questions.isNotEmpty &&
      questions.every((q) => q.anomalies.isEmpty);
}

class Etudiant {
  final String id;
  String matricule;
  String nomComplet;
  Sexe sexe;
  String niveauId;
  bool actif;

  Etudiant({
    required this.id,
    required this.matricule,
    required this.nomComplet,
    required this.sexe,
    required this.niveauId,
    this.actif = true,
  });
}

class Utilisateur {
  final String id;
  String identifiant;
  String motDePasse;
  String nomComplet;
  Role role;
  bool actif;

  /// Renseigné uniquement pour les enseignants : matières qui lui sont confiées.
  List<String> matiereIds;

  Utilisateur({
    required this.id,
    required this.identifiant,
    required this.motDePasse,
    required this.nomComplet,
    required this.role,
    this.actif = true,
    List<String>? matiereIds,
  }) : matiereIds = matiereIds ?? [];

  /// Initiales pour l'avatar : « Marc Kuimo » -> « MK ».
  String get initiales {
    final mots = nomComplet.trim().split(RegExp(r'\s+'));
    if (mots.isEmpty || mots.first.isEmpty) return '?';
    if (mots.length == 1) return mots.first.substring(0, 1).toUpperCase();
    return (mots.first.substring(0, 1) + mots.last.substring(0, 1))
        .toUpperCase();
  }
}
