import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/magasin.dart';
import '../data/magasin_epreuves.dart';
import '../data/magasin_sessions.dart';
import '../data/modeles.dart';
import '../data/session.dart';
import '../widgets/communs.dart';
import 'ecran_editeur_epreuve.dart';
import 'ecran_surveillance.dart';

/// Espace enseignant : matières confiées, étudiants concernés et épreuves.
class EcranMesMatieres extends StatefulWidget {
  const EcranMesMatieres({super.key});

  @override
  State<EcranMesMatieres> createState() => _EcranMesMatieresState();
}

class _EcranMesMatieresState extends State<EcranMesMatieres> {
  /// Matière ouverte ; null = grille des matières.
  String? _matiereId;

  @override
  Widget build(BuildContext context) {
    final magasin = Magasin.instance;

    return AnimatedBuilder(
      animation: Listenable.merge(
          [magasin, Session.instance, MagasinEpreuves.instance]),
      builder: (context, _) {
        final utilisateur = Session.instance.courant;
        final confiees = utilisateur?.matiereIds ?? const <String>[];
        final mesMatieres =
            magasin.matieres.where((m) => confiees.contains(m.id)).toList();

        // La matière a pu être retirée de ses affectations entre-temps.
        final ouverte = _matiereId == null
            ? null
            : mesMatieres.where((m) => m.id == _matiereId).firstOrNull;

        if (ouverte != null) {
          return _DetailMatiere(
            matiere: ouverte,
            onRetour: () => setState(() => _matiereId = null),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EnTetePage(
              titre: 'Mes matières',
              sousTitre: utilisateur == null
                  ? 'Matières qui vous sont confiées.'
                  : '${utilisateur.nomComplet} — ${mesMatieres.length} matière(s) à évaluer.',
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    Espace.xxl, 0, Espace.xxl, Espace.xxl),
                child: mesMatieres.isEmpty
                    ? const _AucuneMatiere()
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 340,
                          mainAxisExtent: 176,
                          crossAxisSpacing: Espace.lg,
                          mainAxisSpacing: Espace.lg,
                        ),
                        itemCount: mesMatieres.length,
                        itemBuilder: (context, i) {
                          final m = mesMatieres[i];
                          return _CarteMatiere(
                            matiere: m,
                            onOuvrir: () =>
                                setState(() => _matiereId = m.id),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CarteMatiere extends StatefulWidget {
  final Matiere matiere;
  final VoidCallback onOuvrir;

  const _CarteMatiere({required this.matiere, required this.onOuvrir});

  @override
  State<_CarteMatiere> createState() => _CarteMatiereState();
}

class _CarteMatiereState extends State<_CarteMatiere> {
  bool _survol = false;

  @override
  Widget build(BuildContext context) {
    final m = Magasin.instance;
    final mat = widget.matiere;
    final nbEpreuves = MagasinEpreuves.instance.epreuvesDe(mat.id).length;

    return MouseRegion(
      onEnter: (_) => setState(() => _survol = true),
      onExit: (_) => setState(() => _survol = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onOuvrir,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(Espace.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(rayon),
            border: Border.all(
                color: _survol ? AppColors.bleu : AppColors.bordure),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Pastille.bleue(mat.code),
                  const SizedBox(width: Espace.sm),
                  Pastille.neutre('S${mat.semestre}'),
                  const Spacer(),
                  Icon(Icons.arrow_forward,
                      size: 16,
                      color:
                          _survol ? AppColors.bleu : AppColors.texteFaible),
                ],
              ),
              const SizedBox(height: Espace.md),
              Text(
                mat.intitule,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: Espace.xs),
              Text(
                m.nomNiveau(mat.niveauId),
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.groups_outlined,
                      size: 16, color: AppColors.texteFaible),
                  const SizedBox(width: Espace.xs + 2),
                  Text('${m.etudiantsDe(mat.niveauId).length} étudiant(s)',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(width: Espace.lg),
                  const Icon(Icons.quiz_outlined,
                      size: 16, color: AppColors.texteFaible),
                  const SizedBox(width: Espace.xs + 2),
                  Text('$nbEpreuves épreuve(s)',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Détail d'une matière ----------

class _DetailMatiere extends StatefulWidget {
  final Matiere matiere;
  final VoidCallback onRetour;

  const _DetailMatiere({required this.matiere, required this.onRetour});

  @override
  State<_DetailMatiere> createState() => _DetailMatiereState();
}

class _DetailMatiereState extends State<_DetailMatiere> {
  int _onglet = 0;

  @override
  Widget build(BuildContext context) {
    final m = Magasin.instance;
    final mat = widget.matiere;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EnTetePage(
          titre: mat.intitule,
          sousTitre: '${mat.code} · ${m.nomNiveau(mat.niveauId)}',
          actions: [
            OutlinedButton.icon(
              onPressed: widget.onRetour,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Mes matières'),
            ),
            FilledButton.icon(
              onPressed: () => _creerEpreuve(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nouvelle épreuve'),
            ),
          ],
        ),
        Padding(
          padding:
              const EdgeInsets.fromLTRB(Espace.xxl, 0, Espace.xxl, Espace.lg),
          child: Row(
            children: [
              _Onglet(
                titre: 'Épreuves',
                icone: Icons.quiz_outlined,
                actif: _onglet == 0,
                onTap: () => setState(() => _onglet = 0),
              ),
              const SizedBox(width: Espace.sm),
              _Onglet(
                titre: 'Étudiants',
                icone: Icons.groups_outlined,
                actif: _onglet == 1,
                onTap: () => setState(() => _onglet = 1),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                Espace.xxl, 0, Espace.xxl, Espace.xxl),
            child: _onglet == 0
                ? _ListeEpreuves(matiere: mat)
                : _ListeEtudiants(niveauId: mat.niveauId),
          ),
        ),
      ],
    );
  }

  Future<void> _creerEpreuve(BuildContext context) async {
    final titre = TextEditingController(
        text: 'Évaluation ${widget.matiere.code}');

    final valide = await showDialog<bool>(
      context: context,
      builder: (c) => DialogueFormulaire(
        titre: 'Nouvelle épreuve',
        champs: [
          TextField(
            controller: titre,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Titre de l\'épreuve',
              hintText: 'Contrôle continu n°1',
            ),
          ),
        ],
        onEnregistrer: () {
          if (titre.text.trim().isEmpty) return;
          Navigator.pop(c, true);
        },
      ),
    );
    if (valide != true || !context.mounted) return;

    Epreuve? creee;
    final ok = await executer(context, () async {
      creee = await MagasinEpreuves.instance.creerEpreuve(
        titre.text,
        widget.matiere.id,
        auteurId: Session.instance.courant?.id,
      );
    });
    if (!ok || creee == null || !context.mounted) return;

    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EcranEditeurEpreuve(epreuveId: creee!.id),
    ));
  }
}

class _Onglet extends StatelessWidget {
  final String titre;
  final IconData icone;
  final bool actif;
  final VoidCallback onTap;

  const _Onglet({
    required this.titre,
    required this.icone,
    required this.actif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(rayonPetit),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(
            horizontal: Espace.lg, vertical: Espace.md),
        decoration: BoxDecoration(
          color: actif ? AppColors.rougePale : AppColors.surface,
          borderRadius: BorderRadius.circular(rayonPetit),
          border:
              Border.all(color: actif ? AppColors.rouge : AppColors.bordure),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone,
                size: 17,
                color: actif ? AppColors.rouge : AppColors.texteDoux),
            const SizedBox(width: Espace.sm),
            Text(
              titre,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
                color: actif ? AppColors.rouge : AppColors.texte,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListeEpreuves extends StatelessWidget {
  final Matiere matiere;
  const _ListeEpreuves({required this.matiere});

  static const _flex = <double>[3, 1.4, 1.6, 1.2, 1.2, 1];

  @override
  Widget build(BuildContext context) {
    final liste = MagasinEpreuves.instance.epreuvesDe(matiere.id);

    return Tableau(
      colonnes: const [
        'Titre',
        'Questions',
        'Début',
        'Durée',
        'État',
        '',
      ],
      flex: _flex,
      messageVide: 'Aucune épreuve pour cette matière.',
      lignes: [
        for (final e in liste)
          LigneTableau(
            flex: _flex,
            cellules: [
              cellule(e.titre, gras: true),
              cellule('${e.questions.length} · ${_bareme(e)} pts'),
              cellule(e.debut == null ? 'Non planifiée' : _dateCourte(e.debut!),
                  couleur: AppColors.texteDoux),
              cellule('${e.dureeMinutes} min',
                  couleur: AppColors.texteDoux),
              Align(
                alignment: Alignment.centerLeft,
                child: _PastilleEtat(etat: e.etat),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Tooltip(
                    message: 'Modifier l\'épreuve',
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EcranEditeurEpreuve(epreuveId: e.id),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(rayonPetit),
                      child: const Padding(
                        padding: EdgeInsets.all(Espace.xs + 2),
                        child: Icon(Icons.edit_outlined,
                            size: 17, color: AppColors.bleu),
                      ),
                    ),
                  ),
                  Tooltip(
                    // Diffuser un brouillon n'a pas de sens : aucun
                    // étudiant ne pourrait s'y connecter.
                    message: e.etat == EtatEpreuve.brouillon
                        ? 'Planifiez l\'épreuve pour la diffuser'
                        : 'Diffuser et surveiller',
                    child: InkWell(
                      onTap: e.etat == EtatEpreuve.brouillon
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EcranSurveillance(epreuveId: e.id),
                                ),
                              ),
                      borderRadius: BorderRadius.circular(rayonPetit),
                      child: Padding(
                        padding: const EdgeInsets.all(Espace.xs + 2),
                        child: Icon(
                          Icons.podcasts_outlined,
                          size: 17,
                          color: e.etat == EtatEpreuve.brouillon
                              ? AppColors.bordure
                              : AppColors.succes,
                        ),
                      ),
                    ),
                  ),
                  _BoutonSupprimer(epreuve: e),
                ],
              ),
            ],
          ),
      ],
    );
  }

  String _bareme(Epreuve e) {
    final total = e.bareme;
    return total == total.roundToDouble()
        ? '${total.toInt()}'
        : total.toStringAsFixed(1);
  }

  static String _dateCourte(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';
}

/// Suppression d'une épreuve.
///
/// Bloquée dès qu'un étudiant a composé : effacer l'épreuve emporterait
/// les copies par cascade, et une note remise ne se récupère pas.
class _BoutonSupprimer extends StatelessWidget {
  final Epreuve epreuve;
  const _BoutonSupprimer({required this.epreuve});

  @override
  Widget build(BuildContext context) {
    final copies = MagasinSessions.instance.sessionsDe(epreuve.id).length;
    final verrouillee = copies > 0;

    return Tooltip(
      message: verrouillee
          ? '$copies copie(s) enregistrée(s) : suppression impossible'
          : 'Supprimer l\'épreuve',
      child: InkWell(
        onTap: verrouillee ? null : () => _supprimer(context),
        borderRadius: BorderRadius.circular(rayonPetit),
        child: Padding(
          padding: const EdgeInsets.all(Espace.xs + 2),
          child: Icon(
            Icons.delete_outline,
            size: 17,
            color: verrouillee ? AppColors.bordure : AppColors.danger,
          ),
        ),
      ),
    );
  }

  Future<void> _supprimer(BuildContext context) async {
    final planifiee = epreuve.etat != EtatEpreuve.brouillon;

    final ok = await confirmerSuppression(
      context,
      titre: 'Supprimer l\'épreuve ?',
      message: planifiee
          ? '« ${epreuve.titre} » est planifiée. Elle sera supprimée avec ses '
              '${epreuve.questions.length} question(s). Les étudiants ne '
              'pourront plus s\'y connecter.'
          : '« ${epreuve.titre} » et ses ${epreuve.questions.length} '
              'question(s) seront définitivement supprimées.',
    );
    if (!ok || !context.mounted) return;

    await executer(
      context,
      () => MagasinEpreuves.instance.supprimerEpreuve(epreuve.id),
      succes: 'Épreuve supprimée.',
    );
  }
}

class _PastilleEtat extends StatelessWidget {
  final EtatEpreuve etat;
  const _PastilleEtat({required this.etat});

  @override
  Widget build(BuildContext context) => switch (etat) {
        EtatEpreuve.brouillon => Pastille.neutre(etat.libelle),
        EtatEpreuve.planifiee => Pastille.bleue(etat.libelle),
        EtatEpreuve.enCours => Pastille.succes(etat.libelle),
        EtatEpreuve.terminee => Pastille(
            texte: etat.libelle,
            couleur: AppColors.alerte,
            fond: AppColors.alertePale,
          ),
      };
}

class _ListeEtudiants extends StatelessWidget {
  final String niveauId;
  const _ListeEtudiants({required this.niveauId});

  static const _flex = <double>[1.6, 3, 0.8, 1];

  @override
  Widget build(BuildContext context) {
    final liste = Magasin.instance.etudiantsDe(niveauId);

    return Tableau(
      colonnes: const ['Matricule', 'Noms et prénoms', 'Sexe', 'État'],
      flex: _flex,
      messageVide: 'Aucun étudiant dans cette promotion.',
      lignes: [
        for (final e in liste)
          LigneTableau(
            flex: _flex,
            cellules: [
              cellule(e.matricule,
                  couleur: AppColors.bleuSombre, gras: true),
              cellule(e.nomComplet, gras: true),
              cellule(e.sexe.code),
              Align(
                alignment: Alignment.centerLeft,
                child: e.actif
                    ? Pastille.succes('Inscrit')
                    : Pastille.neutre('Inactif'),
              ),
            ],
          ),
      ],
    );
  }
}

class _AucuneMatiere extends StatelessWidget {
  const _AucuneMatiere();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(rayon),
        border: Border.all(color: AppColors.bordure),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book_outlined,
              size: 34, color: AppColors.texteFaible),
          const SizedBox(height: Espace.md),
          Text(
            'Aucune matière ne vous est encore confiée.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: Espace.xs),
          Text(
            'L\'administration les assigne depuis la rubrique « Assignations ».',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
