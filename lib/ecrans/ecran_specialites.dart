import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/magasin.dart';
import '../data/modeles.dart';
import '../widgets/communs.dart';

class EcranSpecialites extends StatefulWidget {
  const EcranSpecialites({super.key});

  @override
  State<EcranSpecialites> createState() => _EcranSpecialitesState();
}

class _EcranSpecialitesState extends State<EcranSpecialites> {
  static const _flex = <double>[1, 2.8, 2, 1.6, 1, 1];

  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final m = Magasin.instance;
    return AnimatedBuilder(
      animation: m,
      builder: (context, _) {
        final liste = m.specialites.where((s) {
          final texte =
              '${s.abreviation} ${s.intitule} ${s.responsable}'.toLowerCase();
          return texte.contains(_recherche.toLowerCase());
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EnTetePage(
              titre: 'Spécialités',
              sousTitre:
                  'Parcours de formation proposés par l\'établissement, avec leur responsable.',
              actions: [
                FilledButton.icon(
                  onPressed: () => _ouvrirFormulaire(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nouvelle spécialité'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Espace.xxl, 0, Espace.xxl, Espace.lg),
              child: Row(
                children: [
                  ChampRecherche(
                    indice: 'Rechercher une spécialité…',
                    onChange: (v) => setState(() => _recherche = v),
                  ),
                  const Spacer(),
                  Text('${liste.length} spécialité(s)',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    Espace.xxl, 0, Espace.xxl, Espace.xxl),
                child: Tableau(
                  colonnes: const [
                    'Abrév.',
                    'Intitulé',
                    'Responsable',
                    'Niveaux ouverts',
                    'Matières',
                    ''
                  ],
                  flex: _flex,
                  messageVide: 'Aucune spécialité ne correspond.',
                  lignes: [
                    for (final s in liste)
                      LigneTableau(
                        flex: _flex,
                        cellules: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Pastille.rouge(s.abreviation),
                          ),
                          cellule(s.intitule, gras: true),
                          cellule(s.responsable,
                              couleur: AppColors.texteDoux),
                          _Paliers(niveaux: m.niveauxDe(s.id)),
                          cellule('${m.nbMatieresSpecialite(s.id)}'),
                          ActionsLigne(
                            onModifier: () =>
                                _ouvrirFormulaire(context, specialite: s),
                            onSupprimer: () => _supprimer(context, s),
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

  Future<void> _supprimer(BuildContext context, Specialite s) async {
    final m = Magasin.instance;
    final nb = m.effectifSpecialite(s.id);
    final nbNiveaux = m.niveauxDe(s.id).length;

    final ok = await confirmerSuppression(
      context,
      titre: 'Supprimer la spécialité ?',
      message: nb > 0 || nbNiveaux > 0
          ? '« ${s.intitule} » sera supprimée, ainsi que ses $nbNiveaux niveau(x) et ses $nb étudiant(s).'
          : '« ${s.intitule} » sera définitivement supprimée.',
    );
    if (ok && context.mounted) {
      await executer(context, () => m.supprimerSpecialite(s.id));
    }
  }

  void _ouvrirFormulaire(BuildContext context, {Specialite? specialite}) {
    final m = Magasin.instance;
    final abreviation =
        TextEditingController(text: specialite?.abreviation ?? '');
    final intitule = TextEditingController(text: specialite?.intitule ?? '');
    final responsable =
        TextEditingController(text: specialite?.responsable ?? '');

    showDialog(
      context: context,
      builder: (c) => DialogueFormulaire(
        titre: specialite == null
            ? 'Nouvelle spécialité'
            : 'Modifier la spécialité',
        champs: [
          TextField(
            controller: abreviation,
            decoration: const InputDecoration(
                labelText: 'Abréviation', hintText: 'GL'),
            textCapitalization: TextCapitalization.characters,
          ),
          TextField(
            controller: intitule,
            decoration: const InputDecoration(
                labelText: 'Intitulé', hintText: 'Génie Logiciel'),
          ),
          TextField(
            controller: responsable,
            decoration: const InputDecoration(
              labelText: 'Responsable de la spécialité',
              hintText: 'M. KUIMO',
            ),
          ),
        ],
        onEnregistrer: () async {
          if (abreviation.text.trim().isEmpty ||
              intitule.text.trim().isEmpty) {
            return;
          }
          final ok = await executer(
            c,
            () => specialite == null
                ? m.ajouterSpecialite(abreviation.text.trim(),
                    intitule.text.trim(), responsable.text.trim())
                : m.majSpecialite(specialite, abreviation.text.trim(),
                    intitule.text.trim(), responsable.text.trim()),
          );
          if (ok && c.mounted) Navigator.pop(c);
        },
      ),
    );
  }
}

/// Paliers ouverts pour une spécialité, sous forme de pastilles.
class _Paliers extends StatelessWidget {
  final List<Niveau> niveaux;
  const _Paliers({required this.niveaux});

  @override
  Widget build(BuildContext context) {
    if (niveaux.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Pastille.neutre('Aucun'),
      );
    }
    return Wrap(
      spacing: Espace.xs,
      runSpacing: Espace.xs,
      children: [
        for (final n in niveaux) Pastille.bleue(n.palier.abreviation),
      ],
    );
  }
}
