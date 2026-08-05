import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/magasin.dart';
import '../data/modeles.dart';
import '../widgets/communs.dart';

/// Promotions ouvertes : un palier d'étude ouvert pour une spécialité.
class EcranNiveaux extends StatefulWidget {
  const EcranNiveaux({super.key});

  @override
  State<EcranNiveaux> createState() => _EcranNiveauxState();
}

class _EcranNiveauxState extends State<EcranNiveaux> {
  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final m = Magasin.instance;
    return AnimatedBuilder(
      animation: m,
      builder: (context, _) {
        // L'import INSAM ouvre des centaines de spécialités : sans filtre
        // la page devient inexploitable.
        final q = _recherche.trim().toLowerCase();
        final visibles = q.isEmpty
            ? m.specialites
            : m.specialites
                .where((s) =>
                    s.intitule.toLowerCase().contains(q) ||
                    s.abreviation.toLowerCase().contains(q))
                .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EnTetePage(
              titre: 'Niveaux',
              sousTitre:
                  'Paliers ouverts, regroupés par spécialité. Chaque ligne est une promotion.',
              actions: [
                FilledButton.icon(
                  onPressed: m.specialites.isEmpty
                      ? null
                      : () => _ouvrirFormulaire(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ouvrir un niveau'),
                ),
              ],
            ),
            if (m.specialites.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Espace.xxl, 0, Espace.xxl, Espace.lg),
                child: Row(
                  children: [
                    ChampRecherche(
                      indice: 'Rechercher une spécialité…',
                      onChange: (v) => setState(() => _recherche = v),
                    ),
                    const SizedBox(width: Espace.lg),
                    Text(
                      '${visibles.length} spécialité(s)'
                      '${q.isEmpty ? '' : ' sur ${m.specialites.length}'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            Expanded(
              child: m.specialites.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.fromLTRB(
                          Espace.xxl, 0, Espace.xxl, Espace.xxl),
                      child: _AucuneSpecialite(),
                    )
                  : visibles.isEmpty
                      ? const Center(
                          child: Text('Aucune spécialité ne correspond.'))
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(
                              Espace.xxl, 0, Espace.xxl, Espace.xxl),
                          children: [
                            // Une carte par spécialité : les paliers d'une même
                            // filière restent visuellement ensemble.
                            for (final s in visibles) ...[
                              _CarteSpecialite(
                                specialite: s,
                                niveaux: m.niveauxDe(s.id),
                                onOuvrir: () =>
                                    _ouvrirFormulaire(context, specialite: s),
                                onModifier: (n) =>
                                    _ouvrirFormulaire(context, niveau: n),
                                onSupprimer: (n) => _supprimer(context, n),
                              ),
                              const SizedBox(height: Espace.xxl),
                            ],
                          ],
                        ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _supprimer(BuildContext context, Niveau n) async {
    final m = Magasin.instance;
    final nb = m.effectifNiveau(n.id);
    final nbMatieres = m.nbMatieresNiveau(n.id);
    final intitule = m.nomNiveau(n.id);

    final ok = await confirmerSuppression(
      context,
      titre: 'Supprimer le niveau ?',
      message: nb > 0 || nbMatieres > 0
          ? '« $intitule » sera supprimé, ainsi que ses $nb étudiant(s) et ses $nbMatieres matière(s).'
          : '« $intitule » sera définitivement supprimé.',
    );
    if (ok && context.mounted) {
      await executer(context, () => m.supprimerNiveau(n.id));
    }
  }

  /// [specialite] pré-sélectionne la filière : le « + » d'une carte ouvre
  /// directement un niveau pour celle-ci.
  void _ouvrirFormulaire(BuildContext context,
      {Niveau? niveau, Specialite? specialite}) {
    final m = Magasin.instance;
    var specialiteId =
        niveau?.specialiteId ?? specialite?.id ?? m.specialites.first.id;
    var palier = niveau?.palier ?? Palier.bts1;
    String? erreur;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, majEtat) => DialogueFormulaire(
          titre: niveau == null ? 'Ouvrir un niveau' : 'Modifier le niveau',
          champs: [
            SelecteurCherchable<String>(
              etiquette: 'Spécialité',
              valeur: specialiteId,
              options: [
                for (final s in m.specialites)
                  OptionSelecteur(
                    valeur: s.id,
                    libelle: s.intitule,
                    detail: s.abreviation,
                  ),
              ],
              onChange: (v) => majEtat(() {
                specialiteId = v;
                erreur = null;
              }),
            ),
            SelecteurCherchable<Palier>(
              etiquette: 'Niveau',
              valeur: palier,
              options: [
                for (final p in Palier.values)
                  OptionSelecteur(
                    valeur: p,
                    libelle: p.libelleComplet,
                    // Signale les paliers indisponibles avant la validation.
                    detail: m.niveauExiste(specialiteId, p, saufId: niveau?.id)
                        ? 'Déjà ouvert pour cette spécialité'
                        : 'Rang ${p.rang}',
                  ),
              ],
              onChange: (v) => majEtat(() {
                palier = v;
                erreur = null;
              }),
            ),
            if (erreur != null)
              Text(
                erreur!,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.danger,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
          onEnregistrer: () async {
            // Un même palier ne peut être ouvert deux fois pour une spécialité.
            if (m.niveauExiste(specialiteId, palier, saufId: niveau?.id)) {
              majEtat(() => erreur =
                  '${palier.abreviation} est déjà ouvert pour cette spécialité.');
              return;
            }
            final ok = await executer(
              c,
              () => niveau == null
                  ? m.ajouterNiveau(specialiteId, palier)
                  : m.majNiveau(niveau, specialiteId, palier),
            );
            if (ok && c.mounted) Navigator.pop(c);
          },
        ),
      ),
    );
  }
}

/// Une spécialité et les paliers qu'elle a ouverts.
///
/// Le nom de la spécialité sert de titre de section, posé au-dessus de la
/// carte : sans cette rupture, toutes les cartes se ressemblent et l'œil ne
/// voit plus où finit une filière et où commence la suivante.
class _CarteSpecialite extends StatelessWidget {
  final Specialite specialite;
  final List<Niveau> niveaux;
  final VoidCallback onOuvrir;
  final ValueChanged<Niveau> onModifier;
  final ValueChanged<Niveau> onSupprimer;

  const _CarteSpecialite({
    required this.specialite,
    required this.niveaux,
    required this.onOuvrir,
    required this.onModifier,
    required this.onSupprimer,
  });

  @override
  Widget build(BuildContext context) {
    final m = Magasin.instance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Titre de section, hors de la carte.
        Padding(
          padding: const EdgeInsets.only(bottom: Espace.sm, left: Espace.xs),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.rouge,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: Espace.md),
              Text(
                specialite.intitule,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: AppColors.texte,
                ),
              ),
              const SizedBox(width: Espace.sm),
              Text(
                specialite.abreviation,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.texteFaible,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onOuvrir,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Ajouter'),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(rayon),
            border: Border.all(color: AppColors.bordure),
          ),
          clipBehavior: Clip.antiAlias,
          child: niveaux.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: Espace.xl),
                  child: Center(
                    child: Text('Aucun niveau ouvert.',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < niveaux.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _LigneNiveau(
                        niveau: niveaux[i],
                        nbMatieres: m.nbMatieresNiveau(niveaux[i].id),
                        effectif: m.effectifNiveau(niveaux[i].id),
                        onModifier: () => onModifier(niveaux[i]),
                        onSupprimer: () => onSupprimer(niveaux[i]),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _LigneNiveau extends StatefulWidget {
  final Niveau niveau;
  final int nbMatieres;
  final int effectif;
  final VoidCallback onModifier;
  final VoidCallback onSupprimer;

  const _LigneNiveau({
    required this.niveau,
    required this.nbMatieres,
    required this.effectif,
    required this.onModifier,
    required this.onSupprimer,
  });

  @override
  State<_LigneNiveau> createState() => _LigneNiveauState();
}

class _LigneNiveauState extends State<_LigneNiveau> {
  bool _survol = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.niveau;

    return MouseRegion(
      onEnter: (_) => setState(() => _survol = true),
      onExit: (_) => setState(() => _survol = false),
      child: Container(
        color: _survol ? AppColors.survol : Colors.transparent,
        padding: const EdgeInsets.symmetric(
            horizontal: Espace.lg, vertical: Espace.md),
        child: Row(
          children: [
            // Le palier porte l'information principale de la ligne.
            SizedBox(
              width: 96,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Pastille.bleue(n.palier.abreviation),
              ),
            ),
            Expanded(
              child: Text(
                n.palier.libelle,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontFamily: 'Inter',
                  color: AppColors.texteDoux,
                ),
              ),
            ),
            _Compteur(
              icone: Icons.menu_book_outlined,
              valeur: widget.nbMatieres,
              infobulle: 'matière(s)',
            ),
            const SizedBox(width: Espace.lg),
            _Compteur(
              icone: Icons.groups_outlined,
              valeur: widget.effectif,
              infobulle: 'étudiant(s)',
            ),
            const SizedBox(width: Espace.lg),
            ActionsLigne(
              onModifier: widget.onModifier,
              onSupprimer: widget.onSupprimer,
            ),
          ],
        ),
      ),
    );
  }
}

/// Petit compteur icône + nombre, aligné en fin de ligne.
class _Compteur extends StatelessWidget {
  final IconData icone;
  final int valeur;
  final String infobulle;

  const _Compteur({
    required this.icone,
    required this.valeur,
    required this.infobulle,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$valeur $infobulle',
      child: SizedBox(
        width: 52,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(icone, size: 15, color: AppColors.texteFaible),
            const SizedBox(width: Espace.xs + 2),
            Text(
              '$valeur',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
                color: valeur == 0 ? AppColors.texteFaible : AppColors.texte,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AucuneSpecialite extends StatelessWidget {
  const _AucuneSpecialite();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(rayon),
        border: Border.all(color: AppColors.bordure),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.workspaces_outlined,
                size: 32, color: AppColors.texteFaible),
            const SizedBox(height: Espace.md),
            Text('Créez d\'abord une spécialité',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Espace.xs),
            Text('Chaque niveau est ouvert pour une spécialité donnée.',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
