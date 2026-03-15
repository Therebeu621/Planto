# 🌿 PLANTO - Frontend Flutter

Application mobile cross-platform pour PLANTO, développée avec Flutter et Riverpod.

## 📱 Plateformes supportées

- Android
- iOS
- Web
- macOS / Windows / Linux (Desktop)

---

## � Lancement avec Docker (Recommandé)

**Le plus simple !** Juste besoin de Docker installé.

```bash
# Lancer l'application
docker-compose up

# Ou en arrière-plan
docker-compose up -d
```

L'app sera disponible sur **http://localhost:3000** 🚀

```bash
# Arrêter
docker-compose down

# Rebuild après modifications
docker-compose up --build
```

---

## 🛠️ Lancement sans Docker (Développement)

### Prérequis

**macOS (Homebrew) :**
```bash
brew install --cask flutter
```

**Windows / Linux :**
Suivre le guide officiel : https://docs.flutter.dev/get-started/install

### Vérifier l'installation
```bash
flutter doctor
```

### Lancer le projet
```bash
# Installer les dépendances
flutter pub get

# Lancer l'application
flutter run
```

---

## 📂 Structure du projet

```
lib/
├── main.dart                 # Point d'entrée
├── core/
│   ├── constants/            # Constantes globales
│   ├── theme/                # Configuration du thème
│   ├── utils/                # Utilitaires et extensions
│   └── widgets/              # Widgets réutilisables
└── features/
    ├── auth/                 # Authentification
    ├── home/                 # Page d'accueil
    └── settings/             # Paramètres
```

## 🎨 Stack technique

| Package | Version | Usage |
|---------|---------|-------|
| flutter_riverpod | ^2.6.1 | State Management |
| go_router | ^14.6.2 | Navigation |
| dio | ^5.7.0 | Client HTTP |
| shared_preferences | ^2.3.3 | Stockage local |
| google_fonts | ^6.2.1 | Polices |

## 🏃 Commandes utiles

```bash
# Lancer sur Chrome (Web)
flutter run -d chrome

# Lancer sur Android
flutter run -d android

# Lancer sur iOS (Mac uniquement)
flutter run -d ios

# Analyser le code
flutter analyze

# Lancer les tests
flutter test
```

## ⚙️ Configuration

L'URL de l'API backend est configurée dans :
```
lib/core/constants/app_constants.dart
```

```dart
static const String apiBaseUrl = 'http://localhost:8080';
```

## 🔗 Backend

Ce frontend communique avec le backend Quarkus situé dans `jee-groupeprojet4/`.

## 👥 Équipe

- Groupe Projet 4
