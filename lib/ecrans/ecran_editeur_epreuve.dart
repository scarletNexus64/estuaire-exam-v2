import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/magasin.dart';
import '../data/magasin_epreuves.dart';
import '../data/modeles.dart';
import '../data/session.dart';
import '../documents/sujet_epreuve.dart';
import 'ecran_apercu_pdf.dart';
import '../widgets/communs.dart';

/// Éditeur d'épreuve : questions, propositions, planification.
class EcranEditeurEpreuve extends StatefulWidget {
  final String epreuveId;

  const EcranEditeurEpreuve({super.key, required this.epreuveId});

  @override
  State<EcranEditeurEpreuve> createState() => _EcranEditeurEpreuveState();
}

class _EcranEditeurEpreuveState extends State<EcranEditeurEpreuve> {
  final _magasin = MagasinEpreuves.instance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _magasin,
      builder: (context, _) {
        final e = _magasin.epreuve(widget.epreuveId);
        // L'épreuve a pu être supprimée depuis un autre écran.
        if (e == null) {
          return Scaffold(
            backgroundColor: AppColors.fond,
            appBar: AppBar(title: const Text('Épreuve introuvable')),
            body: Center(
              child: Text('Cette épreuve n\'existe plus.',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          );
        }

        final matiere =
            Magasin.instance.matieres.where((m) => m.id == e.matiereId).firstOrNull;

        return Scaffold(
          backgroundColor: AppColors.fond,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BarreTitre(epreuve: e, matiere: matiere),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _ListeQuestions(epreuve: e)),
                    const VerticalDivider(width: 1),
                    SizedBox(width: 320, child: _PanneauReglages(epreuve: e)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BarreTitre extends StatelessWidget {
  final Epreuve epreuve;
  final Matiere? matiere;

  const _BarreTitre({required this.epreuve, required this.matiere});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          Espace.xl, Espace.lg, Espace.xl, Espace.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.bordure)),
      ),
      child: Row(
        children: [
          Tooltip(
            message: 'Retour',
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(rayonPetit),
              child: const Padding(
                padding: EdgeInsets.all(Espace.sm),
                child: Icon(Icons.arrow_back, size: 20),
              ),
            ),
          ),
          const SizedBox(width: Espace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(epreuve.titre,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(
                  matiere == null
                      ? 'Matière supprimée'
                      : '${matiere!.code} · ${matiere!.intitule}',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: Espace.lg),
          Pastille.neutre(
              '${epreuve.questions.length} question(s) · ${_bareme(epreuve)} pts'),
          const SizedBox(width: Espace.md),
          OutlinedButton.icon(
            onPressed: () => _renommer(context, epreuve),
            icon: const Icon(Icons.edit_outlined, size: 17),
            label: const Text('Renommer'),
          ),
          const SizedBox(width: Espace.sm),
          _BoutonSujet(epreuve: epreuve, matiere: matiere),
        ],
      ),
    );
  }

  static String _bareme(Epreuve e) {
    final total = e.bareme;
    return total == total.roundToDouble()
        ? '${total.toInt()}'
        : total.toStringAsFixed(1);
  }

  Future<void> _renommer(BuildContext context, Epreuve e) async {
    final titre = TextEditingController(text: e.titre);
    final consignes = TextEditingController(text: e.consignes);

    await showDialog(
      context: context,
      builder: (c) => DialogueFormulaire(
        titre: 'Modifier l\'épreuve',
        largeur: 520,
        champs: [
          TextField(
            controller: titre,
            decoration: const InputDecoration(labelText: 'Titre'),
          ),
          TextField(
            controller: consignes,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Consignes',
              hintText: 'Affichées à l\'étudiant avant le démarrage.',
              alignLabelWithHint: true,
            ),
          ),
        ],
        onEnregistrer: () async {
          if (titre.text.trim().isEmpty) return;
          final ok = await executer(
            c,
            () => MagasinEpreuves.instance.majEpreuve(e,
                titre: titre.text, consignes: consignes.text),
          );
          if (ok && c.mounted) Navigator.pop(c);
        },
      ),
    );
  }
}

