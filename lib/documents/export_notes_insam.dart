/// Export des notes au format attendu par le système central INSAM.
library;

import 'package:excel/excel.dart';

import '../data/magasin.dart';
import '../data/magasin_epreuves.dart';
import '../data/magasin_insam.dart';
import '../data/magasin_sessions.dart';
import '../data/modeles.dart';
import '../data/referentiel_insam.dart';

/// Une ligne du fichier remis à INSAM : un étudiant, une note.
class LigneExport {
  final int? idEtudiant;
  final String nom;
  final String prenom;
  final double? note;

  /// Nom local de l'étudiant sans correspondance INSAM, pour le rapport.
  final bool sansCorrespondance;

  const LigneExport({
    required this.idEtudiant,
    required this.nom,
    required this.prenom,
    required this.note,
    required this.sansCorrespondance,
  });
}

/// Fichier prêt à être enregistré, avec de quoi le nommer et l'expliquer.
class ExportNotes {
  final List<int> octets;
  final String nomFichier;
  final List<LigneExport> lignes;

  const ExportNotes({
    required this.octets,
    required this.nomFichier,
    required this.lignes,
  });

  int get total => lignes.length;
  int get avecNote => lignes.where((l) => l.note != null).length;
  List<LigneExport> get orphelines =>
      lignes.where((l) => l.sansCorrespondance).toList();
}

/// Produit le classeur que le système central importe dans sa table
/// `composer`.
///
/// Le format n'est pas une mise en page : c'est un tableau plat, une
/// colonne par champ de la table cible. On reproduit exactement l'ordre
/// et les intitulés du modèle fourni par INSAM — toute variation ferait
/// échouer leur import.
class ExportNotesInsam {
  ExportNotesInsam._();

  /// En-têtes du modèle INSAM, à reproduire au caractère près.
  static const enTetes = <String>[
    'id_composer',
    'id_etudiant',
    'id_matiere',
    'id_examen',
    'id_annee',
    'Nom',
    'Prenom',
    'note',
    'date_composer',
  ];

  /// Identifiant d'examen chez INSAM : 1 = contrôle continu,
  /// 2 = session normale, 3 = rattrapage (table `examen` du dump).
  static int idExamen(NatureEpreuve nature) => switch (nature) {
        NatureEpreuve.controleContinu => 1,
        NatureEpreuve.sessionNormale => 2,
        NatureEpreuve.rattrapage => 3,
      };

  /// Construit le fichier pour une matière et une nature d'épreuve.
  ///
  /// L'année académique INSAM est relue depuis la promotion importée :
  /// la laisser saisir exposerait à un décalage silencieux, et les notes
  /// atterriraient sur la mauvaise année chez INSAM.
  ///
  /// [dateEpreuve] alimente `date_composer` ; à défaut, le jour de
  /// l'épreuve la plus récente, sinon celui de l'export.
  static Future<ExportNotes> generer({
    required Matiere matiere,
    required NatureEpreuve nature,
    DateTime? dateEpreuve,
  }) async {
    final magasin = Magasin.instance;
    final insam = MagasinInsam.instance;

    final idMatiere = await insam.idDistant(EntiteInsam.matiere, matiere.id);
    if (idMatiere == null) {
      throw StateError(
        'La matière « ${matiere.intitule} » n\'a pas de correspondance '
        'INSAM. Importez la promotion depuis le référentiel avant '
        'd\'exporter.',
      );
    }

    final idSpecialite =
        await insam.idDistant(EntiteInsam.niveau, matiere.niveauId);
    if (idSpecialite == null) {
      throw StateError(
        'La promotion de cette matière n\'a pas de correspondance INSAM. '
        'Importez-la depuis le référentiel avant d\'exporter.',
      );
    }

    final annee =
        await ReferentielInsam.instance.anneeDeSpecialite(idSpecialite);
    if (annee == null) {
      throw StateError(
        'L\'année académique de cette promotion est introuvable dans le '
        'référentiel INSAM.',
      );
    }
    final idAnnee = annee.id;

    final etudiants = magasin.etudiantsDe(matiere.niveauId);
    final correspondances =
        await insam.correspondances(EntiteInsam.etudiant);

    // La date de composition est celle de l'épreuve, pas celle de
    // l'export : les notes peuvent être remontées plusieurs jours après.
    final date = _jour(dateEpreuve ?? _dateEpreuve(matiere, nature));

    final lignes = <LigneExport>[];
    for (final e in etudiants) {
      final idDistant = correspondances[e.id];
      lignes.add(LigneExport(
        idEtudiant: idDistant,
        // INSAM range le nom complet dans `Nom` et laisse `Prenom` vide :
        // on s'aligne, notre modèle ne sépare pas les deux non plus.
        nom: e.nomComplet,
        prenom: '',
        note: _note(matiere, e.id, nature),
        sansCorrespondance: idDistant == null,
      ));
    }

    final classeur = Excel.createExcel();
    final feuille = classeur[classeur.getDefaultSheet()!];

    feuille.appendRow(
        [for (final t in enTetes) TextCellValue(t)]);

    for (final l in lignes) {
      feuille.appendRow(<CellValue?>[
        // `id_composer` reste vide : c'est l'auto-increment de MySQL.
        // Le renseigner provoquerait des collisions à l'import.
        null,
        l.idEtudiant == null ? null : IntCellValue(l.idEtudiant!),
        IntCellValue(idMatiere),
        IntCellValue(idExamen(nature)),
        IntCellValue(idAnnee),
        TextCellValue(l.nom),
        l.prenom.isEmpty ? null : TextCellValue(l.prenom),
        // Note absente = étudiant qui n'a pas composé : on laisse la
        // cellule vide plutôt que d'écrire 0, qu'INSAM ne saurait pas
        // distinguer d'un zéro mérité.
        l.note == null ? null : DoubleCellValue(_arrondi(l.note!)),
        TextCellValue(date),
      ]);
    }

    final octets = classeur.encode();
    if (octets == null) {
      throw StateError('La génération du classeur a échoué.');
    }

    return ExportNotes(
      octets: octets,
      nomFichier: _nomFichier(matiere, nature),
      lignes: lignes,
    );
  }

