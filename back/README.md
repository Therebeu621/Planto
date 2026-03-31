# 🌿 Plant Management Backend

Backend API pour l'application de gestion de plantes domestiques.

## Architecture globale

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           UTILISATEURS                                  │
│                                                                         │
│   ┌──────────────┐    ┌──────────────┐    ┌──────────────────────┐     │
│   │  App Mobile   │    │  Goose/LLM   │    │  Navigateur          │     │
│   │  (Flutter)    │    │  (MCP)       │    │  (Swagger UI)        │     │
│   └──────┬───────┘    └──────┬───────┘    └──────────┬───────────┘     │
└──────────┼───────────────────┼───────────────────────┼─────────────────┘
           │ REST/JSON         │ REST/JSON              │
           │ Bearer JWT        │ X-MCP-API-Key          │
           │                   │ ou Bearer JWT          │
           ▼                   ▼                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                     KUBERNETES CLUSTER (Kind)                           │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                    Ingress (nginx)                                │   │
│  └──────────────────────────┬───────────────────────────────────────┘   │
│                              │                                          │
│  ┌───────────────────────────▼──────────────────────────────────────┐   │
│  │              BACKEND — Quarkus (Java 21)                         │   │
│  │              2 replicas par defaut (replicaCount Helm)           │   │
│  │                                                                   │   │
│  │  ┌─────────┐ ┌──────────┐ ┌──────────┐ ┌───────────────────┐    │   │
│  │  │  REST   │ │ Security │ │ Services │ │   Schedulers      │    │   │
│  │  │Resources│ │  (JWT)   │ │  Layer   │ │ (Cron: arrosage   │    │   │
│  │  │ 16 cls  │ │ RBAC     │ │ Services │ │  8h, soins lun 9h)│    │   │
│  │  └────┬────┘ └────┬─────┘ └────┬─────┘ └───────────────────┘    │   │
│  │       │           │            │                                  │   │
│  │       │     ┌─────▼─────┐      │                                  │   │
│  │       │     │ Panache   │◄─────┘                                  │   │
│  │       │     │ ORM       │                                         │   │
│  │       │     │ 19 entites│                                         │   │
│  │       │     └─────┬─────┘                                         │   │
│  │       │           │                                                │   │
│  │  Endpoints:       │    Endpoints systeme:                          │   │
│  │  /api/v1/*        │    /q/health/live    (liveness)                │   │
│  │  80+ routes       │    /q/health/ready   (readiness)               │   │
│  │                   │    /q/metrics         (prometheus)              │   │
│  │                   │    /q/swagger-ui      (documentation)          │   │
│  └───────────────────┼───────────────────────────────────────────────┘   │
│                      │                                                   │
│                      ▼                                                   │
│  ┌───────────────────────────────┐                                      │
│  │    PostgreSQL 15 (Bitnami)    │                                      │
│  │    StatefulSet + PVC          │                                      │
│  │    Flyway: 23 migrations      │                                      │
│  └───────────────────────────────┘                                      │
│                                                                         │
│  ┌────────────────────────────────────────────────────────────────┐     │
│  │                   OBSERVABILITE                                 │     │
│  │                                                                 │     │
│  │  Prometheus ──► Grafana (:30030)    Promtail ──► Loki          │     │
│  │  (scrape 15s)   2 dashboards        (log shipping)             │     │
│  │                 - Monitoring (HTTP, JVM, CPU)                   │     │
│  │                 - Logs (volume, erreurs, filtrage)              │     │
│  └────────────────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────────────┘

                        APIS EXTERNES
  ┌──────────┐ ┌──────────┐ ┌────────────┐ ┌──────────┐ ┌──────────┐
  │ Trefle.io│ │ Perenual │ │OpenWeather │ │  Gemini  │ │ Firebase │
  │ (especes)│ │ (soins)  │ │  (meteo)   │ │   (IA)   │ │  (FCM)   │
  └──────────┘ └──────────┘ └────────────┘ └──────────┘ └──────────┘
```

### Flux de donnees principaux

```
1. AUTH:     Mobile → POST /auth/login → JWT (access 1h + refresh 7j)
2. CRUD:     Mobile → Bearer JWT → Resource → Service → Panache → PostgreSQL
3. MCP:      LLM/Goose → X-MCP-API-Key ou Bearer JWT → McpResource → McpService (19 outils) → Services metier
4. PUSH:     Scheduler (cron) → NotificationService → Firebase FCM → Mobile
5. METRICS:  Prometheus → scrape /q/metrics (15s) → Grafana dashboards
6. LOGS:     Pods (JSON stdout) → Promtail → Loki → Grafana
```

### Pipeline CI/CD (GitLab)

```
┌────────┐    ┌────────┐    ┌────────┐    ┌──────────────────────┐
│  SAST  │───►│  SCA   │───►│  TEST  │───►│       BUILD          │
│SpotBugs│    │ Trivy  │    │Quarkus │    │ Kaniko → Docker      │
│Checkstl│    │        │    │+ PgSQL │    │ (JVM + Native)       │
└────────┘    └────────┘    └────────┘    │ → GitLab Registry    │
                                           └──────────┬───────────┘
                                                      │
                                           ┌──────────▼───────────┐
                                           │      DEPLOY          │
                                           │ helm upgrade (K8s)   │
                                           │ staging (auto)       │
                                           │ production (manual)  │
                                           └──────────────────────┘
```

## Stack technique & justification des choix

| Technologie | Choix | Pourquoi |
|-------------|-------|----------|
| **Backend** | Java 21 + Quarkus 3.30 | Demarrage rapide (~1s), faible empreinte memoire, extensions natives (JWT, Hibernate, Flyway, Micrometer). Ideal pour les microservices conteneurises. |
| **Frontend** | Flutter (Dart) | Un seul code pour Android, iOS et Web. Hot reload accelere le dev. Ecosysteme riche (Dio, Riverpod, Firebase). |
| **BDD** | PostgreSQL 15 | SGBDR robuste et open-source. Support JSON natif, excellent avec Hibernate/Panache. Flyway pour les migrations versionnees. |
| **Auth** | JWT (RS256) + Refresh Token | Stateless, scalable horizontalement (pas de session serveur). RS256 permet la verification sans partager la cle privee. |
| **ORM** | Hibernate Panache (Active Record) | Reduit le boilerplate vs JPA classique. Pattern Active Record lisible (`Plant.findById()`). |
| **Conteneurisation** | Docker + Kind + Helm | Environnement reproductible. Kind simule un vrai cluster K8s en local. Helm charts reutilisables pour staging/prod. |
| **Observabilite** | Prometheus + Grafana + Loki | Stack open-source standard. Metriques (Micrometer), dashboards (Grafana), logs centralises (Loki + Promtail). |
| **IA** | Google Gemini (Vision) | API multimodale performante pour l'identification de plantes par photo. Cout faible en mode flash. |
| **LLM** | MCP via Goose | Protocole standardise (Model Context Protocol) pour exposer des outils metier au LLM. Decouplage entre le modele et l'application. |
| **APIs plantes** | Trefle.io + Perenual | Bases de donnees botaniques complementaires (especes, soins, images). Fallback si l'une est indisponible. |

## Prérequis

- Java 21+
- Docker & Docker Compose
- Maven 3.9+ (ou utiliser `./mvnw`)

## Développement local

### 1. Lancer la base de données

```bash
docker-compose up -d
```

Cela démarre :
- **PostgreSQL** sur `localhost:5433`
- **PgAdmin** (interface web pour la BDD) sur `http://localhost:5050`
  - Connexion PgAdmin : `admin@plantmanager.dev` / `admin`
  - Pour se connecter à PostgreSQL : Host=`postgres`, Port=`5432`, DB=`plant_db`, User=`plant_user`, Pass=`plant_pass`

### 2. Lancer le backend

```bash
./mvnw quarkus:dev
```

### 3. Accéder à l'API

- **Swagger UI** : http://localhost:8080/q/swagger-ui
- **Health check** : http://localhost:8080/q/health
- **OpenAPI runtime (source de verite)** : `http://localhost:8080/q/openapi?format=yaml`
- **OpenAPI runtime JSON** : `http://localhost:8080/q/openapi?format=json`

### 3.b Spécification OpenAPI

Approche code-first, spec OpenAPI générée automatiquement par Quarkus et archivée en artefact CI.


### 4. Arrêter les services

```bash
docker-compose down          # Arrête les conteneurs (garde les données)
docker-compose down -v       # Arrête et supprime toutes les données
```

## Structure du projet

### Structure technique

```
src/main/java/com/plantmanager/
├── resource/    # Endpoints REST et MCP
├── service/     # Logique metier
├── entity/      # Entites JPA / Panache
├── dto/         # Contrats API
├── security/    # JWT, filtres et securite
├── client/      # Clients externes
└── health/      # Health checks
```

### Domaines fonctionnels couverts

- `auth` : authentification, login, register, JWT, refresh token
- `user` : gestion du profil utilisateur et informations de compte
- `house` : maisons, membres, roles, invitations, maison active, mode vacances
- `room` : gestion des pieces dans la maison active
- `plant` : CRUD plantes, details, photos, arrosage, historique de soins
- `species` : recherche botanique et enrichissement via Trefle / Perenual
- `notification` : notifications applicatives et push Firebase
- `mcp` : exposition d'outils LLM via `McpResource` et `McpService`
- `garden` : cultures du potager et suivi des etapes
- `stats` / `gamification` : statistiques, progression et suivi d'usage
- `pot` / `qrcode` / `iot` / `weather` : modules complementaires du projet

En pratique, ces domaines sont implementes a travers les classes de `resource/`, `service/`, `entity/` et `dto/`.

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
| `MCP_DEFAULT_USER_EMAIL` | Email utilisateur par defaut utilise uniquement en mode `X-MCP-API-Key` | *(vide)* |
| `FIREBASE_CREDENTIALS_PATH` | Chemin credentials Firebase | `/var/run/secrets/firebase/firebase-service-account.json` |
| `MAIL_FROM` | Adresse expediteur SMTP | `noreply@plantmanager.local` |
| `MAIL_HOST` | Serveur SMTP | `localhost` |
| `MAIL_PORT` | Port SMTP | `587` |
| `MAIL_USERNAME` | Utilisateur SMTP | *(vide)* |
| `MAIL_PASSWORD` | Mot de passe SMTP | *(vide)* |

> **Note :** En dev local, le mailer n'est pas mocke (`%dev.quarkus.mailer.mock=false`). Configurez `DEV_MAIL_*` pour tester les emails, sinon evitez les parcours de reset password et verification d'email.
> Les cles API externes (Trefle, Perenual, Gemini, etc.) ne sont pas necessaires pour les tests.

## API Trefle.io (Recherche d'espèces)

L'API utilise Trefle.io pour la recherche d'espèces. Les résultats sont cachés localement (7 jours).

### Configuration

1. Copier le fichier d'exemple :
   ```bash
   cp .env.example .env
   ```

2. Ouvrir `.env` et remplacer `TREFLE_API_TOKEN=your-trefle-token-here` par votre token d'equipe

3. Lancer le backend :
   ```bash
   ./mvnw quarkus:dev
   ```

### Tester

```bash
curl "http://localhost:8080/api/v1/species/search?q=rose" | jq .
```

## Integration MCP — Controle de Planto par LLM

Le backend expose des endpoints MCP permettant a un client LLM (Goose ou autre orchestrateur) d'executer des actions metier sur les donnees Planto.

Endpoints :
- `GET /api/v1/mcp/schema`
- `POST /api/v1/mcp/tools`

### Modes d'authentification

Deux modes sont supportes par `McpResource` :

1. `X-MCP-API-Key`
   - utile pour une integration serveur a serveur ou une demo simple
   - les actions sont alors executees pour l'utilisateur defini par `MCP_DEFAULT_USER_EMAIL`

2. `Authorization: Bearer <jwt>`
   - utile quand le client MCP agit au nom d'un vrai utilisateur connecte
   - les outils operent alors dans le contexte exact du JWT

### Configuration backend

Variables utiles :

```env
# Mode API key
MCP_API_KEY=your_mcp_api_key
MCP_DEFAULT_USER_EMAIL=default@example.com
```

Le mode `Bearer JWT` n'a pas besoin de `MCP_DEFAULT_USER_EMAIL`, car l'utilisateur est resolu depuis le token.

### Flux MCP

```
Utilisateur -> Goose / client LLM -> /api/v1/mcp/schema
                                  -> /api/v1/mcp/tools
                                  -> McpResource
                                  -> McpService
                                  -> Services metier / BDD
```

### Les 19 outils disponibles

| Outil | Description | Parametres |
|-------|-------------|------------|
| `list_houses` | Lister les maisons de l'utilisateur | — |
| `get_active_house` | Recuperer la maison active | — |
| `switch_active_house` | Changer la maison active | `houseId?`, `houseName?` |
| `list_plants` | Lister toutes les plantes de l'utilisateur | — |
| `search_plants` | Rechercher une espece dans la base botanique | `query` |
| `add_plant` | Ajouter une plante | `speciesName`, `roomName`, `nickname?` |
| `get_plant_detail` | Recuperer le detail d'une plante | `plantName` |
| `update_plant` | Modifier une plante | `plantName`, `newNickname?`, `notes?`, `isSick?`, `isWilted?`, `needsRepotting?`, `wateringIntervalDays?` |
| `delete_plant` | Supprimer une plante | `plantName` |
| `water_plant` | Arroser une plante | `plantName` |
| `water_all_plants` | Arroser toutes les plantes | — |
| `list_plants_needing_water` | Lister les plantes a arroser | — |
| `move_plant` | Deplacer une plante dans une piece | `plantName`, `roomName` |
| `list_rooms` | Lister les pieces de la maison active | — |
| `create_room` | Creer une piece dans la maison active | `name` |
| `delete_room` | Supprimer une piece | `roomName` |
| `get_care_recommendation` | Recuperer des conseils d'entretien | `speciesName` |
| `get_weather_watering_advice` | Conseil d'arrosage selon la meteo | `city` |
| `enrich_plant_caresheet` | Fiche de soin enrichie | `speciesName`, `city?` |

### Exemple Goose

Le point important pour Goose est surtout l'authentification. La documentation du profil depend du connecteur utilise, mais il faut prevoir :
- base URL : `http://localhost:8080/api/v1`
- soit un header `X-MCP-API-Key`
- soit un header `Authorization: Bearer <jwt>`

### Tester en curl

Recuperer le schema avec API key :

```bash
curl http://localhost:8080/api/v1/mcp/schema \
  -H "X-MCP-API-Key: your_mcp_api_key" | jq .
```

Executer un outil avec API key :

```bash
curl -X POST http://localhost:8080/api/v1/mcp/tools \
  -H "Content-Type: application/json" \
  -H "X-MCP-API-Key: your_mcp_api_key" \
  -d '{"tool":"list_plants","params":{}}' | jq .
```

Executer un outil avec Bearer JWT :

```bash
curl -X POST http://localhost:8080/api/v1/mcp/tools \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <your_jwt_token>" \
  -d '{"tool":"list_plants","params":{}}' | jq .
```

### Format de reponse

Succes :

```json
{
  "status": "success",
  "message": "2 plante(s) arrosee(s) avec succes!",
  "data": []
}
```

Erreur :

```json
{
  "status": "error",
  "message": "Plante 'xxx' introuvable",
  "data": null
}
```

### Securite MCP

- authentification requise via `X-MCP-API-Key` ou `Authorization: Bearer <jwt>`
- le LLM agit uniquement dans le contexte de l'utilisateur resolu
- aucune elevation de privilege specifique MCP n'est ajoutee
- sans API key valide ni JWT valide : `401 Unauthorized`

### Soutenance

Pour le scenario de demonstration global, voir aussi :
- `SCENARIO_DEMO.md`

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
- 2 pods `plant-backend` (valeur par defaut de `replicaCount`)
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
   - OpenAPI genere depuis `/q/openapi` (`openapi.yaml` / `.json`)
   - Images Docker (JVM + Native) via Kaniko, en s'appuyant sur le script partage `ci/build-image.sh`, taguees avec `GIT_SHA`.

## Équipe

- Anisse Hamdi
- Ali Can Cebi 
- Lucas Lefebvre