/// Impression du sujet : version étudiant ou corrigé enseignant.
class _BoutonSujet extends StatelessWidget {
  final Epreuve epreuve;
  final Matiere? matiere;

  const _BoutonSujet({required this.epreuve, required this.matiere});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<bool>(
      tooltip: 'Imprimer le sujet',
      enabled: matiere != null && epreuve.questions.isNotEmpty,
      onSelected: (corrige) => _imprimer(context, corrige),
      itemBuilder: (_) => const [
        PopupMenuItem(value: false, child: Text('Sujet (étudiants)')),
        PopupMenuItem(value: true, child: Text('Corrigé (enseignant)')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Espace.lg, vertical: Espace.md - 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(rayonPetit),
          border: Border.all(color: AppColors.bordure),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.print_outlined, size: 17),
            SizedBox(width: Espace.sm),
            Text('Imprimer',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter')),
          ],
        ),
      ),
    );
  }

  Future<void> _imprimer(BuildContext context, bool corrige) async {
    final messager = ScaffoldMessenger.of(context);
    try {
      final pdf = await SujetEpreuve.generer(
        epreuve: epreuve,
        matiere: matiere!,
        enseignant: Session.instance.courant?.nomComplet ?? '...............',
        avecCorrige: corrige,
      );
      if (!context.mounted) return;

      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EcranApercuPdf(
          titre: corrige ? 'Corrigé de l\'épreuve' : 'Sujet d\'épreuve',
          sousTitre: epreuve.titre,
          nomFichier:
              '${corrige ? "corrige" : "sujet"}-${epreuve.codeAcces}',
          document: pdf,
        ),
      ));
    } catch (e) {
      messager.showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        content: Text('Impression impossible : $e'),
      ));
    }
  }
}

// ---------- Questions ----------

class _ListeQuestions extends StatelessWidget {
  final Epreuve epreuve;
  const _ListeQuestions({required this.epreuve});

