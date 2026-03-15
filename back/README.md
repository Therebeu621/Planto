# 🌿 Plant Management Backend

Backend API pour l'application de gestion de plantes domestiques.

## Stack technique

- **Java 21** + **Quarkus 3.30**
- **PostgreSQL 15** (base de données)
- **JWT** (authentification)
- **Flyway** (migrations)
- **OpenAPI/Swagger** (documentation API)

## Prérequis

- Java 21+
- Docker & Docker Compose
- Maven 3.9+ (ou utiliser `./mvnw`)

## Développement local

### 1. Lancer la base de données

```bash
docker-compose up -d postgres pgadmin
```

Cela démarre :
- **PostgreSQL** sur `localhost:5433`
- **PgAdmin** (interface web pour la BDD) sur `http://localhost:5050`
  - Connexion PgAdmin : `admin@plantmanager.dev` / `admin`
  - Pour se connecter à PostgreSQL : Host=`postgres`, Port=`5432`, DB=`plant_db`, User=`plant_user`, Pass=`plant_pass`

### 2. Generer les cles JWT locales

```bash
./scripts/generate-jwt-keys.sh
```

### 3. Lancer le backend

```bash
./mvnw quarkus:dev
```

### 3. Accéder à l'API

- **Swagger UI** : http://localhost:8080/q/swagger-ui
- **Health check** : http://localhost:8080/q/health

### 4. Arrêter les services

```bash
docker-compose down          # Arrête les conteneurs (garde les données)
docker-compose down -v       # Arrête et supprime toutes les données
```

## Structure du projet

```
src/main/java/com/plantmanager/
├── auth/           # Authentification (login, register, JWT)
├── user/           # Gestion des utilisateurs
├── house/          # Gestion des maisons/familles
├── room/           # Gestion des pièces
├── plant/          # Gestion des plantes
├── species/        # Cache Trefle.io (espèces)
├── carelog/        # Historique des soins
├── notification/   # Notifications in-app
├── mcp/            # Endpoint MCP pour LLM
└── common/         # Utilitaires (exceptions, security)
```

## Configuration

Les variables d'environnement disponibles :

| Variable | Description | Defaut |
|----------|-------------|--------|
| `DB_HOST` | Hote PostgreSQL | `localhost` |
| `DB_PORT` | Port PostgreSQL | `5433` |
| `DB_NAME` | Nom de la base | `plant_db` |
| `DB_USER` | Utilisateur DB | `plant_user` |
| `DB_PASSWORD` | Mot de passe DB | `plant_pass` |
| `TREFLE_API_TOKEN` | Token API Trefle.io | *(vide)* |
| `PERENUAL_API_KEY` | Cle API Perenual | *(vide)* |
| `GEMINI_API_KEY` | Cle API Gemini AI | *(vide)* |
| `OPENWEATHER_API_KEY` | Cle API OpenWeatherMap | *(vide)* |
| `OPENWEATHER_DEFAULT_CITY` | Ville par defaut meteo | `Paris` |
| `MCP_API_KEY` | Cle API MCP (LLM) | *(vide)* |
| `MCP_DEFAULT_USER_EMAIL` | Email utilisateur MCP | *(vide)* |
| `FIREBASE_CREDENTIALS_PATH` | Chemin credentials Firebase | `/var/run/secrets/firebase/firebase-service-account.json` |
| `MAIL_FROM` | Adresse expediteur SMTP | `noreply@plantmanager.local` |
| `MAIL_HOST` | Serveur SMTP | `localhost` |
| `MAIL_PORT` | Port SMTP | `587` |
| `MAIL_USERNAME` | Utilisateur SMTP | *(vide)* |
| `MAIL_PASSWORD` | Mot de passe SMTP | *(vide)* |

> **Note :** En dev local, le mailer est automatiquement en mode mock (`%dev.quarkus.mailer.mock=true`).
> Les cles API externes (Trefle, Perenual, Gemini, etc.) ne sont pas necessaires pour les tests.
> Les fichiers `privateKey.pem` et `publicKey.pem` ne sont pas versionnes dans cette copie publique. Generez-les localement avec `./scripts/generate-jwt-keys.sh`.

## API Trefle.io (Recherche d'espèces)

L'API utilise Trefle.io pour la recherche d'espèces. Les résultats sont cachés localement (7 jours).

### Configuration

1. Copier le fichier d'exemple :
   ```bash
   cp .env.example .env
   ```

