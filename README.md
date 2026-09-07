# Planty

Projet universitaire d'arrosage connecté : application Flutter, capteurs et
microcontrôleur ESP32, avec Firebase pour le suivi des plantes et les notifications.

## Le projet

- Application mobile : connexion, paramètres des plantes, mesures et historique.
- Firmware ESP32 : acquisition des capteurs et prototype de commande d'arrosage.
- Cloud Functions TypeScript : rappels d'arrosage manuel.

Cette version publique est une archive pédagogique indépendante, publiée à
partir des fichiers nettoyés, sans import d'ancien historique Git ni configuration
d'un service existant. Ce n'est pas une application de production maintenue.

## Organisation

| Dossier | Contenu |
| --- | --- |
| `lib/` | Application Flutter / Dart |
| `firmware/` | Sketch Arduino/ESP32 et exemple de configuration locale |
| `functions/` | Cloud Functions TypeScript, logique horaire et tests |

## Application Flutter

1. Installer un SDK Flutter compatible avec `pubspec.yaml`, puis lancer
   `flutter pub get`.
2. Créer votre propre projet Firebase de test, sans données réelles.
3. Exécuter `flutterfire configure --project=VOTRE_PROJET` pour générer
   `lib/firebase_options.dart` et les configurations natives requises.
   Ces fichiers doivent rester privés et sont ignorés par Git.
4. Exécuter `flutter analyze`, `flutter test`, puis `flutter run`.

`lib/firebase_options.example.dart` est un exemple documentaire, pas une
configuration fonctionnelle. Aucun accès au backend d'origine n'est fourni.
Le SDK Flutter et le fonctionnement de l'application sur appareil n'ont pas été
validés lors de la préparation de cette publication.

## Cloud Functions

Dans `functions/`, avec Node.js 22 ou 24 :

```sh
npm ci --ignore-scripts
npm run lint
npm test
npm audit
```

Le runtime Firebase est explicitement configuré en Node.js 22. La configuration
de lint utilise ESLint 10 et typescript-eslint. Les deux consommateurs indirects
de `uuid` (`gaxios` et `teeny-request`) sont contraints à la version corrigée 11.1.1
ou ultérieure dans la même version majeure ; leurs appels CommonJS à `v4` ont été
vérifiés. Il ne s'agit pas d'une exclusion ou d'une suppression des alertes d'audit.

Les notifications sont **désactivées par défaut** par le paramètre Firebase
`ENABLE_WATERING_NOTIFICATIONS=false`. Dans cet état, la fonction ne lit aucun
document et n'envoie aucun message. Les tests ne contactent pas Firebase.

Ne déployez pas simplement cette archive : un déploiement crée une planification
et peut entraîner des frais, même avec les notifications désactivées. Une
activation dans votre propre environnement demande un examen préalable des
autorisations IAM, des règles, des coûts, du volume de données et du risque de
notifications répétées. Aucun déploiement automatique n'est configuré ici.

## Données et matériel

Les règles Firestore et Realtime Database fournies refusent tous les accès
clients, même authentifiés. La reproduction complète exige des règles adaptées
au propriétaire de chaque plante et une identité dédiée par appareil, à tester
dans les émulateurs. Ne remplacez pas ces règles par un accès global ouvert.

Le firmware est un prototype : revoir l'authentification, les délais et les
sécurités physiques avant de connecter une pompe. Voir [firmware/README.md](firmware/README.md).

## Vérifications

Préparation du 8 septembre 2026 : build TypeScript, ESLint, cinq tests Node et
audit npm sans vulnérabilité signalée sur les dépendances des Cloud Functions.
Ce résultat ne constitue pas un audit exhaustif de Flutter, du firmware ou des
services cloud. Voir [SECURITY.md](SECURITY.md).

## Auteurs du projet universitaire

Ediz Buba et Abdellah Boussaha.