  @override
  Widget build(BuildContext context) {
    final questions = epreuve.questionsTriees;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: questions.isEmpty
              ? const _AucuneQuestion()
              : ListView.builder(
                  padding: const EdgeInsets.all(Espace.xl),
                  itemCount: questions.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: Espace.lg),
                    child: _CarteQuestion(
                      epreuve: epreuve,
                      question: questions[i],
                      numero: i + 1,
                      premiere: i == 0,
                      derniere: i == questions.length - 1,
                    ),
                  ),
                ),
        ),
        Container(
          padding: const EdgeInsets.all(Espace.lg),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.bordure)),
          ),
          child: Row(
            children: [
              Text('Ajouter une question :',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: Espace.md),
              Expanded(
                child: Wrap(
                  spacing: Espace.sm,
                  runSpacing: Espace.sm,
                  children: [
                    for (final type in TypeQuestion.values)
                      _BoutonType(
                        type: type,
                        onAjouter: () => _ajouter(context, type),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _ajouter(BuildContext context, TypeQuestion type) async {
    await executer(
      context,
      () async {
        final q = await MagasinEpreuves.instance
            .ajouterQuestion(epreuve, '', type);
        // Choix et liste démarrent avec deux propositions vides : une
        // question sans proposition ne veut rien dire.
        if (!type.propositionsFigees) {
          await MagasinEpreuves.instance.ajouterProposition(q, '');
          await MagasinEpreuves.instance.ajouterProposition(q, '');
        }
      },
    );
  }
}

class _BoutonType extends StatelessWidget {
  final TypeQuestion type;
  final VoidCallback onAjouter;

  const _BoutonType({required this.type, required this.onAjouter});

  IconData get _icone => switch (type) {
        TypeQuestion.choixUnique => Icons.radio_button_checked,
        TypeQuestion.choixMultiple => Icons.check_box_outlined,
        TypeQuestion.listeDeroulante => Icons.arrow_drop_down_circle_outlined,
        TypeQuestion.vraiFaux => Icons.rule,
      };

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: type.description,
      child: OutlinedButton.icon(
        onPressed: onAjouter,
        icon: Icon(_icone, size: 17),
        label: Text(type.libelle),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
              horizontal: Espace.md, vertical: Espace.sm + 2),
        ),
      ),
    );
  }
}

class _CarteQuestion extends StatelessWidget {
  final Epreuve epreuve;
  final Question question;
  final int numero;
  final bool premiere;
  final bool derniere;

  const _CarteQuestion({
    required this.epreuve,
    required this.question,
    required this.numero,
    required this.premiere,
    required this.derniere,
  });

  @override
  Widget build(BuildContext context) {
    final anomalies = question.anomalies;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(rayon),
        border: Border.all(
            color: anomalies.isEmpty ? AppColors.bordure : AppColors.alerte),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _enTete(context, anomalies),
          Padding(
            padding: const EdgeInsets.all(Espace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  initialValue: question.enonce,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: 'Énoncé de la question…',
                  ),
                  onChanged: (v) => MagasinEpreuves.instance
                      .majQuestion(question, enonce: v),
                ),
                const SizedBox(height: Espace.lg),
                _Propositions(question: question),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _enTete(BuildContext context, List<String> anomalies) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Espace.lg, vertical: Espace.sm),
      decoration: const BoxDecoration(
        color: AppColors.fond,
        border: Border(bottom: BorderSide(color: AppColors.bordure)),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.bleuPale,
              shape: BoxShape.circle,
            ),
            child: Text('$numero',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.bleuSombre,
                  fontFamily: 'Inter',
                )),
          ),
          const SizedBox(width: Espace.md),
          _SelecteurType(question: question),
          const SizedBox(width: Espace.md),
          _ChampPoints(question: question),
          const Spacer(),
          if (anomalies.isNotEmpty)
            Tooltip(
              message: 'À corriger : ${anomalies.join(', ')}',
              child: const Icon(Icons.warning_amber_rounded,
                  size: 18, color: AppColors.alerte),
            ),
          const SizedBox(width: Espace.sm),
          _bouton(Icons.arrow_upward, 'Monter',
              premiere ? null : () => _deplacer(-1)),
          _bouton(Icons.arrow_downward, 'Descendre',
              derniere ? null : () => _deplacer(1)),
          _bouton(Icons.delete_outline, 'Supprimer',
              () => _supprimer(context), AppColors.danger),
        ],
      ),
    );
  }

  Widget _bouton(IconData icone, String info, VoidCallback? onTap,
      [Color? couleur]) {
    return Tooltip(
      message: info,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(rayonPetit),
        child: Padding(
          padding: const EdgeInsets.all(Espace.xs + 2),
          child: Icon(
            icone,
            size: 17,
            color: onTap == null
                ? AppColors.bordure
                : (couleur ?? AppColors.texteDoux),
          ),
        ),
      ),
    );
  }

  void _deplacer(int delta) =>
      MagasinEpreuves.instance.deplacerQuestion(epreuve, question, delta);

  Future<void> _supprimer(BuildContext context) async {
    final ok = await confirmerSuppression(
      context,
      titre: 'Supprimer la question ?',
      message: 'La question $numero et ses propositions seront supprimées.',
    );
    if (ok && context.mounted) {
      await executer(
        context,
        () => MagasinEpreuves.instance.supprimerQuestion(epreuve, question.id),
      );
    }
  }
}

class _SelecteurType extends StatelessWidget {
  final Question question;
  const _SelecteurType({required this.question});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TypeQuestion>(
          value: question.type,
          isDense: true,
          borderRadius: BorderRadius.circular(rayonPetit),
          style: const TextStyle(
            fontSize: 12.5,
            fontFamily: 'Inter',
            color: AppColors.texte,
          ),
          items: [
            for (final t in TypeQuestion.values)
              DropdownMenuItem(value: t, child: Text(t.libelle)),
          ],
          onChanged: (v) {
            if (v != null) {
              MagasinEpreuves.instance.majQuestion(question, type: v);
            }
          },
        ),
      ),
    );
  }
}

class _ChampPoints extends StatelessWidget {
  final Question question;
  const _ChampPoints({required this.question});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 32,
      child: TextFormField(
        initialValue: question.points == question.points.roundToDouble()
            ? '${question.points.toInt()}'
            : '${question.points}',
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12.5, fontFamily: 'Inter'),
        decoration: const InputDecoration(
          suffixText: 'pts',
          isDense: true,
          contentPadding:
              EdgeInsets.symmetric(horizontal: Espace.sm, vertical: Espace.sm),
        ),
        onChanged: (v) {
          final points = double.tryParse(v.replaceAll(',', '.'));
          if (points != null && points >= 0) {
            MagasinEpreuves.instance.majQuestion(question, points: points);
          }
        },
      ),
    );
  }
}

