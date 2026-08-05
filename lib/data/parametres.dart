import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'base_locale.dart';

/// Réglages qui figurent sur les documents officiels.
///
/// Le campus n'est pas ici : il vient de la sélection faite à la connexion,
/// voir [MagasinCampus].
class Parametres extends ChangeNotifier {
  static final Parametres instance = Parametres._();
  Parametres._();

  Database get _db => BaseLocale.instance.db;

  static const cleAnnee = 'annee_academique';

  final Map<String, String> _valeurs = {};

  Future<void> charger() async {
    final lignes = await _db.query('parametre');
    _valeurs
      ..clear()
      ..addEntries(lignes
          .map((l) => MapEntry(l['cle'] as String, l['valeur'] as String)));

    // Une fiche imprimée sans année serait inutilisable : on en propose
    // une, déduite du calendrier.
    if (!_valeurs.containsKey(cleAnnee)) {
      await definir(cleAnnee, _anneeCourante());
    }
    notifyListeners();
  }

  /// Année scolaire déduite de la date : bascule en août.
  static String _anneeCourante() {
    final maintenant = DateTime.now();
    final debut = maintenant.month >= 8 ? maintenant.year : maintenant.year - 1;
    return '$debut-${debut + 1}';
  }

  String lire(String cle, {String defaut = ''}) => _valeurs[cle] ?? defaut;

  String get annee => lire(cleAnnee);

  Future<void> definir(String cle, String valeur) async {
    await _db.insert(
      'parametre',
      {'cle': cle, 'valeur': valeur.trim()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _valeurs[cle] = valeur.trim();
    notifyListeners();
  }
}
