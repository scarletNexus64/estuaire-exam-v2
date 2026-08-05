import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app/theme.dart';
import '../data/magasin.dart';
import '../data/magasin_epreuves.dart';
import '../data/magasin_sessions.dart';
import '../data/modeles.dart';
import '../serveur/serveur_examen.dart';
import '../widgets/communs.dart';

/// Suivi en direct d'une épreuve : diffusion, sessions et incidents.
class EcranSurveillance extends StatefulWidget {
  final String epreuveId;

  const EcranSurveillance({super.key, required this.epreuveId});

  @override
  State<EcranSurveillance> createState() => _EcranSurveillanceState();
}

class _EcranSurveillanceState extends State<EcranSurveillance> {
  Timer? _rafraichissement;

  @override
  void initState() {
    super.initState();
    // Le temps restant et l'état « en ligne » évoluent sans qu'aucun
    // magasin ne notifie : on redessine à intervalle régulier.
    _rafraichissement = Timer.periodic(
      const Duration(seconds: 2),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _rafraichissement?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        MagasinEpreuves.instance,
        MagasinSessions.instance,
        ServeurExamen.instance,
      ]),
      builder: (context, _) {
        final e = MagasinEpreuves.instance.epreuve(widget.epreuveId);
        if (e == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Épreuve introuvable')),
            body: const SizedBox.shrink(),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.fond,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BarreTitre(epreuve: e),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _Sessions(epreuve: e)),
                    const VerticalDivider(width: 1),
                    SizedBox(width: 340, child: _PanneauDiffusion(epreuve: e)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BarreTitre extends StatelessWidget {
  final Epreuve epreuve;
  const _BarreTitre({required this.epreuve});

  @override
  Widget build(BuildContext context) {
    final sessions = MagasinSessions.instance.sessionsDePassation(
        epreuve.id, epreuve.debut?.toIso8601String() ?? '');
    final enLigne = sessions.where((s) => s.enLigne && !s.estSoumise).length;
    final remises = sessions.where((s) => s.estSoumise).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(
          Espace.xl, Espace.lg, Espace.xl, Espace.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.bordure)),
      ),
      child: Row(
        children: [
          Tooltip(
            message: 'Retour',
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(rayonPetit),
              child: const Padding(
                padding: EdgeInsets.all(Espace.sm),
                child: Icon(Icons.arrow_back, size: 20),
              ),
            ),
          ),
          const SizedBox(width: Espace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Surveillance — ${epreuve.titre}',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge),
                Text('${epreuve.dureeMinutes} minutes · ${epreuve.questions.length} questions',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          _Compteur(valeur: '$enLigne', libelle: 'en ligne', couleur: AppColors.succes),
          const SizedBox(width: Espace.xl),
          _Compteur(
              valeur: '${sessions.length}', libelle: 'connectés',
              couleur: AppColors.bleu),
          const SizedBox(width: Espace.xl),
          _Compteur(
              valeur: '$remises', libelle: 'remises', couleur: AppColors.alerte),
        ],
      ),
    );
  }
}

class _Compteur extends StatelessWidget {
  final String valeur;
  final String libelle;
  final Color couleur;

