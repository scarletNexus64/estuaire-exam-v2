import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/magasin.dart';
import '../data/modeles.dart';
import '../widgets/communs.dart';

class EcranNiveaux extends StatefulWidget {
  const EcranNiveaux({super.key});

  @override
  State<EcranNiveaux> createState() => _EcranNiveauxState();
}

class _EcranNiveauxState extends State<EcranNiveaux> {
  @override
  Widget build(BuildContext context) {
    final m = Magasin.instance;
    return AnimatedBuilder(
      animation: m,
      builder: (context, _) {
        final liste = m.niveauxTries;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EnTetePage(
              titre: 'Niveaux',
              sousTitre:
                  'Années d\'étude, ordonnées par rang. Le rang détermine la progression lors des migrations.',
              actions: [
                FilledButton.icon(
                  onPressed: () => _ouvrirFormulaire(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nouveau niveau'),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    Espace.xxl, 0, Espace.xxl, Espace.xxl),
                child: Tableau(
                  colonnes: const [
                    'Rang',
                    'Code',
                    'Intitulé',
                    'Effectif',
                    'Niveau suivant',
                    ''
                  ],
                  flex: const [0.8, 1, 2.6, 1, 1.8, 1],
                  messageVide: 'Aucun niveau défini.',
                  lignes: [
                    for (final n in liste)
                      LigneTableau(
                        flex: const [0.8, 1, 2.6, 1, 1.8, 1],
                        cellules: [
                          cellule('${n.rang}', gras: true),
                          Pastille.bleue(n.code),
                          cellule(n.intitule, gras: true),
                          cellule('${m.effectifNiveau(n.id)}'),
                          m.niveauSuivant(n.id) == null
                              ? Pastille.neutre('Dernier niveau')
                              : cellule(m.niveauSuivant(n.id)!.intitule,
                                  couleur: AppColors.texteDoux),
                          ActionsLigne(
                            onModifier: () =>
                                _ouvrirFormulaire(context, niveau: n),
                            onSupprimer: () => _supprimer(context, n),
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

  Future<void> _supprimer(BuildContext context, Niveau n) async {
    final m = Magasin.instance;
    final nb = m.effectifNiveau(n.id);
    final ok = await confirmerSuppression(
      context,
      titre: 'Supprimer le niveau ?',
      message: nb > 0
          ? '« ${n.intitule} » compte $nb étudiant(s) inscrit(s).'
          : '« ${n.intitule} » sera définitivement supprimé.',
    );
    if (ok) m.supprimerNiveau(n.id);
  }

  void _ouvrirFormulaire(BuildContext context, {Niveau? niveau}) {
    final m = Magasin.instance;
    final code = TextEditingController(text: niveau?.code ?? '');
    final intitule = TextEditingController(text: niveau?.intitule ?? '');
    final rang = TextEditingController(
        text: '${niveau?.rang ?? (m.niveaux.length + 1)}');

    showDialog(
      context: context,
      builder: (c) => DialogueFormulaire(
        titre: niveau == null ? 'Nouveau niveau' : 'Modifier le niveau',
        champs: [
          TextField(
            controller: code,
            decoration: const InputDecoration(
                labelText: 'Code', hintText: 'BTS1'),
            textCapitalization: TextCapitalization.characters,
          ),
          TextField(
            controller: intitule,
            decoration: const InputDecoration(
                labelText: 'Intitulé', hintText: 'BTS 1'),
          ),
          TextField(
            controller: rang,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Rang',
              hintText: '1',
              helperText:
                  'Ordre de progression : 1 précède 2, qui précède 3.',
            ),
          ),
        ],
        onEnregistrer: () {
          final r = int.tryParse(rang.text.trim());
          if (code.text.trim().isEmpty ||
              intitule.text.trim().isEmpty ||
              r == null) {
            return;
          }
          if (niveau == null) {
            m.ajouterNiveau(code.text.trim(), intitule.text.trim(), r);
          } else {
            m.majNiveau(niveau, code.text.trim(), intitule.text.trim(), r);
          }
          Navigator.pop(c);
        },
      ),
    );
  }
}