2. Ouvrir `.env` et remplacer `TREFLE_API_TOKEN=not-configured` par le token partagé par l'équipe

3. Lancer le backend :
   ```bash
   ./mvnw quarkus:dev
   ```

### Tester

```bash
curl "http://localhost:8080/api/v1/species/search?q=rose" | jq .
```

## 🚀 DevOps & Déploiement (Projet M2)

L'infrastructure complète (Kubernetes local, CI/CD, Helm) est automatisée via un gestionnaire de tâches (`Taskfile`).

### 1. Prérequis

Pour déployer l'architecture localement, vous devez avoir installé :
- [Docker](https://docs.docker.com/get-docker/) (moteur de conteneurs)
- [Kind](https://kind.sigs.k8s.io/) (pour lancer Kubernetes dans Docker)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/) (client K8s)
- [Helm](https://helm.sh/docs/intro/install/) (gestionnaire de paquets K8s)
- [Task](https://taskfile.dev/installation/) (lanceur de tches, ex: `go install github.com/go-task/task/v3/cmd/task@latest`)

### 2. Démarrage Rapide (All-in-One)

Si vous avez tous les prérequis, vous pouvez tout lancer en une seule commande (cluster, BDD, build d'images, et déploiement backend) :

```bash
task install-all
```

*(Note: Si vous n'avez pas de cluster, commencez par l'étape 3).*

### 3. Déploiement Étape par Étape

**Étape 1 : Créer le cluster Kubernetes (Kind)**
Vérifiez ou créez le cluster `plant-cluster` (3 nœuds, K8s v1.34.0) :
```bash
task create-kind
```

**Étape 2 : Déployer la base de données PostgreSQL**
Déploie le chart Helm Bitnami PostgreSQL :
```bash
task install-db
```

**Étape 3 : Compiler et charger les images Docker**
Compile l'application (JVM et Native) et charge les images dans le cluster Kind :
```bash
task build-image
```

**Etape 4 : Deployer le Backend (API)**
Deploie l'application via le chart Helm unique (`helm/backend`) :
```bash
task install-app
```

### 4. Verification

Une fois déployé, vous pouvez vérifier l'état des ressources :

```bash
kubectl get pods,svc,pvc
```

Vous devriez voir :
- 2 pods `plant-backend` (en statut `Running`)
- 1 pod `plant-db-postgresql-0`
- 1 Volume persistant (`pvc`) pour la base de données
- Les services réseau associés.

### Configuration Firebase (FCM)

Pour activer les push notifications en environnement Kubernetes, il faut fournir le fichier de service Firebase via un Secret monte dans le pod :

```bash
kubectl create secret generic firebase-service-account \
  --from-file=firebase-service-account.json=/chemin/vers/firebase-service-account.json
```

Puis lors du deploiement Helm :

```bash
helm upgrade --install plant-backend ./helm/backend \
  --set firebase.existingSecret=firebase-service-account
```

Sans ce Secret, le backend demarre quand meme, mais FCM reste desactive.

### 5. Nettoyage

Pour supprimer complètement l'environnement local (cluster et ressources) :

```bash
task delete-kind
```

### 6. Observabilite (bonus)

Installer la stack de monitoring (Prometheus, Grafana, Loki, Promtail) :

```bash
task install-observability
```

Acces Grafana : `http://localhost:30030` (admin / admin)

Deux dashboards sont provisionnes automatiquement :
- **Plant Backend - Monitoring** : requetes HTTP, temps de reponse, CPU/memoire, JVM heap, redemarrages
- **Plant Backend - Logs** : flux de logs par pod, volume par niveau, filtrage erreurs

### 7. Pipeline CI/CD (GitLab)

Le projet intègre une pipeline complète sur GitLab CI (`.gitlab-ci.yml`) :
1. **SAST** : Analyse statique avec *SpotBugs* et *Checkstyle*.
2. **SCA** : Scan de vulnérabilités des dépendances avec *Trivy* (image `aquasec/trivy`).
3. **Tests** : Tests unitaires Quarkus intégrés avec *Testcontainers* (PostgreSQL).
4. **Build & Artifacts** :
   - Javadoc (`.tar.gz`)
   - Swagger OpenAPI (`openapi.yaml` / `.json`)
   - Images Docker (JVM + Native) via Kaniko, en s'appuyant sur le script partage `ci/build-image.sh`, taguees avec `GIT_SHA`.

## Équipe

- Anisse Hamdi
- Ali Can Cebi 
- Lucas Lefebvre
