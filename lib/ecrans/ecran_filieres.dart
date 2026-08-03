import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/magasin.dart';
import '../data/modeles.dart';
import '../widgets/communs.dart';

class EcranFilieres extends StatefulWidget {
  const EcranFilieres({super.key});

  @override
  State<EcranFilieres> createState() => _EcranFilieresState();
}

class _EcranFilieresState extends State<EcranFilieres> {
  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final m = Magasin.instance;
    return AnimatedBuilder(
      animation: m,
      builder: (context, _) {
        final liste = m.filieres
            .where((f) =>
                f.intitule.toLowerCase().contains(_recherche.toLowerCase()) ||
                f.code.toLowerCase().contains(_recherche.toLowerCase()))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EnTetePage(
              titre: 'Filières',
              sousTitre:
                  'Grands domaines de formation regroupant les spécialités.',
              actions: [
                FilledButton.icon(
                  onPressed: () => _ouvrirFormulaire(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nouvelle filière'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Espace.xxl, 0, Espace.xxl, Espace.lg),
              child: Row(
                children: [
                  ChampRecherche(
                    indice: 'Rechercher une filière…',
                    onChange: (v) => setState(() => _recherche = v),
                  ),
                  const Spacer(),
                  Text('${liste.length} filière(s)',
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
                    'Code',
                    'Intitulé',
                    'Spécialités',
                    'Effectif',
                    ''
                  ],
                  flex: const [1, 3.4, 1.2, 1, 1],
                  messageVide: 'Aucune filière. Créez-en une pour commencer.',
                  lignes: [
                    for (final f in liste)
                      LigneTableau(
                        flex: const [1, 3.4, 1.2, 1, 1],
                        cellules: [
                          Pastille.bleue(f.code),
                          cellule(f.intitule, gras: true),
                          cellule('${m.specialitesDe(f.id).length}'),
                          cellule(
                            '${m.specialitesDe(f.id).fold<int>(0, (t, s) => t + m.effectifSpecialite(s.id))}',
                          ),
                          ActionsLigne(
                            onModifier: () =>
                                _ouvrirFormulaire(context, filiere: f),
                            onSupprimer: () => _supprimer(context, f),
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

  Future<void> _supprimer(BuildContext context, Filiere f) async {
    final m = Magasin.instance;
    final nb = m.specialitesDe(f.id).length;
    final ok = await confirmerSuppression(
      context,
      titre: 'Supprimer la filière ?',
      message: nb > 0
          ? '« ${f.intitule} » contient $nb spécialité(s). '
              'Elles perdront leur rattachement.'
          : '« ${f.intitule} » sera définitivement supprimée.',
    );
    if (ok) m.supprimerFiliere(f.id);
  }

  void _ouvrirFormulaire(BuildContext context, {Filiere? filiere}) {
    final code = TextEditingController(text: filiere?.code ?? '');
    final intitule = TextEditingController(text: filiere?.intitule ?? '');

    showDialog(
      context: context,
      builder: (c) => DialogueFormulaire(
        titre: filiere == null ? 'Nouvelle filière' : 'Modifier la filière',
        champs: [
          TextField(
            controller: code,
            decoration: const InputDecoration(
              labelText: 'Code',
              hintText: 'GI',
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          TextField(
            controller: intitule,
            decoration: const InputDecoration(
              labelText: 'Intitulé',
              hintText: 'Génie Informatique',
            ),
          ),
        ],
        onEnregistrer: () {
          if (code.text.trim().isEmpty || intitule.text.trim().isEmpty) return;
          final m = Magasin.instance;
          if (filiere == null) {
            m.ajouterFiliere(code.text.trim(), intitule.text.trim());
          } else {
            m.majFiliere(filiere, code.text.trim(), intitule.text.trim());
          }
          Navigator.pop(c);
        },
      ),
    );
  }
}