class _Propositions extends StatelessWidget {
  final Question question;
  const _Propositions({required this.question});

  @override
  Widget build(BuildContext context) {
    final propositions = question.propositionsTriees;
    final figees = question.type.propositionsFigees;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              question.type.multiple
                  ? 'Cochez toutes les bonnes réponses'
                  : 'Cochez la bonne réponse',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        const SizedBox(height: Espace.sm),
        for (final p in propositions) ...[
          _LigneProposition(
            question: question,
            proposition: p,
            // Vrai/faux : le texte est imposé, seule la bonne réponse change.
            figee: figees,
            // Toujours au moins deux propositions, sinon la question n'a
            // plus de sens.
            supprimable: !figees && propositions.length > 2,
          ),
          const SizedBox(height: Espace.sm),
        ],
        if (!figees)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => executer(
                context,
                () => MagasinEpreuves.instance
                    .ajouterProposition(question, ''),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Ajouter une proposition'),
            ),
          ),
      ],
    );
  }
}

class _LigneProposition extends StatelessWidget {
  final Question question;
  final Proposition proposition;
  final bool figee;
  final bool supprimable;

  const _LigneProposition({
    required this.question,
    required this.proposition,
    required this.figee,
    required this.supprimable,
  });

  @override
  Widget build(BuildContext context) {
    final magasin = MagasinEpreuves.instance;

    return Row(
      children: [
        // La forme du contrôle annonce le type de question à l'enseignant.
        Tooltip(
          message: proposition.correcte ? 'Bonne réponse' : 'Marquer correcte',
          child: InkWell(
            onTap: () => magasin.basculerCorrecte(question, proposition),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(Espace.xs),
              child: Icon(
                question.type.multiple
                    ? (proposition.correcte
                        ? Icons.check_box
                        : Icons.check_box_outline_blank)
                    : (proposition.correcte
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked),
                size: 20,
                color: proposition.correcte
                    ? AppColors.succes
                    : AppColors.texteFaible,
              ),
            ),
          ),
        ),
        const SizedBox(width: Espace.sm),
        Expanded(
          child: figee
              ? Text(proposition.texte,
                  style: const TextStyle(
                      fontSize: 13.5, fontFamily: 'Inter'))
              : TextFormField(
                  initialValue: proposition.texte,
                  style: const TextStyle(fontSize: 13.5, fontFamily: 'Inter'),
                  decoration: const InputDecoration(
                    hintText: 'Proposition…',
                    isDense: true,
                  ),
                  onChanged: (v) =>
                      magasin.majProposition(proposition, texte: v),
                ),
        ),
        if (supprimable) ...[
          const SizedBox(width: Espace.sm),
          Tooltip(
            message: 'Retirer',
            child: InkWell(
              onTap: () => executer(
                context,
                () => magasin.supprimerProposition(question, proposition.id),
              ),
              borderRadius: BorderRadius.circular(rayonPetit),
              child: const Padding(
                padding: EdgeInsets.all(Espace.xs),
                child: Icon(Icons.close,
                    size: 16, color: AppColors.texteFaible),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AucuneQuestion extends StatelessWidget {
  const _AucuneQuestion();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.quiz_outlined,
              size: 34, color: AppColors.texteFaible),
          const SizedBox(height: Espace.md),
          Text('Aucune question',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Espace.xs),
          Text('Choisissez un type de question ci-dessous pour commencer.',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

// ---------- Réglages ----------

class _PanneauReglages extends StatelessWidget {
  final Epreuve epreuve;
  const _PanneauReglages({required this.epreuve});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: ListView(
        padding: const EdgeInsets.all(Espace.xl),
        children: [
          Text('ÉVALUATION', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: Espace.md),
          // Détermine la colonne de la fiche de report où la note ira.
          SelecteurCherchable<NatureEpreuve>(
            etiquette: 'Nature',
            valeur: epreuve.nature,
            options: [
              for (final n in NatureEpreuve.values)
                OptionSelecteur(
                  valeur: n,
                  libelle: n.libelle,
                  detail: 'Colonne « ${n.libelle} » de la fiche de notes',
                ),
            ],
            onChange: (v) =>
                MagasinEpreuves.instance.majEpreuve(epreuve, nature: v),
          ),
          const SizedBox(height: Espace.xxl),
          Text('PLANIFICATION',
              style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: Espace.md),
          _ChampDate(epreuve: epreuve),
          const SizedBox(height: Espace.lg),
          _ChampDuree(epreuve: epreuve),
          const SizedBox(height: Espace.lg),
          _Fin(epreuve: epreuve),
          const SizedBox(height: Espace.xxl),
          Text('DÉROULEMENT', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: Espace.sm),
          _Bascule(
            titre: 'Mélanger les questions',
            description: 'Chaque étudiant reçoit un ordre différent.',
            valeur: epreuve.melangerQuestions,
            onChange: (v) => MagasinEpreuves.instance
                .majEpreuve(epreuve, melangerQuestions: v),
          ),
          _Bascule(
            titre: 'Mélanger les propositions',
            description: 'L\'ordre des réponses varie d\'un étudiant à l\'autre.',
            valeur: epreuve.melangerPropositions,
            onChange: (v) => MagasinEpreuves.instance
                .majEpreuve(epreuve, melangerPropositions: v),
          ),
          const SizedBox(height: Espace.xxl),
          Text('ACCÈS', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: Espace.md),
          _CodeAcces(code: epreuve.codeAcces),
          const SizedBox(height: Espace.xxl),
          _Publication(epreuve: epreuve),
        ],
      ),
    );
  }
}

class _ChampDate extends StatelessWidget {
  final Epreuve epreuve;
  const _ChampDate({required this.epreuve});

  @override
  Widget build(BuildContext context) {
    final d = epreuve.debut;

    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Début'),
      child: InkWell(
        onTap: () => _choisir(context),
        child: Row(
          children: [
            Expanded(
              child: Text(
                d == null ? 'Non planifiée' : _format(d),
                style: TextStyle(
                  fontSize: 13.5,
                  fontFamily: 'Inter',
                  color: d == null ? AppColors.texteFaible : AppColors.texte,
                ),
              ),
            ),
            const Icon(Icons.event_outlined,
                size: 17, color: AppColors.texteDoux),
          ],
        ),
      ),
    );
  }

  static String _format(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
      'à ${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';

  Future<void> _choisir(BuildContext context) async {
    final maintenant = DateTime.now();
    final initiale = epreuve.debut ?? maintenant;

    final jour = await showDatePicker(
      context: context,
      initialDate: initiale.isBefore(maintenant) ? maintenant : initiale,
      // Aujourd'hui au plus tôt : une épreuve planifiée dans le passé
      // serait close avant d'avoir commencé.
      firstDate: DateTime(maintenant.year, maintenant.month, maintenant.day),
      lastDate: DateTime(maintenant.year + 2),
      helpText: 'Date de l\'épreuve',
    );
    if (jour == null || !context.mounted) return;

    final heure = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          initiale.isBefore(maintenant) ? maintenant : initiale),
      helpText: 'Heure de début',
    );
    if (heure == null || !context.mounted) return;

    final choisi =
        DateTime(jour.year, jour.month, jour.day, heure.hour, heure.minute);

    // Le sélecteur de date ne borne pas l'heure : refuser ici évite
    // qu'une épreuve du jour soit fixée à une heure déjà passée.
    if (choisi.isBefore(maintenant)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        content: Text(
          'Cette heure est déjà passée. Choisissez un horaire postérieur à '
          '${_format(maintenant)}.',
        ),
      ));
      return;
    }

    await executer(
      context,
      () => MagasinEpreuves.instance.majEpreuve(epreuve, debut: choisi),
    );
  }
}

class _ChampDuree extends StatelessWidget {
  final Epreuve epreuve;
  const _ChampDuree({required this.epreuve});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: '${epreuve.dureeMinutes}',
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Durée',
        suffixText: 'minutes',
      ),
      onChanged: (v) {
        final duree = int.tryParse(v.trim());
        if (duree != null && duree > 0) {
          MagasinEpreuves.instance
              .majEpreuve(epreuve, dureeMinutes: duree);
        }
      },
    );
  }
}

