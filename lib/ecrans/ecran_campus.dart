import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/magasin_campus.dart';
import '../data/modeles.dart';
import '../widgets/communs.dart';

/// Structure de l'établissement : annexes et campus rattachés.
class EcranCampus extends StatelessWidget {
  const EcranCampus({super.key});

  @override
  Widget build(BuildContext context) {
    final m = MagasinCampus.instance;

    return AnimatedBuilder(
      animation: m,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EnTetePage(
              titre: 'Campus',
              sousTitre:
                  'Annexes et campus. Chaque campus a ses propres spécialités, promotions et étudiants.',
              actions: [
                FilledButton.icon(
                  onPressed: () => _formulaireAnnexe(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nouvelle annexe'),
                ),
              ],
            ),
            Expanded(
              child: m.annexes.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.fromLTRB(
                          Espace.xxl, 0, Espace.xxl, Espace.xxl),
                      child: _AucuneAnnexe(),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                          Espace.xxl, 0, Espace.xxl, Espace.xxl),
                      children: [
                        for (final a in m.annexes) ...[
                          _CarteAnnexe(annexe: a),
                          const SizedBox(height: Espace.xxl),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _formulaireAnnexe(BuildContext context,
      {Annexe? annexe}) async {
    final intitule = TextEditingController(text: annexe?.intitule ?? '');

    await showDialog(
      context: context,
      builder: (c) => DialogueFormulaire(
        titre: annexe == null ? 'Nouvelle annexe' : 'Modifier l\'annexe',
        champs: [
          TextField(
            controller: intitule,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Intitulé',
              hintText: 'Campus annexe de Bafoussam',
            ),
          ),
        ],
        onEnregistrer: () async {
          if (intitule.text.trim().isEmpty) return;
          final ok = await executer(
            c,
            () => annexe == null
                ? MagasinCampus.instance.ajouterAnnexe(intitule.text)
                : MagasinCampus.instance.majAnnexe(annexe, intitule.text),
          );
          if (ok && c.mounted) Navigator.pop(c);
        },
      ),
    );
  }
}

class _CarteAnnexe extends StatelessWidget {
  final Annexe annexe;
  const _CarteAnnexe({required this.annexe});

  @override
  Widget build(BuildContext context) {
    final m = MagasinCampus.instance;
    final liste = m.campusDe(annexe.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Espace.sm, left: Espace.xs),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.rouge,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: Espace.md),
              Text(
                annexe.intitule,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: AppColors.texte,
                ),
              ),
              const SizedBox(width: Espace.sm),
              Text('${liste.length} campus',
                  style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _formulaireCampus(context, annexe),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Ajouter'),
              ),
              Tooltip(
                message: 'Modifier l\'annexe',
                child: InkWell(
                  onTap: () =>
                      EcranCampus._formulaireAnnexe(context, annexe: annexe),
                  borderRadius: BorderRadius.circular(rayonPetit),
                  child: const Padding(
                    padding: EdgeInsets.all(Espace.xs + 2),
                    child: Icon(Icons.edit_outlined,
                        size: 16, color: AppColors.bleu),
                  ),
                ),
              ),
              Tooltip(
                message: 'Supprimer l\'annexe',
                child: InkWell(
                  onTap: () => _supprimerAnnexe(context),
                  borderRadius: BorderRadius.circular(rayonPetit),
                  child: const Padding(
                    padding: EdgeInsets.all(Espace.xs + 2),
                    child: Icon(Icons.delete_outline,
                        size: 16, color: AppColors.danger),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(rayon),
            border: Border.all(color: AppColors.bordure),
          ),
          clipBehavior: Clip.antiAlias,
          child: liste.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: Espace.xl),
                  child: Center(
                    child: Text('Aucun campus dans cette annexe.',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < liste.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _LigneCampus(campus: liste[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _supprimerAnnexe(BuildContext context) async {
    final m = MagasinCampus.instance;
    final nbCampus = m.campusDe(annexe.id).length;

    final ok = await confirmerSuppression(
      context,
      titre: 'Supprimer l\'annexe ?',
      message: nbCampus > 0
          ? '« ${annexe.intitule} » sera supprimée avec ses $nbCampus campus, '
              'ainsi que TOUTES leurs spécialités, promotions et étudiants.'
          : '« ${annexe.intitule} » sera définitivement supprimée.',
    );
    if (ok && context.mounted) {
      await executer(context, () => m.supprimerAnnexe(annexe.id));
    }
  }

  static Future<void> _formulaireCampus(BuildContext context, Annexe annexe,
      {Campus? campus}) async {
    final intitule = TextEditingController(text: campus?.intitule ?? '');
    var annexeId = campus?.annexeId ?? annexe.id;
    final m = MagasinCampus.instance;

    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, majEtat) => DialogueFormulaire(
          titre: campus == null ? 'Nouveau campus' : 'Modifier le campus',
          champs: [
            TextField(
              controller: intitule,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Intitulé',
                hintText: 'CAMPUS A',
              ),
            ),
            SelecteurCherchable<String>(
              etiquette: 'Annexe de rattachement',
              valeur: annexeId,
              options: [
                for (final a in m.annexes)
                  OptionSelecteur(valeur: a.id, libelle: a.intitule),
              ],
              onChange: (v) => majEtat(() => annexeId = v),
            ),
          ],
          onEnregistrer: () async {
            if (intitule.text.trim().isEmpty) return;
            final ok = await executer(
              c,
              () => campus == null
                  ? m.ajouterCampus(annexeId, intitule.text)
                  : m.majCampus(campus, annexeId, intitule.text),
            );
            if (ok && c.mounted) Navigator.pop(c);
          },
        ),
      ),
    );
  }
}

class _LigneCampus extends StatefulWidget {
  final Campus campus;
  const _LigneCampus({required this.campus});

  @override
  State<_LigneCampus> createState() => _LigneCampusState();
}

class _LigneCampusState extends State<_LigneCampus> {
  bool _survol = false;

  @override
  Widget build(BuildContext context) {
    final m = MagasinCampus.instance;
    final c = widget.campus;
    final actif = m.actif?.id == c.id;

    return MouseRegion(
      onEnter: (_) => setState(() => _survol = true),
      onExit: (_) => setState(() => _survol = false),
      child: Container(
        color: _survol ? AppColors.survol : Colors.transparent,
        padding: const EdgeInsets.symmetric(
            horizontal: Espace.lg, vertical: Espace.md),
        child: Row(
          children: [
            const Icon(Icons.location_city_outlined,
                size: 17, color: AppColors.texteDoux),
            const SizedBox(width: Espace.md),
            Expanded(
              child: Text(
                c.intitule,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                  color: AppColors.texte,
                ),
              ),
            ),
            if (actif) ...[
              Pastille.succes('Campus courant'),
              const SizedBox(width: Espace.md),
            ],
            _Entete(campus: c),
            const SizedBox(width: Espace.md),
            FutureBuilder<int>(
              future: m.nbSpecialites(c.id),
              builder: (context, snap) => Text(
                snap.hasData ? '${snap.data} spécialité(s)' : '…',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: Espace.lg),
            ActionsLigne(
              onModifier: () => _CarteAnnexe._formulaireCampus(
                context,
                m.annexes.firstWhere((a) => a.id == c.annexeId),
                campus: c,
              ),
              onSupprimer: () => _supprimer(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _supprimer(BuildContext context) async {
    final m = MagasinCampus.instance;
    final c = widget.campus;

    if (m.actif?.id == c.id) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Impossible de supprimer le campus où vous travaillez.'),
      ));
      return;
    }

    final nb = await m.nbSpecialites(c.id);
    if (!context.mounted) return;

    final ok = await confirmerSuppression(
      context,
      titre: 'Supprimer le campus ?',
      message: nb > 0
          ? '« ${c.intitule} » compte $nb spécialité(s). Toutes leurs '
              'promotions, matières et étudiants seront supprimés.'
          : '« ${c.intitule} » sera définitivement supprimé.',
    );
    if (ok && context.mounted) {
      await executer(context, () => m.supprimerCampus(c.id));
    }
  }
}

/// En-tête propre au campus : aperçu, remplacement, retrait.
///
/// Sans en-tête, les documents du campus reprennent celui de l'institut.
class _Entete extends StatelessWidget {
  final Campus campus;
  const _Entete({required this.campus});

  @override
  Widget build(BuildContext context) {
    final present = campus.aEntete;

    return Tooltip(
      message: present
          ? 'En-tête personnalisé — cliquer pour le remplacer'
          : 'Aucun en-tête : celui de l\'institut est utilisé',
      child: InkWell(
        onTap: () => _menu(context, present),
        borderRadius: BorderRadius.circular(rayonPetit),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Espace.sm, vertical: Espace.xs),
          decoration: BoxDecoration(
            color: present ? AppColors.succesPale : AppColors.bordureDouce,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                present ? Icons.image_outlined : Icons.image_not_supported_outlined,
                size: 14,
                color: present ? AppColors.succes : AppColors.texteFaible,
              ),
              const SizedBox(width: Espace.xs + 1),
              Text(
                present ? 'En-tête' : 'Par défaut',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                  color: present ? AppColors.succes : AppColors.texteDoux,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _menu(BuildContext context, bool present) async {
    final action = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text('En-tête de ${campus.intitule}',
            style: Theme.of(c).textTheme.titleLarge),
        children: [
          if (present)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Espace.xl, 0, Espace.xl, Espace.md),
              child: Container(
                padding: const EdgeInsets.all(Espace.sm),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(rayonPetit),
                  border: Border.all(color: AppColors.bordure),
                ),
                child: Image.memory(campus.entete!, fit: BoxFit.contain),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Espace.xl, 0, Espace.xl, Espace.md),
              child: Text(
                'Ce campus utilise l\'en-tête générique de l\'institut sur '
                'ses fiches, listes de présence et sujets.',
                style: Theme.of(c).textTheme.bodySmall,
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, 'choisir'),
            child: Row(
              children: [
                const Icon(Icons.upload_outlined,
                    size: 18, color: AppColors.bleu),
                const SizedBox(width: Espace.md),
                Text(present ? 'Remplacer l\'image' : 'Choisir une image'),
              ],
            ),
          ),
          if (present)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, 'retirer'),
              child: Row(
                children: [
                  const Icon(Icons.delete_outline,
                      size: 18, color: AppColors.danger),
                  const SizedBox(width: Espace.md),
                  const Text('Retirer l\'en-tête'),
                ],
              ),
            ),
        ],
      ),
    );
    if (action == null || !context.mounted) return;

    if (action == 'retirer') {
      await executer(
        context,
        () => MagasinCampus.instance.definirEntete(campus, null),
        succes: 'En-tête retiré.',
      );
      return;
    }

    await _choisirImage(context);
  }

  Future<void> _choisirImage(BuildContext context) async {
    final messager = ScaffoldMessenger.of(context);
    String? chemin;
    try {
      final choix = await FilePicker.platform.pickFiles(
        dialogTitle: 'Choisir l\'en-tête du campus',
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg'],
      );
      chemin = choix?.files.single.path;
    } catch (e) {
      messager.showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        content: Text('Sélecteur de fichiers indisponible : $e'),
      ));
      return;
    }
    if (chemin == null || !context.mounted) return;

    final octets = await File(chemin).readAsBytes();

    // L'image vit dans la base : au-delà de 2 Mo, chaque sauvegarde
    // deviendrait inutilement lourde à transporter.
    if (octets.lengthInBytes > 2 * 1024 * 1024) {
      messager.showSnackBar(const SnackBar(
        backgroundColor: AppColors.danger,
        content: Text('Image trop lourde (2 Mo maximum).'),
      ));
      return;
    }
    if (!context.mounted) return;

    await executer(
      context,
      () => MagasinCampus.instance.definirEntete(campus, octets),
      succes: 'En-tête enregistré.',
    );
  }
}

class _AucuneAnnexe extends StatelessWidget {
  const _AucuneAnnexe();

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
            const Icon(Icons.apartment_outlined,
                size: 32, color: AppColors.texteFaible),
            const SizedBox(height: Espace.md),
            Text('Aucune annexe',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Espace.xs),
            Text('Créez une annexe, puis ses campus.',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
