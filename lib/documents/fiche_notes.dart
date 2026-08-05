import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/magasin.dart';
import '../data/magasin_campus.dart';
import '../data/magasin_epreuves.dart';
import '../data/magasin_sessions.dart';
import '../data/modeles.dart';
import '../data/parametres.dart';

/// Ligne de la fiche : un étudiant et ses notes, colonne par colonne.
class LigneNotes {
  final int numero;
  final String nom;
  final String matricule;
  final String sexe;
  final double? controleContinu;
  final double? sessionNormale;
  final double? rattrapage;

  const LigneNotes({
    required this.numero,
    required this.nom,
    required this.matricule,
    required this.sexe,
    this.controleContinu,
    this.sessionNormale,
    this.rattrapage,
  });
}

/// Génère les documents officiels : fiche de report de notes et liste
/// de présence, calqués sur les modèles de l'établissement.
class FicheNotes {
  FicheNotes._();

  static pw.MemoryImage? _enTeteInstitut;

  /// En-tête à imprimer : celui du campus s'il en a un, sinon celui de
  /// l'institut. Le générique est lu une fois puis conservé.
  /// Partagé avec les autres documents (sujet d'épreuve).
  static Future<pw.MemoryImage> imageEnTete() async {
    final propre = MagasinCampus.instance.enteteActif;
    if (propre != null && propre.isNotEmpty) {
      return pw.MemoryImage(propre);
    }

    final cache = _enTeteInstitut;
    if (cache != null) return cache;
    final donnees = await rootBundle.load('assets/images/header-img-sheet.png');
    final image = pw.MemoryImage(donnees.buffer.asUint8List());
    _enTeteInstitut = image;
    return image;
  }

  /// Deux décimales et virgule décimale, comme sur le modèle papier.
  static String _note(double? valeur) =>
      valeur == null ? '' : valeur.toStringAsFixed(2).replaceAll('.', ',');

  // ---------- Fiche de report de notes ----------

  /// Rassemble les notes d'une matière, toutes épreuves confondues.
  /// Chaque nature d'épreuve alimente sa propre colonne.
  static List<LigneNotes> lignesDe(Matiere matiere) {
    final magasin = Magasin.instance;
    final epreuves = MagasinEpreuves.instance.epreuvesDe(matiere.id);
    final etudiants = magasin.etudiantsDe(matiere.niveauId);

    double? noteDe(String etudiantId, NatureEpreuve nature) {
      // Plusieurs épreuves de même nature : la plus récente fait foi.
      final concernees = epreuves.where((e) => e.nature == nature).toList()
        ..sort((a, b) => (b.debut ?? DateTime(0)).compareTo(a.debut ?? DateTime(0)));

      for (final e in concernees) {
        // Passation courante : une épreuve rejouée reporte la dernière note.
        final session = MagasinSessions.instance.sessionDe(e.id, etudiantId,
            passation: e.debut?.toIso8601String() ?? '');
        if (session?.note != null) return e.sur20(session!.note);
      }
      return null;
    }

    var numero = 0;
    return [
      for (final e in etudiants)
        LigneNotes(
          numero: ++numero,
          nom: e.nomComplet,
          matricule: e.matricule,
          sexe: e.sexe.code,
          controleContinu: noteDe(e.id, NatureEpreuve.controleContinu),
          sessionNormale: noteDe(e.id, NatureEpreuve.sessionNormale),
          rattrapage: noteDe(e.id, NatureEpreuve.rattrapage),
        ),
    ];
  }

