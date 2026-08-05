import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/magasin.dart';
import '../data/magasin_campus.dart';
import '../data/magasin_epreuves.dart';
import '../data/magasin_sessions.dart';
import '../data/session.dart';
import '../widgets/communs.dart';

/// Écran de connexion — deux panneaux : marque à gauche, formulaire à droite.
/// Authentification factice, voir [Session].
class EcranConnexion extends StatefulWidget {
  const EcranConnexion({super.key});

  @override
  State<EcranConnexion> createState() => _EcranConnexionState();
}

class _EcranConnexionState extends State<EcranConnexion> {
  final _cleFormulaire = GlobalKey<FormState>();
  final _identifiant = TextEditingController();
  final _motDePasse = TextEditingController();
  final _focusMotDePasse = FocusNode();

  bool _masque = true;
  bool _enCours = false;
  String? _erreur;

  /// Campus de travail : détermine les données visibles après connexion.
  String? _campusId;

  @override
  void dispose() {
    _identifiant.dispose();
    _motDePasse.dispose();
    _focusMotDePasse.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    if (_enCours) return;
    setState(() => _erreur = null);
    if (!_cleFormulaire.currentState!.validate()) return;

    if (_campusId == null) {
      setState(() => _erreur = 'Choisissez votre campus.');
      return;
    }

    setState(() => _enCours = true);
    final resultat = await Session.instance.connecter(
      _identifiant.text,
      _motDePasse.text,
    );
    if (!mounted) return;

    if (!resultat.ok) {
      setState(() {
        _enCours = false;
        _erreur = resultat.erreur;
      });
      return;
    }

    // Le campus doit être posé avant le chargement : le magasin ne lit
    // que les données du campus actif.
    MagasinCampus.instance.choisir(MagasinCampus.instance.parId(_campusId!));
    await Magasin.instance.charger();
    await MagasinEpreuves.instance.charger();
    await MagasinSessions.instance.charger();
    // En cas de succès, la racine bascule sur l'application.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fond,
      body: LayoutBuilder(
        builder: (context, contraintes) {
          // Sous 900 px, le panneau de marque passe en bandeau supérieur.
          final etroit = contraintes.maxWidth < 900;
          if (etroit) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  const _BandeauMarque(),
                  Padding(
                    padding: const EdgeInsets.all(Espace.xl),
                    child: Center(child: _formulaire(context)),
                  ),
                ],
              ),
            );
          }
          return Row(
            children: [
              const Expanded(flex: 5, child: _PanneauMarque()),
              Expanded(
                flex: 6,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(Espace.xxl),
                    child: _formulaire(context),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _formulaire(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Form(
        key: _cleFormulaire,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Connexion', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: Espace.xs),
            Text(
              'Accédez à votre espace de travail.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: Espace.xl),

            const _Etiquette('Identifiant'),
            const SizedBox(height: Espace.sm),
            TextFormField(
              controller: _identifiant,
              autofocus: true,
              textInputAction: TextInputAction.next,
              enabled: !_enCours,
              decoration: const InputDecoration(
                hintText: 'ex. admin',
                prefixIcon: Icon(Icons.person_outline,
                    size: 18, color: AppColors.texteFaible),
                prefixIconConstraints:
                    BoxConstraints(minWidth: 38, minHeight: 38),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Saisissez votre identifiant.'
                  : null,
              onFieldSubmitted: (_) => _focusMotDePasse.requestFocus(),
            ),
            const SizedBox(height: Espace.lg),

            const _Etiquette('Mot de passe'),
            const SizedBox(height: Espace.sm),
            TextFormField(
              controller: _motDePasse,
              focusNode: _focusMotDePasse,
              obscureText: _masque,
              enabled: !_enCours,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.lock_outline,
                    size: 18, color: AppColors.texteFaible),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 38, minHeight: 38),
                suffixIcon: IconButton(
                  icon: Icon(
                    _masque ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 18,
                    color: AppColors.texteFaible,
                  ),
                  tooltip: _masque ? 'Afficher' : 'Masquer',
                  onPressed: () => setState(() => _masque = !_masque),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty)
                  ? 'Saisissez votre mot de passe.'
                  : null,
              onFieldSubmitted: (_) => _valider(),
            ),

            const SizedBox(height: Espace.lg),
            const _Etiquette('Campus'),
            const SizedBox(height: Espace.sm),
            _SelecteurCampus(
              valeur: _campusId,
              actif: !_enCours,
              onChange: (v) => setState(() {
                _campusId = v;
                _erreur = null;
              }),
            ),

            if (_erreur != null) ...[
              const SizedBox(height: Espace.lg),
              _BandeauErreur(message: _erreur!),
            ],

            const SizedBox(height: Espace.xl),
            SizedBox(
              height: 44,
              child: FilledButton(
                onPressed: _enCours ? null : _valider,
                child: _enCours
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Se connecter'),
              ),
            ),

            const SizedBox(height: Espace.xl),
            Text(
              'Vos identifiants vous sont remis par l’administration.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Etiquette extends StatelessWidget {
  final String texte;
  const _Etiquette(this.texte);

  @override
  Widget build(BuildContext context) {
    return Text(
      texte,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: AppColors.texte,
      ),
    );
  }
}

/// Choix du campus de travail, groupé par annexe.
class _SelecteurCampus extends StatelessWidget {
  final String? valeur;
  final bool actif;
  final ValueChanged<String?> onChange;

  const _SelecteurCampus({
    required this.valeur,
    required this.actif,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final m = MagasinCampus.instance;

    return AnimatedBuilder(
      animation: m,
      builder: (context, _) {
        if (m.campus.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(Espace.md),
            decoration: BoxDecoration(
              color: AppColors.alertePale,
              borderRadius: BorderRadius.circular(rayonPetit),
            ),
            child: Text(
              'Aucun campus configuré. Un administrateur doit en créer un.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        }

        return SelecteurCherchable<String>(
          etiquette: 'Campus de travail',
          valeur: valeur,
          indice: 'Choisir votre campus…',
          options: [
            // Groupé par annexe : « CAMPUS A » seul serait ambigu entre
            // Bafoussam et Mbouda.
            for (final a in m.annexes)
              for (final c in m.campusDe(a.id))
                OptionSelecteur(
                  valeur: c.id,
                  libelle: c.intitule,
                  detail: a.intitule,
                ),
          ],
          onChange: actif ? onChange : (_) {},
        );
      },
    );
  }
}

class _BandeauErreur extends StatelessWidget {
  final String message;
  const _BandeauErreur({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Espace.md, vertical: Espace.md),
      decoration: BoxDecoration(
        color: AppColors.dangerPale,
        borderRadius: BorderRadius.circular(rayonPetit),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 17, color: AppColors.danger),
          const SizedBox(width: Espace.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.danger,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Panneau latéral de marque (écrans larges).
class _PanneauMarque extends StatelessWidget {
  const _PanneauMarque();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.ardoise, Color(0xFF243244)],
        ),
      ),
      child: Stack(
        children: [
          // Halos colorés discrets, repris des teintes du logo.
          Positioned(
            top: -80,
            right: -60,
            child: _Halo(couleur: AppColors.rouge.withValues(alpha: 0.18)),
          ),
          Positioned(
            bottom: -100,
            left: -70,
            child: _Halo(couleur: AppColors.bleu.withValues(alpha: 0.20)),
          ),
          Padding(
            padding: const EdgeInsets.all(Espace.xxxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const LogoEstuaire(hauteur: 96),
                const SizedBox(height: Espace.xxl),
                const Text(
                  'Évaluation des étudiants,\nsur le poste du campus.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 28,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.7,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: Espace.lg),
                Text(
                  'Gestion des filières, des matières et des notes. '
                  'Aucune connexion Internet n’est nécessaire : tout '
                  'fonctionne en local.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    height: 1.55,
                    color: Colors.white.withValues(alpha: 0.70),
                  ),
                ),
                const SizedBox(height: Espace.xxl),
                const _PointFort(
                    Icons.wifi_off_outlined, 'Aucune connexion requise'),
                const SizedBox(height: Espace.md),
                const _PointFort(
                    Icons.storage_outlined, 'Données stockées localement'),
                const SizedBox(height: Espace.md),
                const _PointFort(
                    Icons.verified_user_outlined, 'Accès séparé par rôle'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Halo extends StatelessWidget {
  final Color couleur;
  const _Halo({required this.couleur});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: 260,
      decoration: BoxDecoration(shape: BoxShape.circle, color: couleur),
    );
  }
}

class _PointFort extends StatelessWidget {
  final IconData icone;
  final String texte;
  const _PointFort(this.icone, this.texte);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icone, size: 17, color: Colors.white.withValues(alpha: 0.65)),
        const SizedBox(width: Espace.md),
        Text(
          texte,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

/// Version compacte de la marque (écrans étroits).
class _BandeauMarque extends StatelessWidget {
  const _BandeauMarque();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Espace.xxl),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.ardoise, Color(0xFF243244)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LogoEstuaire(hauteur: 58),
          const SizedBox(height: Espace.lg),
          Text(
            'Plateforme d’évaluation des étudiants — hors ligne.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}
