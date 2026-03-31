# PLANTO Frontend

Frontend Flutter de PLANTO. L'application consomme l'API Quarkus du backend et couvre l'authentification, la gestion des maisons partagees, des plantes, des pieces, du calendrier, du potager, des QR codes, des stats, de l'IA Gemini et des notifications.

## Architecture

```
Flutter (mobile / web / desktop)
        |
        | HTTP JSON + Bearer JWT
        v
Backend Quarkus (/api/v1)
```

Le frontend utilise :
- `dio` pour les appels API
- `flutter_riverpod` pour une partie de l'etat applicatif
- `shared_preferences` pour la persistance locale
- Firebase Messaging + notifications locales pour les rappels
- Gemini cote front pour l'identification IA et certaines interactions conversationnelles

## Plateformes supportees

- Android
- iOS
- Web
- macOS / Windows / Linux

## Structure du projet

```
lib/
├── main.dart
├── core/
│   ├── constants/   # Constantes globales et configuration runtime
│   ├── models/      # Modeles partages
│   ├── services/    # Services API, auth, notifications, Gemini, etc.
│   ├── theme/       # Theme et styles communs
│   ├── utils/       # Helpers et extensions
│   └── widgets/     # Widgets reutilisables
└── features/
    ├── auth/
    ├── calendar/
    ├── chat/
    ├── garden/
    ├── home/
    ├── house/
    ├── iot/
    ├── onboarding/
    ├── plant/
    ├── pot/
    ├── profile/
    ├── room/
    └── stats/
```

## Configuration

La configuration runtime principale passe par `--dart-define`.

Variables utiles :
- `API_BASE_URL` : URL du backend Quarkus
- `GEMINI_API_KEY` : cle Gemini utilisee par les fonctionnalites IA cote front

Exemple local :

```bash
flutter run \
  --dart-define=API_BASE_URL=http://localhost:8080 \
  --dart-define=GEMINI_API_KEY=your_gemini_api_key
```

Exemple Android emulator :

```bash
flutter run -d android \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080 \
  --dart-define=GEMINI_API_KEY=your_gemini_api_key
```

Important :
- ne jamais mettre de vraies cles API dans le repo
- utiliser uniquement des placeholders dans la documentation
- la fallback URL est geree dans `lib/core/constants/app_constants.dart`

## Lancement en developpement

Prerequis :
- Flutter SDK installe
- `flutter doctor` sans erreur bloquante
- backend Quarkus demarre localement ou accessible sur une URL connue

Installation :

```bash
flutter pub get
```

Lancement web :

```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8080 \
  --dart-define=GEMINI_API_KEY=your_gemini_api_key
```

Lancement Android :

```bash
flutter run -d android \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080 \
  --dart-define=GEMINI_API_KEY=your_gemini_api_key
```

Lancement iOS :

```bash
flutter run -d ios \
  --dart-define=API_BASE_URL=http://localhost:8080 \
  --dart-define=GEMINI_API_KEY=your_gemini_api_key
```

## Lancement avec Docker

Le projet contient aussi un mode de lancement conteneurise pour le frontend web :

```bash
docker-compose up --build
```

Puis :
- application accessible sur `http://localhost:3000`

Arret :

```bash
docker-compose down
```

## Qualite et CI

Commandes locales utiles :

```bash
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test --no-pub
```

La pipeline GitLab front execute actuellement :
- `flutter pub get`
- `flutter analyze --no-fatal-infos --no-fatal-warnings`
- `flutter test --no-pub`
- build d'image Docker via Kaniko

## Dependances principales

| Package | Usage |
|---------|-------|
| `flutter_riverpod` | Etat applicatif |
| `go_router` | Navigation |
| `dio` | Client HTTP |
| `shared_preferences` | Stockage local |
| `firebase_core` / `firebase_messaging` | Push notifications |
| `flutter_local_notifications` | Notifications locales |
| `google_sign_in` | Connexion Google |
| `image_picker` | Capture / selection d'image |
| `share_plus` | Partage natif |

## Lien avec le backend

Le frontend depend du backend Quarkus situe dans `../back`.

Points d'integration principaux :
- authentification JWT
- CRUD plantes / pieces / maisons
- historique de soins et calendrier
- QR codes
- stats et gamification
- mode vacances et collaboration
- potager
- IA Gemini cote front pour les experiences guidees

## Equipe

- Groupe Projet 4