/// Fin déduite du début et de la durée, jamais saisie à la main.
class _Fin extends StatelessWidget {
  final Epreuve epreuve;
  const _Fin({required this.epreuve});

  @override
  Widget build(BuildContext context) {
    final fin = epreuve.fin;

    return Container(
      padding: const EdgeInsets.all(Espace.md),
      decoration: BoxDecoration(
        color: AppColors.fond,
        borderRadius: BorderRadius.circular(rayonPetit),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_off_outlined,
              size: 16, color: AppColors.texteDoux),
          const SizedBox(width: Espace.sm),
          Text('Fin', style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          Text(
            fin == null ? '—' : _ChampDate._format(fin),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
              color: AppColors.texte,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bascule extends StatelessWidget {
  final String titre;
  final String description;
  final bool valeur;
  final ValueChanged<bool> onChange;

  const _Bascule({
    required this.titre,
    required this.description,
    required this.valeur,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: valeur,
      onChanged: onChange,
      title: Text(titre,
          style: const TextStyle(fontSize: 13, fontFamily: 'Inter')),
      subtitle: Text(description,
          style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.texteDoux,
              fontFamily: 'Inter')),
      contentPadding: EdgeInsets.zero,
      activeThumbColor: AppColors.succes,
      dense: true,
    );
  }
}

class _CodeAcces extends StatelessWidget {
  final String code;
  const _CodeAcces({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Espace.lg),
      decoration: BoxDecoration(
        color: AppColors.bleuPale,
        borderRadius: BorderRadius.circular(rayonPetit),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Code d\'accès étudiant',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: Espace.xs),
          SelectableText(
            code,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
              color: AppColors.bleuSombre,
            ),
          ),
          const SizedBox(height: Espace.xs),
          Text(
            'Le lien de composition sera généré au démarrage du serveur.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Publication : bloquée tant que l'épreuve n'est pas complète.
class _Publication extends StatelessWidget {
  final Epreuve epreuve;
  const _Publication({required this.epreuve});

  @override
  Widget build(BuildContext context) {
    final manques = _manques();
    final pret = manques.isEmpty;
    final publiee = epreuve.etat != EtatEpreuve.brouillon;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!pret) ...[
          Container(
            padding: const EdgeInsets.all(Espace.md),
            decoration: BoxDecoration(
              color: AppColors.alertePale,
              borderRadius: BorderRadius.circular(rayonPetit),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 15, color: AppColors.alerte),
                    const SizedBox(width: Espace.sm),
                    Text('À compléter',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: Espace.sm),
                for (final m in manques)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text('• $m',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Espace.md),
        ],
        FilledButton.icon(
          onPressed: !pret
              ? null
              : () => executer(
                    context,
                    () => MagasinEpreuves.instance.majEpreuve(
                      epreuve,
                      etat: publiee
                          ? EtatEpreuve.brouillon
                          : EtatEpreuve.planifiee,
                    ),
                    succes: publiee
                        ? 'Épreuve repassée en brouillon.'
                        : 'Épreuve planifiée.',
                  ),
          icon: Icon(publiee ? Icons.undo : Icons.check, size: 18),
          label: Text(publiee ? 'Repasser en brouillon' : 'Planifier'),
          style: publiee
              ? FilledButton.styleFrom(backgroundColor: AppColors.texteDoux)
              : null,
        ),
      ],
    );
  }

  List<String> _manques() {
    final manques = <String>[];
    if (epreuve.titre.trim().isEmpty) manques.add('Donner un titre');
    if (epreuve.debut == null) manques.add('Fixer la date de début');
    if (epreuve.questions.isEmpty) {
      manques.add('Ajouter au moins une question');
    }
    final incompletes =
        epreuve.questions.where((q) => q.anomalies.isNotEmpty).length;
    if (incompletes > 0) {
      manques.add('Corriger $incompletes question(s) incomplète(s)');
    }
    return manques;
  }
}