  const _Compteur({
    required this.valeur,
    required this.libelle,
    required this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(valeur,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'Inter',
              color: couleur,
            )),
        Text(libelle, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

// ---------- Sessions ----------

class _Sessions extends StatelessWidget {
  final Epreuve epreuve;
  const _Sessions({required this.epreuve});

  static const _flex = <double>[1.5, 2.4, 1.3, 1.2, 1.2, 1.3];

  @override
  Widget build(BuildContext context) {
    final m = Magasin.instance;
    final sessions = MagasinSessions.instance.sessionsDePassation(
        epreuve.id, epreuve.debut?.toIso8601String() ?? '')
      ..sort((a, b) => a.debut.compareTo(b.debut));

    return Padding(
      padding: const EdgeInsets.all(Espace.xl),
      child: Tableau(
        colonnes: const [
          'Matricule',
          'Étudiant',
          'Avancement',
          'Temps restant',
          'Incidents',
          'État',
        ],
        flex: _flex,
        messageVide: 'Aucun étudiant n\'a encore rejoint l\'épreuve.',
        lignes: [
          for (final s in sessions)
            LigneTableau(
              flex: _flex,
              cellules: [
                cellule(
                  m.etudiants
                          .where((e) => e.id == s.etudiantId)
                          .firstOrNull
                          ?.matricule ??
                      '—',
                  couleur: AppColors.bleuSombre,
                  gras: true,
                ),
                Row(
                  children: [
                    _Pastille(enLigne: s.enLigne && !s.estSoumise),
                    const SizedBox(width: Espace.sm),
                    Expanded(
                      child: cellule(
                        m.etudiants
                                .where((e) => e.id == s.etudiantId)
                                .firstOrNull
                                ?.nomComplet ??
                            '—',
                        gras: true,
                      ),
                    ),
                  ],
                ),
                cellule('${s.reponses.length} / ${epreuve.questions.length}'),
                cellule(
                  s.estSoumise ? '—' : _duree(s.restant(epreuve.dureeMinutes)),
                  couleur: !s.estSoumise &&
                          s.restant(epreuve.dureeMinutes).inMinutes < 5
                      ? AppColors.danger
                      : AppColors.texteDoux,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: s.alertes == 0
                      ? cellule('—', couleur: AppColors.texteFaible)
                      : Tooltip(
                          message: _detailIncidents(s.id),
                          child: Pastille(
                            texte: '${s.alertes}',
                            couleur: AppColors.danger,
                            fond: AppColors.dangerPale,
                          ),
                        ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: s.estSoumise
                      ? Pastille.succes(
                          'Remise · ${_note(s.note)}/${_note(epreuve.bareme)}')
                      : Pastille.bleue('En cours'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  static String _duree(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:'
      '${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  static String _note(double? n) {
    if (n == null) return '—';
    return n == n.roundToDouble() ? '${n.toInt()}' : n.toStringAsFixed(1);
  }

  String _detailIncidents(String sessionId) {
    final liste = ServeurExamen.instance.incidentsDe(sessionId).take(8);
    if (liste.isEmpty) return 'Aucun incident';
    return liste
        .map((i) =>
            '${i.instant.hour.toString().padLeft(2, '0')}:'
            '${i.instant.minute.toString().padLeft(2, '0')} — ${i.libelle}')
        .join('\n');
  }
}

class _Pastille extends StatelessWidget {
  final bool enLigne;
  const _Pastille({required this.enLigne});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: enLigne ? 'Connecté' : 'Sans signal depuis 30 s',
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enLigne ? AppColors.succes : AppColors.texteFaible,
        ),
      ),
    );
  }
}

// ---------- Diffusion ----------

class _PanneauDiffusion extends StatelessWidget {
  final Epreuve epreuve;
  const _PanneauDiffusion({required this.epreuve});

  @override
  Widget build(BuildContext context) {
    final serveur = ServeurExamen.instance;

    return Container(
      color: AppColors.surface,
      child: ListView(
        padding: const EdgeInsets.all(Espace.xl),
        children: [
          Text('DIFFUSION', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: Espace.md),
          if (!serveur.actif)
            _ServeurArrete(epreuve: epreuve)
          else
            _ServeurActif(epreuve: epreuve),
        ],
      ),
    );
  }
}

class _ServeurArrete extends StatelessWidget {
  final Epreuve epreuve;
  const _ServeurArrete({required this.epreuve});

  @override
  Widget build(BuildContext context) {
    final prete = epreuve.etat != EtatEpreuve.brouillon;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(Espace.lg),
          decoration: BoxDecoration(
            color: AppColors.fond,
            borderRadius: BorderRadius.circular(rayonPetit),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.wifi_off_outlined,
                      size: 17, color: AppColors.texteDoux),
                  const SizedBox(width: Espace.sm),
                  Text('Serveur arrêté',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: Espace.xs),
              Text(
                prete
                    ? 'Démarrez le serveur pour que les étudiants puissent se connecter depuis le réseau du campus.'
                    : 'Planifiez d\'abord l\'épreuve depuis l\'éditeur.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: Espace.lg),
        FilledButton.icon(
          onPressed: prete ? () => _demarrer(context) : null,
          icon: const Icon(Icons.play_arrow, size: 18),
          label: const Text('Démarrer le serveur'),
        ),
      ],
    );
  }

  Future<void> _demarrer(BuildContext context) async {
    final messager = ScaffoldMessenger.of(context);
    try {
      await ServeurExamen.instance.demarrer();
      if (ServeurExamen.instance.lien == null) {
        messager.showSnackBar(const SnackBar(
          backgroundColor: AppColors.alerte,
          content: Text(
              'Serveur démarré, mais aucune adresse réseau détectée. '
              'Vérifiez que le poste est connecté au Wi-Fi du campus.'),
        ));
      }
    } catch (e) {
      messager.showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        content: Text('Démarrage impossible : $e'),
      ));
    }
  }
}

class _ServeurActif extends StatelessWidget {
  final Epreuve epreuve;
  const _ServeurActif({required this.epreuve});

  @override
  Widget build(BuildContext context) {
    final lien = ServeurExamen.instance.lien;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(Espace.md),
          decoration: BoxDecoration(
            color: AppColors.succesPale,
            borderRadius: BorderRadius.circular(rayonPetit),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.succes,
                ),
              ),
              const SizedBox(width: Espace.sm),
              Text('Serveur en marche',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
        const SizedBox(height: Espace.lg),

        Text('Adresse à communiquer',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: Espace.xs),
        Container(
          padding: const EdgeInsets.all(Espace.md),
          decoration: BoxDecoration(
            color: AppColors.fond,
            borderRadius: BorderRadius.circular(rayonPetit),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  lien ?? 'Adresse réseau indisponible',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.bleuSombre,
                  ),
                ),
              ),
              if (lien != null)
                Tooltip(
                  message: 'Copier',
                  child: InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: lien));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Adresse copiée.')),
                      );
                    },
                    borderRadius: BorderRadius.circular(rayonPetit),
                    child: const Padding(
                      padding: EdgeInsets.all(Espace.xs),
                      child: Icon(Icons.copy_outlined,
                          size: 16, color: AppColors.texteDoux),
                    ),
                  ),
                ),
            ],
          ),
        ),

        if (lien != null) ...[
          const SizedBox(height: Espace.lg),
          // Le QR évite de dicter l'adresse à toute la salle.
          Center(
            child: Container(
              padding: const EdgeInsets.all(Espace.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(rayonPetit),
                border: Border.all(color: AppColors.bordure),
              ),
              child: QrImageView(
                data: lien,
                size: 160,
                backgroundColor: Colors.white,
              ),
            ),
          ),
        ],

        const SizedBox(height: Espace.lg),
        Text('Code d\'accès', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: Espace.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: Espace.md),
          decoration: BoxDecoration(
            color: AppColors.bleuPale,
            borderRadius: BorderRadius.circular(rayonPetit),
          ),
          child: Center(
            child: SelectableText(
              epreuve.codeAcces,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: 5,
                color: AppColors.bleuSombre,
              ),
            ),
          ),
        ),

        const SizedBox(height: Espace.xxl),
        OutlinedButton.icon(
          onPressed: () => _arreter(context),
          icon: const Icon(Icons.stop, size: 18),
          label: const Text('Arrêter le serveur'),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
        ),
        const SizedBox(height: Espace.sm),
        _BoutonCloturer(epreuve: epreuve),
      ],
    );
  }

  Future<void> _arreter(BuildContext context) async {
    final enCours = MagasinSessions.instance
        .sessionsDe(epreuve.id)
        .where((s) => !s.estSoumise)
        .length;

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Arrêter le serveur ?',
            style: Theme.of(c).textTheme.titleLarge),
        content: Text(
          enCours > 0
              ? '$enCours étudiant(s) composent encore. Ils perdront la '
                  'connexion, mais leurs réponses déjà saisies sont enregistrées.'
              : 'Les étudiants ne pourront plus se connecter.',
          style: Theme.of(c).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Arrêter'),
          ),
        ],
      ),
    );
    if (ok == true) await ServeurExamen.instance.arreter();
  }
}

