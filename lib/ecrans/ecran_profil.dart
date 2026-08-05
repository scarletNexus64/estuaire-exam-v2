import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/modeles.dart';
import '../data/session.dart';
import '../widgets/communs.dart';

/// Mon compte : identité et mot de passe de l'utilisateur connecté.
class EcranProfil extends StatefulWidget {
  const EcranProfil({super.key});

  @override
  State<EcranProfil> createState() => _EcranProfilState();
}

class _EcranProfilState extends State<EcranProfil> {
  final _nom = TextEditingController();
  final _actuel = TextEditingController();
  final _nouveau = TextEditingController();
  final _confirmation = TextEditingController();

  String? _erreurMdp;
  bool _nomCharge = false;

  @override
  void dispose() {
    _nom.dispose();
    _actuel.dispose();
    _nouveau.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    return AnimatedBuilder(
      animation: s,
      builder: (context, _) {
        final u = s.courant;
        if (u == null) return const SizedBox.shrink();

        // Amorçage unique : ne pas écraser la saisie en cours à chaque notify.
        if (!_nomCharge) {
          _nom.text = u.nomComplet;
          _nomCharge = true;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EnTetePage(
              titre: 'Mon compte',
              sousTitre: 'Votre identité et votre mot de passe.',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    Espace.xxl, 0, Espace.xxl, Espace.xxl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Identite(utilisateur: u),
                      const SizedBox(height: Espace.lg),
                      _Bloc(
                        titre: 'Identité',
                        description:
                            'Le nom affiché dans l\'application et sur les documents.',
                        enfant: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _nom,
                              decoration: const InputDecoration(
                                  labelText: 'Nom complet'),
                            ),
                            const SizedBox(height: Espace.lg),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton(
                                onPressed: _enregistrerNom,
                                child: const Text('Enregistrer'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Espace.lg),
                      _Bloc(
                        titre: 'Mot de passe',
                        description:
                            'Choisissez un mot de passe d\'au moins 4 caractères.',
                        enfant: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _actuel,
                              obscureText: true,
                              decoration: const InputDecoration(
                                  labelText: 'Mot de passe actuel'),
                            ),
                            const SizedBox(height: Espace.lg),
                            TextField(
                              controller: _nouveau,
                              obscureText: true,
                              decoration: const InputDecoration(
                                  labelText: 'Nouveau mot de passe'),
                            ),
                            const SizedBox(height: Espace.lg),
                            TextField(
                              controller: _confirmation,
                              obscureText: true,
                              decoration: const InputDecoration(
                                  labelText: 'Confirmer le nouveau mot de passe'),
                            ),
                            if (_erreurMdp != null) ...[
                              const SizedBox(height: Espace.md),
                              Text(
                                _erreurMdp!,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            const SizedBox(height: Espace.lg),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton(
                                onPressed: _changerMotDePasse,
                                child: const Text('Modifier le mot de passe'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _enregistrerNom() async {
    if (_nom.text.trim().isEmpty) return;
    await Session.instance.majProfil(_nom.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Identité mise à jour.')),
    );
  }

  Future<void> _changerMotDePasse() async {
    setState(() => _erreurMdp = null);

    if (_nouveau.text != _confirmation.text) {
      setState(() => _erreurMdp = 'Les deux mots de passe ne correspondent pas.');
      return;
    }

    final r =
        await Session.instance.changerMotDePasse(_actuel.text, _nouveau.text);
    if (!mounted) return;
    if (!r.ok) {
      setState(() => _erreurMdp = r.erreur);
      return;
    }

    _actuel.clear();
    _nouveau.clear();
    _confirmation.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mot de passe modifié.')),
    );
  }
}

class _Identite extends StatelessWidget {
  final Utilisateur utilisateur;
  const _Identite({required this.utilisateur});

  @override
  Widget build(BuildContext context) {
    final admin = utilisateur.role == Role.superAdmin;
    return Container(
      padding: const EdgeInsets.all(Espace.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(rayon),
        border: Border.all(color: AppColors.bordure),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: admin ? AppColors.rougePale : AppColors.bleuPale,
            child: Text(
              utilisateur.initiales,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: admin ? AppColors.rouge : AppColors.bleuSombre,
                fontFamily: 'Inter',
              ),
            ),
          ),
          const SizedBox(width: Espace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(utilisateur.nomComplet,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                Text('Identifiant : ${utilisateur.identifiant}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          admin
              ? Pastille.rouge('Administrateur')
              : Pastille.bleue('Enseignant'),
        ],
      ),
    );
  }
}

class _Bloc extends StatelessWidget {
  final String titre;
  final String description;
  final Widget enfant;

  const _Bloc({
    required this.titre,
    required this.description,
    required this.enfant,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Espace.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(rayon),
        border: Border.all(color: AppColors.bordure),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titre, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(description, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: Espace.lg),
          enfant,
        ],
      ),
    );
  }
}
