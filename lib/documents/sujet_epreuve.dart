import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/magasin.dart';
import '../data/magasin_campus.dart';
import '../data/modeles.dart';
import '../data/parametres.dart';
import 'fiche_notes.dart';

/// Sujet d'épreuve à distribuer sur papier, en secours d'une panne réseau
/// ou pour l'archivage exigé par l'administration.
class SujetEpreuve {
  SujetEpreuve._();

  /// [avecCorrige] imprime les bonnes réponses : la version enseignant.
  /// Ne jamais distribuer aux étudiants.
  static Future<Uint8List> generer({
    required Epreuve epreuve,
    required Matiere matiere,
    required String enseignant,
    bool avecCorrige = false,
  }) async {
    final magasin = Magasin.instance;
    final image = await FicheNotes.imageEnTete();

    final niveau = magasin.niveau(matiere.niveauId);
    final specialite =
        niveau == null ? null : magasin.specialite(niveau.specialiteId);

    final document = pw.Document();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(42, 32, 42, 40),
        header: (contexte) => contexte.pageNumber == 1
            ? pw.SizedBox.shrink()
            : pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Image(image, height: 40),
              ),
        footer: (contexte) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              avecCorrige ? 'CORRIGE - usage enseignant' : matiere.code,
              style: pw.TextStyle(
                fontSize: 8,
                color: avecCorrige ? PdfColors.red : PdfColors.grey700,
                fontWeight:
                    avecCorrige ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
            pw.Text(
              'Page ${contexte.pageNumber} / ${contexte.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        ),
        build: (contexte) => [
          pw.Image(image, height: 62),
          pw.SizedBox(height: 12),

          pw.Center(
            child: pw.Text(MagasinCampus.instance.intituleActifImprimable,
                style: const pw.TextStyle(fontSize: 11)),
          ),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              epreuve.titre.toUpperCase(),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
          ),
          if (avecCorrige) ...[
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text('CORRIGÉ',
                  style: pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.red,
                      fontWeight: pw.FontWeight.bold)),
            ),
          ],
          pw.SizedBox(height: 12),

          _entete(epreuve, matiere, specialite, niveau, enseignant),
          pw.SizedBox(height: 10),

          if (epreuve.consignes.trim().isNotEmpty) ...[
            _consignes(epreuve.consignes),
            pw.SizedBox(height: 12),
          ],

          for (final q in epreuve.questionsTriees)
            _question(q, epreuve.questionsTriees.indexOf(q) + 1, avecCorrige),
        ],
      ),
    );

    return document.save();
  }

  static pw.Widget _entete(
    Epreuve epreuve,
    Matiere matiere,
    Specialite? specialite,
    Niveau? niveau,
    String enseignant,
  ) {
    pw.Widget ligne(String etiquette, String valeur) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.RichText(
            text: pw.TextSpan(
              style: const pw.TextStyle(fontSize: 10),
              children: [
                pw.TextSpan(text: '$etiquette : '),
                pw.TextSpan(
                    text: valeur,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
        );

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(width: .8)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          ligne('UNITÉ D\'ENSEIGNEMENT',
              '${matiere.code} - ${matiere.intitule}'),
          ligne(
            'SPÉCIALITÉ',
            niveau == null
                ? '-'
                : '${niveau.palier.libelle} - ${specialite?.intitule ?? "-"}',
          ),
          ligne('ENSEIGNANT', enseignant),
          pw.Row(
            children: [
              pw.Expanded(
                  child: ligne('DURÉE', '${epreuve.dureeMinutes} minutes')),
              pw.Expanded(child: ligne('BARÈME', '${_nombre(epreuve.bareme)} points')),
              pw.Expanded(
                  child: ligne('ANNÉE', Parametres.instance.annee)),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            children: [
              pw.Text('NOM ET PRÉNOMS : ',
                  style: const pw.TextStyle(fontSize: 10)),
              pw.Expanded(
                child: pw.Container(
                  height: 14,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(width: .6)),
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Text('MATRICULE : ',
                  style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(
                width: 110,
                child: pw.Container(
                  height: 14,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(width: .6)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _consignes(String texte) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(8),
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('CONSIGNES',
                style: pw.TextStyle(
                    fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 3),
            pw.Text(texte, style: const pw.TextStyle(fontSize: 9.5)),
          ],
        ),
      );

  static pw.Widget _question(Question q, int numero, bool avecCorrige) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('$numero. ',
                  style: pw.TextStyle(
                      fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
              pw.Expanded(
                child: pw.Text(q.enonce,
                    style: pw.TextStyle(
                        fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Text('(${_nombre(q.points)} pt)',
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey700)),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 14),
            child: pw.Text(
              q.type.multiple
                  ? 'Plusieurs réponses possibles.'
                  : 'Une seule réponse.',
              style: const pw.TextStyle(
                  fontSize: 8.5, color: PdfColors.grey700),
            ),
          ),
          pw.SizedBox(height: 4),
          for (var i = 0; i < q.propositionsTriees.length; i++)
            _proposition(q.propositionsTriees[i], i, q, avecCorrige),
        ],
      ),
    );
  }

  static pw.Widget _proposition(
      Proposition p, int index, Question q, bool avecCorrige) {
    // a), b), c)… plutôt que des cases : l'étudiant entoure sa réponse.
    final lettre = String.fromCharCode(97 + index);
    final juste = avecCorrige && p.correcte;

    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 20, bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 12,
            height: 12,
            margin: const pw.EdgeInsets.only(right: 6, top: 1),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: .7),
              shape: q.type.multiple
                  ? pw.BoxShape.rectangle
                  : pw.BoxShape.circle,
            ),
            alignment: pw.Alignment.center,
            child: juste
                ? pw.Text('X',
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold))
                : null,
          ),
          pw.Expanded(
            child: pw.Text(
              '$lettre) ${p.texte}',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight:
                    juste ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _nombre(double valeur) => valeur == valeur.roundToDouble()
      ? '${valeur.toInt()}'
      : valeur.toStringAsFixed(1);
}
