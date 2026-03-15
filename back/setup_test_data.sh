#!/bin/bash

# URL de l'API
API_URL="http://localhost:8080/api/v1"

echo "=== 1. Inscription / Vérification du compte ==="
# On essaie de créer le compte (si ça échoue car il existe déjà, c'est pas grave)
curl -s -X POST $API_URL/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email": "test@test.com", "password": "password123", "displayName": "Test User"}' > /dev/null

echo "=== 2. Connexion ==="
TOKEN=$(curl -s -X POST $API_URL/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "test@test.com", "password": "password123"}' | jq -r '.accessToken')

if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
  echo "❌ Erreur de connexion!"
  exit 1
fi
echo "✅ Token récupéré"

echo "=== 3. Création Maison ==="
HOUSE=$(curl -s -X POST $API_URL/houses \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name": "Appartement Test"}')
HOUSE_ID=$(echo $HOUSE | jq -r '.id')
echo "🏠 Maison créée: $HOUSE_ID"

echo "=== 4. Création Pièces ==="
SALON=$(curl -s -X POST $API_URL/rooms \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"houseId": "'$HOUSE_ID'", "name": "Salon", "type": "LIVING_ROOM"}')
SALON_ID=$(echo $SALON | jq -r '.id')
echo "🛋️ Salon: $SALON_ID"

CHAMBRE=$(curl -s -X POST $API_URL/rooms \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"houseId": "'$HOUSE_ID'", "name": "Chambre", "type": "BEDROOM"}')
CHAMBRE_ID=$(echo $CHAMBRE | jq -r '.id')
echo "🛏️ Chambre: $CHAMBRE_ID"

BALCON=$(curl -s -X POST $API_URL/rooms \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"houseId": "'$HOUSE_ID'", "name": "Balcon", "type": "BALCONY"}')
BALCON_ID=$(echo $BALCON | jq -r '.id')
echo "☀️ Balcon: $BALCON_ID"

echo "=== 5. Ajout des Plantes ==="
# Fonction helper pour ajouter une plante
add_plant() {
  local room_id=$1
  local name=$2
  local interval=$3
  local exposure=$4
  local is_sick=$5
  local is_wilted=$6
  local needs_repotting=$7
  
  curl -s -X POST $API_URL/plants \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d "{\"roomId\": \"$room_id\", \"nickname\": \"$name\", \"wateringIntervalDays\": $interval, \"exposure\": \"$exposure\", \"isSick\": $is_sick, \"isWilted\": $is_wilted, \"needsRepotting\": $needs_repotting}" | jq -r '.nickname'
}

# Fonction pour forcer une plante à avoir soif (SQL hack via Docker)
force_thirsty() {
  local plant_name=$1
  echo "💧 Assèchement de $plant_name (SQL hack)..."
  # Update last_watered to 30 days ago
  docker exec plant-db psql -U plant_user -d plant_db -c "UPDATE user_plant_entity SET last_watered = NOW() - INTERVAL '30 days' WHERE nickname = '$plant_name';" > /dev/null 2>&1
}

echo "=== 5. Ajout des Plantes (Scénarios de test) ==="
# 1. Normal
echo "- Normal (Monstera)..."
add_plant "$SALON_ID" "Monstera" 7 "PARTIAL_SHADE" false false false

# 2. Thirsty (needs date hack)
echo "- Soif (Pothos)..."
add_plant "$SALON_ID" "Pothos" 7 "SHADE" false false false
force_thirsty "Pothos"

# 3. Sick only
echo "- Malade (Calathea)..."
add_plant "$CHAMBRE_ID" "Calathea" 10 "SHADE" true false false

# 4. Wilted only
echo "- Fanée (Fugère)..."
add_plant "$BALCON_ID" "Fugère" 5 "SHADE" false true false

# 5. Repotting only
echo "- Rempotage (Ficus)..."
add_plant "$SALON_ID" "Ficus" 14 "SUN" false false true

# 6. Sick + Wilted
echo "- Malade + Fanée (Orchidée)..."
add_plant "$CHAMBRE_ID" "Orchidée" 7 "SUN" true true false

# 7. Sick + Repotting
echo "- Malade + Rempotage (Bambou)..."
add_plant "$BALCON_ID" "Bambou" 3 "SUN" true false true

# 8. Wilted + Repotting
echo "- Fanée + Rempotage (Yucca)..."
add_plant "$SALON_ID" "Yucca" 20 "SUN" false true true

# 9. All issues
echo "- LA TOTALE (Bégonia)..."
add_plant "$CHAMBRE_ID" "Bégonia" 5 "PARTIAL_SHADE" true true true
force_thirsty "Bégonia"

echo ""
echo "=== 6. Création Maison Secondaire ==="
HOUSE2=$(curl -s -X POST $API_URL/houses \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name": "Maison de Vacances"}')
HOUSE2_ID=$(echo $HOUSE2 | jq -r '.id')
echo "🏠 Maison 2 créée: $HOUSE2_ID"

echo "=== 7. Création Pièces Maison 2 ==="
JARDIN=$(curl -s -X POST $API_URL/rooms \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"houseId": "'$HOUSE2_ID'", "name": "Jardin", "type": "GARDEN"}')
JARDIN_ID=$(echo $JARDIN | jq -r '.id')
echo "🌳 Jardin: $JARDIN_ID"

CUISINE=$(curl -s -X POST $API_URL/rooms \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"houseId": "'$HOUSE2_ID'", "name": "Cuisine", "type": "KITCHEN"}')
CUISINE_ID=$(echo $CUISINE | jq -r '.id')
echo "🍳 Cuisine: $CUISINE_ID"

echo "=== 8. Ajout Plantes Maison 2 ==="
echo "- Basilic (Juste soif)..."
add_plant "$CUISINE_ID" "Basilic" 3 "SUN" false false false
force_thirsty "Basilic"

echo "- Rosier (Normal)..."
add_plant "$JARDIN_ID" "Rosier" 5 "SUN" false false false

echo ""
echo "=== 🎉 TERMINÉ ! ==="
echo "Tu peux te connecter avec : test@test.com / password123"
