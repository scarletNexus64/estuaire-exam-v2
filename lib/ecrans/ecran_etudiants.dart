import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/magasin.dart';
import '../data/modeles.dart';
import '../widgets/communs.dart';

/// Registre des étudiants, présenté par promotion.
/// On choisit une carte « Spécialité — Niveau », puis on gère sa liste.
class EcranEtudiants extends StatefulWidget {
  const EcranEtudiants({super.key});

  @override
  State<EcranEtudiants> createState() => _EcranEtudiantsState();
}

class _EcranEtudiantsState extends State<EcranEtudiants> {
  /// Promotion ouverte ; null = grille des promotions.
  String? _niveauId;

  @override
  Widget build(BuildContext context) {
    final m = Magasin.instance;
    return AnimatedBuilder(
      animation: m,
      builder: (context, _) {
        // La promotion a pu être supprimée entre-temps.
        final niveau = _niveauId == null ? null : m.niveau(_niveauId!);
        if (niveau == null) return _GrillePromotions(onOuvrir: _ouvrir);
        return _ListePromotion(
          niveau: niveau,
          onRetour: () => setState(() => _niveauId = null),
        );
      },
    );
  }

  void _ouvrir(String niveauId) => setState(() => _niveauId = niveauId);
}

// ---------- Grille des promotions ----------

class _GrillePromotions extends StatefulWidget {
  final ValueChanged<String> onOuvrir;
  const _GrillePromotions({required this.onOuvrir});

  @override
  State<_GrillePromotions> createState() => _GrillePromotionsState();
}

class _GrillePromotionsState extends State<_GrillePromotions> {
  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final m = Magasin.instance;
    final onOuvrir = widget.onOuvrir;
    final q = _recherche.trim().toLowerCase();