/// Clôture anticipée de l'épreuve.
///
/// Distincte de l'arrêt du serveur : celui-ci coupe l'accès mais laisse
/// les copies ouvertes et sans note. La clôture corrige tout le monde,
/// ce qui rend la fiche de report et la liste de présence exploitables.
class _BoutonCloturer extends StatelessWidget {
  final Epreuve epreuve;
  const _BoutonCloturer({required this.epreuve});

  @override
  Widget build(BuildContext context) {
    final sessions = MagasinSessions.instance.sessionsDePassation(
        epreuve.id, epreuve.debut?.toIso8601String() ?? '');
    final ouvertes = sessions.where((s) => !s.estSoumise).length;
    final terminee = epreuve.etat == EtatEpreuve.terminee;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed:
              terminee || sessions.isEmpty ? null : () => _cloturer(context),
          icon: const Icon(Icons.task_alt, size: 18),
          label: Text(terminee ? 'Épreuve clôturée' : 'Clôturer l\'épreuve'),
          style: FilledButton.styleFrom(
            backgroundColor: terminee ? AppColors.texteDoux : AppColors.succes,
          ),
        ),
        const SizedBox(height: Espace.sm),
        Text(
          terminee
              ? 'Les notes sont figées. Les documents sont disponibles depuis « Notes ».'
              : sessions.isEmpty
                  ? 'Aucun étudiant n\'a encore composé.'
                  : ouvertes == 0
                      ? 'Toutes les copies sont remises : vous pouvez clôturer.'
                      : '$ouvertes copie(s) encore en cours seront remises en l\'état.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Future<void> _cloturer(BuildContext context) async {
    final sessions = MagasinSessions.instance.sessionsDePassation(
        epreuve.id, epreuve.debut?.toIso8601String() ?? '');
    final ouvertes = sessions.where((s) => !s.estSoumise).length;

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Clôturer l\'épreuve ?',
            style: Theme.of(c).textTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ouvertes == 0
                  ? 'Les ${sessions.length} copie(s) sont déjà remises. '
                      'La clôture fige les notes et marque l\'épreuve comme terminée.'
                  : '$ouvertes étudiant(s) composent encore. Leur copie sera '
                      'remise en l\'état et corrigée immédiatement.',
              style: Theme.of(c).textTheme.bodyMedium,
            ),
            const SizedBox(height: Espace.md),
            Text(
              'Cette action est définitive : les étudiants ne pourront plus '
              'modifier leurs réponses.',
              style: Theme.of(c).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.succes),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Clôturer'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final messager = ScaffoldMessenger.of(context);
    try {
      final remises = await MagasinSessions.instance.cloturer(epreuve);
      await MagasinEpreuves.instance
          .majEpreuve(epreuve, etat: EtatEpreuve.terminee);

      // L'accès n'a plus lieu d'être une fois les copies figées.
      if (ServeurExamen.instance.actif) {
        await ServeurExamen.instance.arreter();
      }
      if (!context.mounted) return;

      messager.showSnackBar(SnackBar(
        backgroundColor: AppColors.succes,
        content: Text(remises == 0
            ? 'Épreuve clôturée.'
            : 'Épreuve clôturée : $remises copie(s) remise(s) et corrigée(s).'),
      ));
      _proposerDocuments(context);
    } catch (e) {
      messager.showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        content: Text('Clôture impossible : $e'),
      ));
    }
  }

  /// Aiguille vers les documents, qui sont l'objet même de la clôture.
  void _proposerDocuments(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Épreuve terminée',
            style: Theme.of(c).textTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Les notes sont enregistrées. Vous pouvez éditer la fiche de '
              'report et la liste de présence depuis la rubrique « Notes ».',
              style: Theme.of(c).textTheme.bodyMedium,
            ),
            const SizedBox(height: Espace.lg),
            _Resume(epreuve: epreuve),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
  }
}

