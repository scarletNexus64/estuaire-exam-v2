import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/modeles.dart';
import '../data/session.dart';
import '../widgets/communs.dart';

/// Gestion des accès : comptes administrateurs et enseignants.
class EcranComptes extends StatefulWidget {
  const EcranComptes({super.key});

  @override
  State<EcranComptes> createState() => _EcranComptesState();
}

class _EcranComptesState extends State<EcranComptes> {
  static const _flex = <double>[1.8, 2.4, 1.8, 1.2, 1];

  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    return AnimatedBuilder(
      animation: s,
      builder: (context, _) {
        final liste = s.comptes.where((c) {
          final texte = '${c.identifiant} ${c.nomComplet}'.toLowerCase();
          return texte.contains(_recherche.toLowerCase());
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EnTetePage(
              titre: 'Comptes',
              sousTitre:
                  'Accès à la plateforme. Les administrateurs gèrent la configuration, les enseignants saisissent les notes.',
              actions: [
                FilledButton.icon(
                  onPressed: () => _ouvrirFormulaire(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nouveau compte'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Espace.xxl, 0, Espace.xxl, Espace.lg),
              child: Row(
                children: [
                  ChampRecherche(
                    indice: 'Rechercher un compte…',
                    onChange: (v) => setState(() => _recherche = v),
                  ),
                  const Spacer(),
                  Text('${liste.length} compte(s)',
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
                    'Identifiant',
                    'Nom complet',
                    'Rôle',
                    'État',
                    ''
                  ],
                  flex: _flex,
                  messageVide: 'Aucun compte ne correspond.',
                  lignes: [
                    for (final c in liste)
                      LigneTableau(
                        flex: _flex,
                        cellules: [
                          Row(
                            children: [
                              cellule(c.identifiant,
                                  couleur: AppColors.bleuSombre, gras: true),
                              if (c.id == s.courant?.id) ...[
                                const SizedBox(width: Espace.sm),
                                Pastille.neutre('vous'),
                              ],
                            ],
                          ),
                          cellule(c.nomComplet),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: c.role == Role.superAdmin
                                ? Pastille.rouge('Administrateur')
                                : Pastille.bleue('Enseignant'),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: c.actif
                                ? Pastille.succes('Actif')
                                : Pastille.neutre('Désactivé'),
                          ),
                          ActionsLigne(
                            onModifier: () =>
                                _ouvrirFormulaire(context, compte: c),
                            onSupprimer: () => _supprimer(context, c),
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

  void _refuser(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _supprimer(BuildContext context, Utilisateur c) async {
    final s = Session.instance;

    if (c.id == s.courant?.id) {
      _refuser(context, 'Vous ne pouvez pas supprimer votre propre compte.');
      return;
    }
    // Sans ce garde-fou, on peut se retrouver sans aucun accès administrateur.
    if (c.role == Role.superAdmin && c.actif && s.nbAdminsActifs <= 1) {
      _refuser(context, 'Il doit rester au moins un administrateur actif.');
      return;
    }

    final ok = await confirmerSuppression(
      context,
      titre: 'Supprimer le compte ?',
      message: '${c.nomComplet} (${c.identifiant}) perdra tout accès.',
    );
    if (ok && context.mounted) {
      await executer(context, () => s.supprimerCompte(c.id));
    }
  }

  void _ouvrirFormulaire(BuildContext context, {Utilisateur? compte}) {
    final s = Session.instance;
    final identifiant = TextEditingController(text: compte?.identifiant ?? '');
    final nom = TextEditingController(text: compte?.nomComplet ?? '');
    final motDePasse = TextEditingController();
    var role = compte?.role ?? Role.enseignant;
    var actif = compte?.actif ?? true;
    String? erreur;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, majEtat) => DialogueFormulaire(
          titre: compte == null ? 'Nouveau compte' : 'Modifier le compte',
          largeur: 520,
          champs: [
            TextField(
              controller: identifiant,
              decoration: const InputDecoration(
                labelText: 'Identifiant',
                hintText: 'kuimo',
                helperText: 'Sert à se connecter. Sans espace.',
              ),
            ),
            TextField(
              controller: nom,
              decoration: const InputDecoration(
                labelText: 'Nom complet',
                hintText: 'Marc Kuimo',
              ),
            ),
            TextField(
              controller: motDePasse,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                helperText: compte == null
                    ? '4 caractères minimum.'
                    : 'Laisser vide pour conserver l\'actuel.',
              ),
            ),
            DropdownButtonFormField<Role>(
              initialValue: role,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Rôle'),
              style: const TextStyle(
                  fontSize: 13.5, color: AppColors.texte, fontFamily: 'Inter'),
              items: const [
                DropdownMenuItem(
                    value: Role.superAdmin,
                    child: Text('Super administrateur')),
                DropdownMenuItem(
                    value: Role.enseignant, child: Text('Enseignant')),
              ],
              onChanged: (v) => majEtat(() => role = v!),
            ),
            if (compte != null)
              SwitchListTile(
                value: actif,
                onChanged: (v) => majEtat(() => actif = v),
                title: const Text('Compte actif',
                    style: TextStyle(fontSize: 13.5, fontFamily: 'Inter')),
                subtitle: Text(
                  actif
                      ? 'Peut se connecter à la plateforme.'
                      : 'La connexion est refusée.',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.texteDoux,
                      fontFamily: 'Inter'),
                ),
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.succes,
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
            final id = identifiant.text.trim();
            final mdp = motDePasse.text;

            if (id.isEmpty || nom.text.trim().isEmpty) {
              majEtat(() => erreur = 'Identifiant et nom sont obligatoires.');
              return;
            }
            if (id.contains(' ')) {
              majEtat(() =>
                  erreur = 'L\'identifiant ne doit pas contenir d\'espace.');
              return;
            }
            if (s.identifiantPris(id, saufId: compte?.id)) {
              majEtat(() => erreur = 'Cet identifiant est déjà utilisé.');
              return;
            }
            if (compte == null && mdp.length < 4) {
              majEtat(() =>
                  erreur = 'Le mot de passe doit faire au moins 4 caractères.');
              return;
            }
            if (compte != null && mdp.isNotEmpty && mdp.length < 4) {
              majEtat(() =>
                  erreur = 'Le mot de passe doit faire au moins 4 caractères.');
              return;
            }
            // Ne pas se retirer soi-même le dernier accès administrateur.
            final perdAdmin = compte != null &&
                compte.role == Role.superAdmin &&
                compte.actif &&
                (role != Role.superAdmin || !actif);
            if (perdAdmin && s.nbAdminsActifs <= 1) {
              majEtat(() =>
                  erreur = 'Il doit rester au moins un administrateur actif.');
              return;
            }

            final ok = await executer(
              c,
              () => compte == null
                  ? s.ajouterCompte(id, mdp, nom.text, role)
                  : s.majCompte(compte, id, nom.text, role, actif,
                      motDePasse: mdp),
            );
            if (ok && c.mounted) Navigator.pop(c);
          },
        ),
      ),
    );
  }
}