    // La recherche porte aussi sur les noms : après un import INSAM on
    // cherche souvent un étudiant sans savoir dans quelle promotion il
    // est inscrit.
    final promotions = q.isEmpty
        ? m.niveauxTries
        : m.niveauxTries.where((n) {
            final specialite = m.nomSpecialite(n.specialiteId).toLowerCase();
            if (specialite.contains(q) ||
                n.palier.abreviation.toLowerCase().contains(q)) {
              return true;
            }
            return m.etudiantsDe(n.id).any((e) =>
                e.nomComplet.toLowerCase().contains(q) ||
                e.matricule.toLowerCase().contains(q));
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EnTetePage(
          titre: 'Étudiants',
          sousTitre:
              'Choisissez une promotion pour consulter et modifier sa liste d\'étudiants.',
        ),
        if (m.niveauxTries.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Espace.xxl, 0, Espace.xxl, Espace.lg),
            child: Row(
              children: [
                ChampRecherche(
                  indice: 'Promotion, nom ou matricule…',
                  largeur: 340,
                  onChange: (v) => setState(() => _recherche = v),
                ),
                const SizedBox(width: Espace.lg),
                Text(
                  '${promotions.length} promotion(s)'
                  '${q.isEmpty ? '' : ' sur ${m.niveauxTries.length}'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        Expanded(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(Espace.xxl, 0, Espace.xxl, Espace.xxl),
            child: m.niveauxTries.isEmpty
                ? const _AucunNiveau()
                : promotions.isEmpty
                ? const Center(child: Text('Aucune promotion ne correspond.'))
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 320,
                      mainAxisExtent: 152,
                      crossAxisSpacing: Espace.lg,
                      mainAxisSpacing: Espace.lg,
                    ),
                    itemCount: promotions.length,
                    itemBuilder: (context, i) {
                      final n = promotions[i];
                      return _CartePromotion(
                        specialite: m.nomSpecialite(n.specialiteId),
                        palier: n.palier.abreviation,
                        nbEtudiants: m.etudiantsDe(n.id).length,
                        nbMatieres: m.nbMatieresNiveau(n.id),
                        onOuvrir: () => onOuvrir(n.id),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _CartePromotion extends StatefulWidget {
  final String specialite;
  final String palier;
  final int nbEtudiants;
  final int nbMatieres;
  final VoidCallback onOuvrir;

  const _CartePromotion({
    required this.specialite,
    required this.palier,
    required this.nbEtudiants,
    required this.nbMatieres,
    required this.onOuvrir,
  });

  @override
  State<_CartePromotion> createState() => _CartePromotionState();
}

class _CartePromotionState extends State<_CartePromotion> {
  bool _survol = false;

  @override
  Widget build(BuildContext context) {
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
                  Pastille.bleue(widget.palier),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: _survol ? AppColors.bleu : AppColors.texteFaible,
                  ),
                ],
              ),
              const SizedBox(height: Espace.md),
              Text(
                widget.specialite,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.groups_outlined,
                      size: 16, color: AppColors.texteFaible),
                  const SizedBox(width: Espace.xs + 2),
                  Text('${widget.nbEtudiants} étudiant(s)',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(width: Espace.md),
                  const Icon(Icons.menu_book_outlined,
                      size: 16, color: AppColors.texteFaible),
                  const SizedBox(width: Espace.xs + 2),
                  Text('${widget.nbMatieres}',
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

// ---------- Liste d'une promotion ----------

class _ListePromotion extends StatefulWidget {
  final Niveau niveau;
  final VoidCallback onRetour;

  const _ListePromotion({required this.niveau, required this.onRetour});

  @override
  State<_ListePromotion> createState() => _ListePromotionState();
}

class _ListePromotionState extends State<_ListePromotion> {
  static const _flex = <double>[1.6, 3, 0.8, 1.2, 1];

  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final m = Magasin.instance;
    final n = widget.niveau;

    final liste = m.etudiantsDe(n.id).where((e) {
      final texte = '${e.matricule} ${e.nomComplet}'.toLowerCase();
      return texte.contains(_recherche.toLowerCase());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EnTetePage(
          titre:
              '${m.nomSpecialite(n.specialiteId)} — ${n.palier.abreviation}',
          sousTitre:
              'Registre de la promotion. Le matricule sert d\'identifiant lors des épreuves.',
          actions: [
            OutlinedButton.icon(
              onPressed: widget.onRetour,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Promotions'),
            ),
            OutlinedButton.icon(
              onPressed: () => _messageBientot(context),
              icon: const Icon(Icons.file_upload_outlined, size: 18),
              label: const Text('Importer'),
            ),
            FilledButton.icon(
              onPressed: () => _ouvrirFormulaire(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nouvel étudiant'),
            ),
          ],
        ),
        Padding(
          padding:
              const EdgeInsets.fromLTRB(Espace.xxl, 0, Espace.xxl, Espace.lg),
          child: Row(
            children: [
              ChampRecherche(
                indice: 'Rechercher par nom ou matricule…',
                largeur: 300,
                onChange: (v) => setState(() => _recherche = v),
              ),
              const Spacer(),
              Text('${liste.length} étudiant(s)',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(Espace.xxl, 0, Espace.xxl, Espace.xxl),
            child: Tableau(
              colonnes: const [
                'Matricule',
                'Noms et prénoms',
                'Sexe',
                'État',
                ''
              ],
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
                      ActionsLigne(
                        onModifier: () =>
                            _ouvrirFormulaire(context, etudiant: e),
                        onSupprimer: () => _supprimer(context, e),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _messageBientot(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('L\'import de listes arrivera avec la base de données locale.'),
      ),
    );
  }

  Future<void> _supprimer(BuildContext context, Etudiant e) async {
    final ok = await confirmerSuppression(
      context,
      titre: 'Supprimer l\'étudiant ?',
      message: '${e.nomComplet} (${e.matricule}) sera retiré du registre.',
    );
    if (ok && context.mounted) {
      await executer(context, () => Magasin.instance.supprimerEtudiant(e.id));
    }
  }

  void _ouvrirFormulaire(BuildContext context, {Etudiant? etudiant}) {
    final m = Magasin.instance;
    final matricule = TextEditingController(text: etudiant?.matricule ?? '');
    final nom = TextEditingController(text: etudiant?.nomComplet ?? '');
    var sexe = etudiant?.sexe ?? Sexe.m;
    // La promotion en cours est proposée par défaut, mais reste modifiable.
    var niveauId = etudiant?.niveauId ?? widget.niveau.id;
    var actif = etudiant?.actif ?? true;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, majEtat) => DialogueFormulaire(
          titre: etudiant == null ? 'Nouvel étudiant' : 'Modifier l\'étudiant',
          largeur: 560,
          champs: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: matricule,
                    decoration: const InputDecoration(
                      labelText: 'Matricule',
                      hintText: 'IUE26TEST92',
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                const SizedBox(width: Espace.md),
                Expanded(
                  child: DropdownButtonFormField<Sexe>(
                    initialValue: sexe,
                    decoration: const InputDecoration(labelText: 'Sexe'),
                    style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.texte,
                        fontFamily: 'Inter'),
                    items: const [
                      DropdownMenuItem(value: Sexe.m, child: Text('Masculin')),
                      DropdownMenuItem(value: Sexe.f, child: Text('Féminin')),
                    ],
                    onChanged: (v) => majEtat(() => sexe = v!),
                  ),
                ),
              ],
            ),
            TextField(
              controller: nom,
              decoration: const InputDecoration(
                labelText: 'Noms et prénoms',
                hintText: 'Ange Tim',
              ),
            ),
            SelecteurCherchable<String>(
              etiquette: 'Spécialité et niveau',
              valeur: niveauId,
              options: [
                for (final p in m.niveauxTries)
                  OptionSelecteur(
                    valeur: p.id,
                    libelle: m.nomNiveau(p.id),
                    detail: p.palier.libelle,
                  ),
              ],
              onChange: (v) => majEtat(() => niveauId = v),
            ),
            if (etudiant != null)
              SwitchListTile(
                value: actif,
                onChanged: (v) => majEtat(() => actif = v),
                title: const Text('Étudiant inscrit',
                    style: TextStyle(fontSize: 13.5, fontFamily: 'Inter')),
                subtitle: Text(
                  actif
                      ? 'Peut composer les épreuves.'
                      : 'Exclu des listes d\'épreuve.',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.texteDoux,
                      fontFamily: 'Inter'),
                ),
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.succes,
              ),
          ],
          onEnregistrer: () async {
            if (matricule.text.trim().isEmpty || nom.text.trim().isEmpty) {
              return;
            }
            final ok = await executer(
              c,
              () => etudiant == null
                  ? m.ajouterEtudiant(
                      matricule.text.trim(), nom.text.trim(), sexe, niveauId)
                  : m.majEtudiant(etudiant, matricule.text.trim(),
                      nom.text.trim(), sexe, niveauId, actif),
            );
            if (ok && c.mounted) Navigator.pop(c);
          },
        ),
      ),
    );
  }
}

class _AucunNiveau extends StatelessWidget {
  const _AucunNiveau();

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
            const Icon(Icons.stairs_outlined,
                size: 32, color: AppColors.texteFaible),
            const SizedBox(height: Espace.md),
            Text('Ouvrez d\'abord un niveau',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Espace.xs),
            Text('Les étudiants sont inscrits dans une promotion.',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
