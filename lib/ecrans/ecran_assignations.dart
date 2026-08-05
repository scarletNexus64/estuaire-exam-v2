import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/magasin.dart';
import '../data/modeles.dart';
import '../data/session.dart';
import '../widgets/communs.dart';

/// Assignation : quelles matières sont confiées à quel enseignant.
class EcranAssignations extends StatefulWidget {
  const EcranAssignations({super.key});

  @override
  State<EcranAssignations> createState() => _EcranAssignationsState();
}

class _EcranAssignationsState extends State<EcranAssignations> {
  static const _flex = <double>[2.2, 1.6, 3.2, 1];

  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    final m = Magasin.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([s, m]),
      builder: (context, _) {
        final liste = s.enseignants.where((e) {
          final texte = '${e.identifiant} ${e.nomComplet}'.toLowerCase();
          return texte.contains(_recherche.toLowerCase());
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EnTetePage(
              titre: 'Assignations',
              sousTitre:
                  'Matières confiées à chaque enseignant. Une même matière peut être partagée entre plusieurs enseignants.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Espace.xxl, 0, Espace.xxl, Espace.lg),
              child: Row(
                children: [
                  ChampRecherche(
                    indice: 'Rechercher un enseignant…',
                    onChange: (v) => setState(() => _recherche = v),
                  ),
                  const Spacer(),
                  Text('${liste.length} enseignant(s)',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    Espace.xxl, 0, Espace.xxl, Espace.xxl),
                child: s.enseignants.isEmpty
                    ? const _AucunEnseignant()
                    : m.matieres.isEmpty
                        ? const _AucuneMatiere()
                        : Tableau(
                            colonnes: const [
                              'Enseignant',
                              'Identifiant',
                              'Matières confiées',
                              ''
                            ],
                            flex: _flex,
                            messageVide: 'Aucun enseignant ne correspond.',
                            lignes: [
                              for (final e in liste)
                                LigneTableau(
                                  flex: _flex,
                                  cellules: [
                                    cellule(e.nomComplet, gras: true),
                                    cellule(e.identifiant,
                                        couleur: AppColors.bleuSombre),
                                    _Matieres(enseignant: e),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            _ouvrirAssignation(context, e),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: Espace.md,
                                            vertical: Espace.sm,
                                          ),
                                        ),
                                        child: const Text('Assigner'),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _ouvrirAssignation(
      BuildContext context, Utilisateur enseignant) async {
    final choix = await showDialog<Set<String>>(
      context: context,
      builder: (c) => _DialogueAssignation(enseignant: enseignant),
    );
    if (choix == null || !context.mounted) return;

    await executer(
      context,
      () => Session.instance.definirAffectations(enseignant, choix),
      succes: '${choix.length} matière(s) confiée(s) à ${enseignant.nomComplet}.',
    );
  }
}

/// Matières d'un enseignant, en pastilles.
class _Matieres extends StatelessWidget {
  final Utilisateur enseignant;
  const _Matieres({required this.enseignant});

  @override
  Widget build(BuildContext context) {
    final m = Magasin.instance;
    final siennes =
        m.matieres.where((x) => enseignant.matiereIds.contains(x.id)).toList();

    if (siennes.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Pastille.neutre('Aucune'),
      );
    }
    return Wrap(
      spacing: Espace.xs,
      runSpacing: Espace.xs,
      children: [
        for (final x in siennes)
          Builder(builder: (context) {
            final partagee =
                Session.instance.enseignantsDe(x.id).length > 1;
            return Tooltip(
              message: partagee
                  ? '${x.intitule}\n${m.nomNiveau(x.niveauId)}\nPartagée avec un autre enseignant'
                  : '${x.intitule}\n${m.nomNiveau(x.niveauId)}',
              child: partagee
                  // Teinte distincte : on voit d'un coup d'œil ce qui est
                  // partagé sans ouvrir chaque infobulle.
                  ? Pastille(
                      texte: '${x.code} ⇄',
                      couleur: AppColors.alerte,
                      fond: AppColors.alertePale,
                    )
                  : Pastille.bleue(x.code),
            );
          }),
      ],
    );
  }
}

/// Sélection multiple des matières, groupées par promotion.
class _DialogueAssignation extends StatefulWidget {
  final Utilisateur enseignant;
  const _DialogueAssignation({required this.enseignant});

  @override
  State<_DialogueAssignation> createState() => _DialogueAssignationState();
}

class _DialogueAssignationState extends State<_DialogueAssignation> {
  late final Set<String> _choix = {...widget.enseignant.matiereIds};
  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final m = Magasin.instance;

    final requete = _recherche.trim().toLowerCase();

    // Groupement par promotion : une matière isolée de son niveau est ambiguë.
    final parNiveau = <String, List<Matiere>>{};
    for (final mat in m.matieres) {
      // Sans recherche, on s'en tient aux matières déjà confiées : après
      // un import INSAM le campus en compte plusieurs milliers, et les
      // afficher toutes figerait la fenêtre à l'ouverture.
      if (requete.isEmpty) {
        if (!_choix.contains(mat.id)) continue;
      } else {
        final texte =
            '${mat.code} ${mat.intitule} ${m.nomNiveau(mat.niveauId)}'
                .toLowerCase();
        if (!texte.contains(requete)) continue;
      }
      parNiveau.putIfAbsent(mat.niveauId, () => []).add(mat);
    }

    final niveauxAffiches = m.niveauxTries
        .where((n) => parNiveau.containsKey(n.id))
        .toList();

    final total = parNiveau.values.fold(0, (t, l) => t + l.length);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Espace.xl, Espace.xl, Espace.xl, Espace.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Matières de ${widget.enseignant.nomComplet}',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    requete.isEmpty
                        ? '${_choix.length} matière(s) confiée(s). '
                            'Recherchez pour en ajouter.'
                        : '${_choix.length} sélectionnée(s) · '
                            '$total résultat(s)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Espace.xl, Espace.md, Espace.xl, Espace.md),
              child: TextField(
                onChanged: (v) => setState(() => _recherche = v),
                decoration: const InputDecoration(
                  hintText: 'Rechercher une matière…',
                  prefixIcon: Icon(Icons.search,
                      size: 18, color: AppColors.texteFaible),
                  prefixIconConstraints:
                      BoxConstraints(minWidth: 38, minHeight: 38),
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: niveauxAffiches.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(Espace.xxl),
                      child: Center(
                        child: Text(
                          requete.isEmpty
                              ? 'Recherchez une matière par son code, son '
                                  'intitulé ou sa promotion pour l\'ajouter.'
                              : 'Aucune matière ne correspond.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(vertical: Espace.sm),
                      children: [
                        for (final n in niveauxAffiches) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                                Espace.xl, Espace.md, Espace.xl, Espace.xs),
                            child: Text(m.nomNiveau(n.id),
                                style:
                                    Theme.of(context).textTheme.labelSmall),
                          ),
                          for (final mat in parNiveau[n.id]!)
                            _LigneMatiere(
                              matiere: mat,
                              choisie: _choix.contains(mat.id),
                              // Autres enseignants déjà sur cette matière :
                              // le partage est permis, autant le montrer.
                              autres: Session.instance
                                  .enseignantsDe(mat.id)
                                  .where((u) => u.id != widget.enseignant.id)
                                  .map((u) => u.nomComplet)
                                  .toList(),
                              onBasculer: () => setState(() {
                                _choix.contains(mat.id)
                                    ? _choix.remove(mat.id)
                                    : _choix.add(mat.id);
                              }),
                            ),
                        ],
                      ],
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(Espace.lg),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _choix.isEmpty
                        ? null
                        : () => setState(_choix.clear),
                    child: const Text('Tout retirer'),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: Espace.sm),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _choix),
                    child: const Text('Enregistrer'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LigneMatiere extends StatelessWidget {
  final Matiere matiere;
  final bool choisie;
  final List<String> autres;
  final VoidCallback onBasculer;

  const _LigneMatiere({
    required this.matiere,
    required this.choisie,
    required this.autres,
    required this.onBasculer,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onBasculer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Espace.lg, vertical: Espace.xs),
        child: Row(
          children: [
            Checkbox(
              value: choisie,
              onChanged: (_) => onBasculer(),
              activeColor: AppColors.bleu,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: Espace.sm),
            SizedBox(
              width: 90,
              child: cellule(matiere.code,
                  couleur: AppColors.bleuSombre, gras: true),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  cellule(matiere.intitule),
                  if (autres.isNotEmpty)
                    Text(
                      'Aussi confiée à ${autres.join(', ')}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontFamily: 'Inter',
                        color: AppColors.texteFaible,
                      ),
                    ),
                ],
              ),
            ),
            Pastille.neutre('S${matiere.semestre}'),
          ],
        ),
      ),
    );
  }
}

class _AucunEnseignant extends StatelessWidget {
  const _AucunEnseignant();

  @override
  Widget build(BuildContext context) => _Vide(
        icone: Icons.person_add_alt_outlined,
        titre: 'Aucun enseignant',
        message:
            'Créez d\'abord un compte enseignant depuis la rubrique « Comptes ».',
      );
}

class _AucuneMatiere extends StatelessWidget {
  const _AucuneMatiere();

  @override
  Widget build(BuildContext context) => _Vide(
        icone: Icons.menu_book_outlined,
        titre: 'Aucune matière',
        message: 'Créez d\'abord des matières pour pouvoir les confier.',
      );
}

class _Vide extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String message;

  const _Vide({
    required this.icone,
    required this.titre,
    required this.message,
  });

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
            Icon(icone, size: 32, color: AppColors.texteFaible),
            const SizedBox(height: Espace.md),
            Text(titre, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Espace.xs),
            Text(message, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