/// Récapitulatif chiffré, affiché après la clôture.
class _Resume extends StatelessWidget {
  final Epreuve epreuve;
  const _Resume({required this.epreuve});

  @override
  Widget build(BuildContext context) {
    final sessions = MagasinSessions.instance.sessionsDePassation(
        epreuve.id, epreuve.debut?.toIso8601String() ?? '');
    final notes = sessions
        .where((s) => s.note != null)
        .map((s) => s.note!)
        .toList();
    final moyenne = notes.isEmpty
        ? 0.0
        : notes.reduce((a, b) => a + b) / notes.length;
    final bareme = epreuve.bareme;
    final reussites =
        bareme > 0 ? notes.where((n) => n / bareme >= 0.5).length : 0;

    Widget ligne(String etiquette, String valeur) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Text(etiquette, style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              Text(valeur,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                    color: AppColors.texte,
                  )),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(Espace.lg),
      decoration: BoxDecoration(
        color: AppColors.fond,
        borderRadius: BorderRadius.circular(rayonPetit),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ligne('Copies corrigées', '${sessions.length}'),
          ligne('Moyenne',
              '${_nombre(moyenne)} / ${_nombre(bareme)}'),
          ligne('Au-dessus de la moyenne', '$reussites / ${notes.length}'),
        ],
      ),
    );
  }

  static String _nombre(double v) =>
      v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(2);
}
