#!/bin/bash

# URL de l'API
API_URL="http://localhost:8080/api/v1"

echo "=== Connexion ==="
TOKEN=$(curl -s -X POST $API_URL/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "test@test.com", "password": "password123"}' | jq -r '.accessToken')

if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
  echo "❌ Erreur de connexion!"
  exit 1
fi
echo "✅ Token récupéré"

echo "=== Récupération des maisons ==="
HOUSES=$(curl -s -X GET $API_URL/houses \
  -H "Authorization: Bearer $TOKEN")

# Extraire tous les IDs de maisons
HOUSE_IDS=$(echo $HOUSES | jq -r '.[].id')

if [ -z "$HOUSE_IDS" ]; then
  echo "✅ Aucune maison à supprimer"
  exit 0
fi

echo "=== Suppression des maisons ==="
for house_id in $HOUSE_IDS; do
  echo "🗑️ Suppression maison: $house_id"

  # D'abord, récupérer toutes les pièces de cette maison
  curl -s -X DELETE $API_URL/houses/$house_id \
    -H "Authorization: Bearer $TOKEN" > /dev/null
done

echo ""
echo "=== 🎉 NETTOYAGE TERMINÉ ! ==="
echo "Toutes les maisons et leurs données ont été supprimées"