  /// Note sur 20 de l'étudiant pour cette nature d'épreuve.
  ///
  /// Même règle que la fiche de report : parmi plusieurs épreuves de même
  /// nature, la plus récente fait foi.
  static double? _note(
      Matiere matiere, String etudiantId, NatureEpreuve nature) {
    final concernees = MagasinEpreuves.instance
        .epreuvesDe(matiere.id)
        .where((e) => e.nature == nature)
        .toList()
      ..sort((a, b) =>
          (b.debut ?? DateTime(0)).compareTo(a.debut ?? DateTime(0)));

    for (final e in concernees) {
      final session = MagasinSessions.instance.sessionDe(
        e.id,
        etudiantId,
        passation: e.debut?.toIso8601String() ?? '',
      );
      if (session?.note != null) return e.sur20(session!.note);
    }
    return null;
  }

  /// Date de l'épreuve la plus récente de cette nature, à défaut ce jour.
  static DateTime _dateEpreuve(Matiere matiere, NatureEpreuve nature) {
    final dates = MagasinEpreuves.instance
        .epreuvesDe(matiere.id)
        .where((e) => e.nature == nature && e.debut != null)
        .map((e) => e.debut!)
        .toList()
      ..sort();
    return dates.isEmpty ? DateTime.now() : dates.last;
  }

  /// Deux décimales : au-delà, INSAM tronque de toute façon.
  static double _arrondi(double note) =>
      double.parse(note.toStringAsFixed(2));

  /// Date au format attendu par MySQL : AAAA-MM-JJ.
  static String _jour(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Nom calqué sur celui du modèle INSAM, qui décrit l'examen en clair.
  static String _nomFichier(Matiere matiere, NatureEpreuve nature) {
    final magasin = Magasin.instance;
    final niveau = magasin.niveau(matiere.niveauId);
    final specialite = niveau == null
        ? ''
        : magasin.specialite(niveau.specialiteId)?.intitule ?? '';

    final libelle = switch (nature) {
      NatureEpreuve.controleContinu => 'Examen De Controle Continu',
      NatureEpreuve.sessionNormale => 'Examen De Session Normale',
      NatureEpreuve.rattrapage => 'Examen De Session De Rattrapage',
    };

    final nom = '$libelle En ${matiere.intitule} '
        'Pour $specialite En ${niveau?.palier.abreviation ?? ''}';

    // Les caractères interdits par les systèmes de fichiers sont retirés,
    // sans quoi l'enregistrement échoue silencieusement sur certains.
    return '${nom.replaceAll(RegExp(r'[/\\:*?"<>|]'), ' ').trim()}.xlsx';
  }
}
