import 'package:flutter/material.dart';

import 'app/coquille_admin.dart';
import 'app/theme.dart';
import 'data/base_locale.dart';
import 'data/magasin.dart';
import 'data/magasin_campus.dart';
import 'data/magasin_epreuves.dart';
import 'data/magasin_sessions.dart';
import 'data/parametres.dart';
import 'data/referentiel_insam.dart';
import 'data/session.dart';
import 'ecrans/ecran_connexion.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // La base locale doit être prête avant le premier écran : tout, y compris
  // l'authentification, la lit.
  String? erreurDemarrage;
  try {
    await BaseLocale.instance.ouvrir();
    await MagasinCampus.instance.charger();
    await Magasin.instance.charger();
    await MagasinEpreuves.instance.charger();
    await MagasinSessions.instance.charger();
    await Session.instance.charger();
    await Parametres.instance.charger();

    // Le référentiel INSAM n'est pas vital : sans lui l'application
    // fonctionne, seul l'import des promotions est indisponible. On ne
    // laisse donc pas son absence bloquer le démarrage.
    try {
      await ReferentielInsam.instance.ouvrir();
    } catch (_) {}
  } catch (e) {
    erreurDemarrage = '$e';
  }

  runApp(ApplicationEstuaire(erreurDemarrage: erreurDemarrage));
}

class ApplicationEstuaire extends StatelessWidget {
  final String? erreurDemarrage;

  const ApplicationEstuaire({super.key, this.erreurDemarrage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Estuaire Examen',
      debugShowCheckedModeBanner: false,
      theme: construireTheme(),
      home: erreurDemarrage == null
          ? const _Racine()
          : _EcranErreur(message: erreurDemarrage!),
    );
  }
}

/// Point d'entrée : l'écran de connexion s'affiche au lancement.
/// L'espace de travail n'apparaît qu'une fois la session ouverte.
class _Racine extends StatelessWidget {
  const _Racine();

  @override
  Widget build(BuildContext context) {
    final session = Session.instance;

    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: session.estConnecte
              // La clé porte l'identifiant : changer de compte reconstruit
              // entièrement la coquille (menu et état de navigation).
              ? CoquilleAdmin(key: ValueKey('espace-${session.courant!.id}'))
              : const EcranConnexion(key: ValueKey('connexion')),
        );
      },
    );
  }
}

/// Base illisible ou verrouillée : sans elle l'application ne peut rien faire.
class _EcranErreur extends StatelessWidget {
  final String message;
  const _EcranErreur({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fond,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            margin: const EdgeInsets.all(Espace.xxl),
            padding: const EdgeInsets.all(Espace.xxl),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(rayon),
              border: Border.all(color: AppColors.bordure),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline,
                    size: 30, color: AppColors.danger),
                const SizedBox(height: Espace.lg),
                Text('Base de données inaccessible',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: Espace.sm),
                Text(
                  'L\'application n\'a pas pu ouvrir sa base locale. '
                  'Vérifiez qu\'une autre instance n\'est pas déjà ouverte, '
                  'puis relancez.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: Espace.lg),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(Espace.md),
                  decoration: BoxDecoration(
                    color: AppColors.fond,
                    borderRadius: BorderRadius.circular(rayonPetit),
                  ),
                  child: Text(
                    message,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: AppColors.texteDoux,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