  static Future<Uint8List> fiche({
    required Matiere matiere,
    required String enseignant,
    required List<LigneNotes> lignes,
  }) async {
    final magasin = Magasin.instance;
    final parametres = Parametres.instance;
    final image = await imageEnTete();

    final niveau = magasin.niveau(matiere.niveauId);
    final specialite =
        niveau == null ? null : magasin.specialite(niveau.specialiteId);
    final intituleSpecialite = niveau == null
        ? '-'
        : '${niveau.palier.libelle} - ${specialite?.intitule ?? "-"}';

    final document = pw.Document();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(42, 32, 42, 36),
        header: (contexte) => contexte.pageNumber == 1
            ? pw.SizedBox.shrink()
            : pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Image(image, height: 46),
              ),
        footer: (contexte) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${contexte.pageNumber} / ${contexte.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
        build: (contexte) => [
          pw.Center(child: pw.Image(image, height: 72)),
          pw.SizedBox(height: 12),

          pw.Center(
            // Campus choisi à la connexion : jamais un réglage saisi.
            child: pw.Text(MagasinCampus.instance.intituleActifImprimable,
                style: const pw.TextStyle(fontSize: 11)),
          ),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text(
              'FICHE DE REPORT DE NOTES ${parametres.annee}',
              style:
                  pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 6),
          // Aligné à droite sous le titre, comme sur le modèle papier.
          pw.Align(
            alignment: pw.Alignment.center,
            child: pw.Padding(
              padding: const pw.EdgeInsets.only(left: 120),
              child: _semestre(matiere.semestre),
            ),
          ),
          pw.SizedBox(height: 8),

          _champ('UNITÉ D\'ENSEIGNEMENT : ', matiere.intitule),
          _champDouble(
            'SPÉCIALITÉ : ', intituleSpecialite,
            '   CODE UE : ', matiere.code,
          ),
          _champ('INTITULÉ DU MODULE : ', matiere.intitule),
          _champDouble(
            'NOMS ET PRÉNOMS DE L\'ENSEIGNANT : ', enseignant,
            '    SIGNATURE ', '.........',
          ),
          _champ('RESPONSABLE DE LA SPÉCIALITÉ : ',
              specialite?.responsable ?? '-'),

          pw.SizedBox(height: 14),
          _tableauNotes(lignes),
        ],
      ),
    );

    return document.save();
  }

  /// « SEMESTRE N°1 ☐ 2 ☐ », la case du semestre courant étant cochée.
  static pw.Widget _semestre(int semestre) {
    pw.Widget case_(bool coche) => pw.Container(
          width: 14,
          height: 14,
          margin: const pw.EdgeInsets.symmetric(horizontal: 3),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: .8),
          ),
          alignment: pw.Alignment.center,
          child: coche
              ? pw.Text('X',
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold))
              : null,
        );

    return pw.Center(
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text('SEMESTRE N°1', style: const pw.TextStyle(fontSize: 10)),
          case_(semestre == 1),
          pw.Text('2', style: const pw.TextStyle(fontSize: 10)),
          case_(semestre == 2),
        ],
      ),
    );
  }

  static pw.Widget _champ(String etiquette, String valeur) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.RichText(
          text: pw.TextSpan(
            style: const pw.TextStyle(fontSize: 10),
            children: [
              pw.TextSpan(text: etiquette),
              pw.TextSpan(text: valeur),
            ],
          ),
        ),
      );

  static pw.Widget _champDouble(
    String etiquette1,
    String valeur1,
    String etiquette2,
    String valeur2,
  ) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.RichText(
          text: pw.TextSpan(
            style: const pw.TextStyle(fontSize: 10),
            children: [
              pw.TextSpan(text: etiquette1),
              pw.TextSpan(text: valeur1),
              pw.TextSpan(text: etiquette2),
              pw.TextSpan(text: valeur2),
            ],
          ),
        ),
      );

  static pw.Widget _tableauNotes(List<LigneNotes> lignes) {
    pw.Widget entete(String texte) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          alignment: pw.Alignment.center,
          child: pw.Text(texte,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 9)),
        );

    pw.Widget cellule(String texte,
            {pw.Alignment alignement = pw.Alignment.centerLeft}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 5),
          alignment: alignement,
          child: pw.Text(texte, style: const pw.TextStyle(fontSize: 9)),
        );

    return pw.Table(
      border: pw.TableBorder.all(width: .8, color: PdfColors.black),
      columnWidths: const {
        0: pw.FixedColumnWidth(28),
        1: pw.FlexColumnWidth(2.7),
        2: pw.FlexColumnWidth(1.6),
        3: pw.FixedColumnWidth(40),
        4: pw.FlexColumnWidth(1.75),
        5: pw.FlexColumnWidth(1.75),
        6: pw.FlexColumnWidth(1.6),
      },
      children: [
        pw.TableRow(
          children: [
            entete('N°'),
            entete('Noms et Prénoms'),
            entete('Matricule'),
            entete('Sexe'),
            entete('Note de\nContrôle Continu'),
            entete('Note de\nSession normale'),
            entete('Note de\nRattrapage'),
          ],
        ),
        for (final l in lignes)
          pw.TableRow(
            children: [
              cellule('${l.numero}', alignement: pw.Alignment.center),
              cellule(l.nom),
              cellule(l.matricule),
              cellule(l.sexe, alignement: pw.Alignment.center),
              cellule(_note(l.controleContinu),
                  alignement: pw.Alignment.center),
              cellule(_note(l.sessionNormale),
                  alignement: pw.Alignment.center),
              cellule(_note(l.rattrapage), alignement: pw.Alignment.center),
            ],
          ),
      ],
    );
  }

  // ---------- Liste de présence ----------

  /// Liste d'émargement d'une épreuve : présence déduite des sessions
  /// réellement ouvertes, avec une colonne signature à remplir à la main.
  static Future<Uint8List> listePresence({
    required Epreuve epreuve,
    required Matiere matiere,
    required String enseignant,
  }) async {
    final magasin = Magasin.instance;
    final parametres = Parametres.instance;
    final image = await imageEnTete();

    final niveau = magasin.niveau(matiere.niveauId);
    final specialite =
        niveau == null ? null : magasin.specialite(niveau.specialiteId);
    final etudiants = magasin.etudiantsDe(matiere.niveauId);

    final document = pw.Document();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(42, 32, 42, 36),
        header: (contexte) => contexte.pageNumber == 1
            ? pw.SizedBox.shrink()
            : pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Image(image, height: 46),
              ),
        footer: (contexte) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${contexte.pageNumber} / ${contexte.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
        build: (contexte) => [
          pw.Image(image, height: 62),
          pw.SizedBox(height: 14),

          pw.Center(
            // Campus choisi à la connexion : jamais un réglage saisi.
            child: pw.Text(MagasinCampus.instance.intituleActifImprimable,
                style: const pw.TextStyle(fontSize: 11)),
          ),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text(
              'LISTE DE PRÉSENCE ${parametres.annee}',
              style:
                  pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 12),

          _champ('ÉPREUVE : ', epreuve.titre),
          _champDouble('UNITÉ D\'ENSEIGNEMENT : ', matiere.intitule,
              '   CODE UE : ', matiere.code),
          _champ(
              'SPÉCIALITÉ : ',
              niveau == null
                  ? '-'
                  : '${niveau.palier.libelle} - ${specialite?.intitule ?? "-"}'),
          _champDouble(
            'DATE : ',
            epreuve.debut == null ? '...............' : _dateLongue(epreuve.debut!),
            '    DURÉE : ',
            '${epreuve.dureeMinutes} minutes',
          ),
          _champDouble('NOMS ET PRÉNOMS DE L\'ENSEIGNANT : ', enseignant,
              '    SIGNATURE ', '.........'),

          pw.SizedBox(height: 14),
          _tableauPresence(epreuve, etudiants),
          pw.SizedBox(height: 18),
          _recapitulatif(epreuve, etudiants.length),
        ],
      ),
    );

    return document.save();
  }

  static String _dateLongue(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
      'à ${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';

  static pw.Widget _tableauPresence(
      Epreuve epreuve, List<Etudiant> etudiants) {
    pw.Widget entete(String texte) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          alignment: pw.Alignment.center,
          child: pw.Text(texte,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 9)),
        );

    pw.Widget cellule(String texte,
            {pw.Alignment alignement = pw.Alignment.centerLeft,
            double hauteur = 0}) =>
        pw.Container(
          height: hauteur > 0 ? hauteur : null,
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 5),
          alignment: alignement,
          child: pw.Text(texte, style: const pw.TextStyle(fontSize: 9)),
        );

    var numero = 0;
    return pw.Table(
      border: pw.TableBorder.all(width: .8, color: PdfColors.black),
      columnWidths: const {
        0: pw.FixedColumnWidth(26),
        1: pw.FlexColumnWidth(3),
        2: pw.FlexColumnWidth(1.8),
        3: pw.FixedColumnWidth(38),
        4: pw.FlexColumnWidth(1.4),
        5: pw.FlexColumnWidth(2.2),
      },
      children: [
        pw.TableRow(
          children: [
            entete('N°'),
            entete('Noms et Prénoms'),
            entete('Matricule'),
            entete('Sexe'),
            entete('Présence'),
            entete('Émargement'),
          ],
        ),
        for (final e in etudiants)
          pw.TableRow(
            children: [
              cellule('${++numero}', alignement: pw.Alignment.center),
              cellule(e.nomComplet),
              cellule(e.matricule),
              cellule(e.sexe.code, alignement: pw.Alignment.center),
              // Une session ouverte prouve la connexion à l'épreuve.
              cellule(
                MagasinSessions.instance.sessionDe(epreuve.id, e.id,
                            passation:
                                epreuve.debut?.toIso8601String() ?? '') ==
                        null
                    ? 'Absent'
                    : 'Présent',
                alignement: pw.Alignment.center,
              ),
              // Colonne laissée vide : signature manuscrite.
              cellule('', hauteur: 22),
            ],
          ),
      ],
    );
  }

  static pw.Widget _recapitulatif(Epreuve epreuve, int inscrits) {
    final sessions = MagasinSessions.instance.sessionsDePassation(
        epreuve.id, epreuve.debut?.toIso8601String() ?? '');
    final presents = sessions.length;
    final remises = sessions.where((s) => s.estSoumise).length;

    pw.Widget entree(String etiquette, String valeur) => pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text('$etiquette : ', style: const pw.TextStyle(fontSize: 10)),
            pw.Text(valeur,
                style:
                    pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ],
        );

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        entree('Inscrits', '$inscrits'),
        entree('Présents', '$presents'),
        entree('Absents', '${inscrits - presents}'),
        entree('Copies remises', '$remises'),
      ],
    );
  }
}
