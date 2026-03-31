#!/bin/bash
#
# Script de test complet de l'interface MCP
# Usage: ./test-mcp.sh [BASE_URL] [API_KEY]
#
# Prerequis: le backend doit tourner (./mvnw quarkus:dev)
#

BASE_URL="${1:-http://localhost:8080/api/v1}"
API_KEY="${2:-mcp-plant-secret-key}"
PASS=0
FAIL=0
TOTAL=0

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================================
# Helpers
# ============================================================

call_mcp() {
    local endpoint="$1"
    local method="${2:-POST}"
    local data="$3"
    local extra_headers="$4"

    if [ "$method" = "GET" ]; then
        curl -s -w "\n%{http_code}" \
            -H "Content-Type: application/json" \
            -H "X-MCP-API-Key: $API_KEY" \
            $extra_headers \
            "$BASE_URL/mcp/$endpoint"
    else
        curl -s -w "\n%{http_code}" \
            -X "$method" \
            -H "Content-Type: application/json" \
            -H "X-MCP-API-Key: $API_KEY" \
            $extra_headers \
            -d "$data" \
            "$BASE_URL/mcp/$endpoint"
    fi
}

# Run a test case
# $1 = test name
# $2 = endpoint
# $3 = method
# $4 = data (JSON body)
# $5 = expected HTTP status
# $6 = expected string in response body
# $7 = extra headers (optional)
run_test() {
    local name="$1"
    local endpoint="$2"
    local method="$3"
    local data="$4"
    local expected_status="$5"
    local expected_body="$6"
    local extra_headers="$7"

    TOTAL=$((TOTAL + 1))

    local response
    response=$(call_mcp "$endpoint" "$method" "$data" "$extra_headers")

    local http_code
    http_code=$(echo "$response" | tail -1)
    local body
    body=$(echo "$response" | sed '$d')

    local status_ok=true
    local body_ok=true

    if [ "$http_code" != "$expected_status" ]; then
        status_ok=false
    fi

    if [ -n "$expected_body" ] && ! echo "$body" | grep -q "$expected_body"; then
        body_ok=false
    fi

    if $status_ok && $body_ok; then
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC} [$http_code] $name"
    else
        FAIL=$((FAIL + 1))
        echo -e "  ${RED}FAIL${NC} [$http_code] $name"
        if ! $status_ok; then
            echo -e "       Expected status: $expected_status, got: $http_code"
        fi
        if ! $body_ok; then
            echo -e "       Expected body to contain: '$expected_body'"
            echo -e "       Got: $(echo "$body" | head -c 200)"
        fi
    fi
}

# ============================================================
# Tests
# ============================================================

echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}    TEST MCP INTERFACE - Plant Manager      ${NC}"
echo -e "${CYAN}============================================${NC}"
echo -e "  Base URL: $BASE_URL"
echo -e "  API Key:  ${API_KEY:0:10}..."
echo ""

# Pre-cleanup: supprimer les pieces de test des runs precedents (ignorer les erreurs)
for room in "Bureau MCP Test" "Chambre MCP Test" "Terrasse MCP" "Piece A Supprimer" "Piece Avec Plantes" "$(printf 'R%.0s' {1..100})"; do
    curl -s -X POST -H "Content-Type: application/json" -H "X-MCP-API-Key: $API_KEY" \
        -d "{\"tool\": \"delete_room\", \"params\": {\"roomName\": \"$room\"}}" \
        "$BASE_URL/mcp/tools" > /dev/null 2>&1
done
# Pre-cleanup: supprimer les plantes de test des runs precedents
for plant in "Test MCP Plant" "Mon Ficus MCP" "Plante Salon MCP" "Super Plante" "Ma plante" "Orchidee Test" "Cactus Bureau" "Basilic Malade" "Plante Orpheline Test" "Nouvelle Plante Achetee" "Plante A Supprimer"; do
    curl -s -X POST -H "Content-Type: application/json" -H "X-MCP-API-Key: $API_KEY" \
        -d "{\"tool\": \"delete_plant\", \"params\": {\"plantName\": \"$plant\"}}" \
        "$BASE_URL/mcp/tools" > /dev/null 2>&1
done
echo -e "  ${CYAN}Pre-nettoyage effectue.${NC}"
echo ""

# ----------------------------------------------------------
echo -e "${YELLOW}--- 1. SCHEMA ---${NC}"
# ----------------------------------------------------------

run_test \
    "GET /mcp/schema - retourne le schema des outils" \
    "schema" "GET" "" \
    "200" "list_plants"

run_test \
    "GET /mcp/schema - contient add_plant" \
    "schema" "GET" "" \
    "200" "add_plant"

run_test \
    "GET /mcp/schema - contient water_plant" \
    "schema" "GET" "" \
    "200" "water_plant"

run_test \
    "GET /mcp/schema - contient search_plants" \
    "schema" "GET" "" \
    "200" "search_plants"

# ----------------------------------------------------------
echo ""
echo -e "${YELLOW}--- 2. AUTHENTIFICATION ---${NC}"
# ----------------------------------------------------------

# Test sans API key
TOTAL=$((TOTAL + 1))
response=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{"tool": "list_plants"}' \
    "$BASE_URL/mcp/tools")
http_code=$(echo "$response" | tail -1)
if [ "$http_code" = "401" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} [$http_code] Sans API key -> 401 Unauthorized"
else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC} [$http_code] Sans API key -> attendu 401"
fi

# Test avec mauvaise API key
TOTAL=$((TOTAL + 1))
response=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -H "X-MCP-API-Key: wrong-key-12345" \
    -d '{"tool": "list_plants"}' \
    "$BASE_URL/mcp/tools")
http_code=$(echo "$response" | tail -1)
if [ "$http_code" = "401" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} [$http_code] Mauvaise API key -> 401 Unauthorized"
else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC} [$http_code] Mauvaise API key -> attendu 401"
fi

# Test schema sans API key
TOTAL=$((TOTAL + 1))
response=$(curl -s -w "\n%{http_code}" \
    -H "Content-Type: application/json" \
    "$BASE_URL/mcp/schema")
http_code=$(echo "$response" | tail -1)
if [ "$http_code" = "401" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} [$http_code] Schema sans API key -> 401 Unauthorized"
else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC} [$http_code] Schema sans API key -> attendu 401"
fi

# Test API key vide
TOTAL=$((TOTAL + 1))
response=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -H "X-MCP-API-Key: " \
    -d '{"tool": "list_plants"}' \
    "$BASE_URL/mcp/tools")
http_code=$(echo "$response" | tail -1)
if [ "$http_code" = "401" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} [$http_code] API key vide -> 401 Unauthorized"
else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC} [$http_code] API key vide -> attendu 401"
fi

# ----------------------------------------------------------
echo ""
echo -e "${YELLOW}--- 3. OUTIL INCONNU / REQUETES INVALIDES ---${NC}"
# ----------------------------------------------------------

run_test \
    "Outil inexistant -> erreur 400" \
    "tools" "POST" \
    '{"tool": "destroy_all_plants", "params": {}}' \
    "400" "Unknown tool"

run_test \
    "Tool name vide -> erreur 400" \
    "tools" "POST" \
    '{"tool": "", "params": {}}' \
    "400" "required"

run_test \
    "Tool name null (absent) -> erreur 400" \
    "tools" "POST" \
    '{"params": {}}' \
    "400" "required"

run_test \
    "Body vide -> erreur" \
    "tools" "POST" \
    '{}' \
    "400" ""

run_test \
    "Outil avec injection SQL dans le nom -> erreur 400" \
    "tools" "POST" \
    '{"tool": "list_plants; DROP TABLE app_user;--", "params": {}}' \
    "400" "Unknown tool"

run_test \
    "Outil avec caracteres speciaux -> erreur 400" \
    "tools" "POST" \
    '{"tool": "scriptalert1script", "params": {}}' \
    "400" "Unknown tool"

# ----------------------------------------------------------
echo ""
echo -e "${YELLOW}--- 4. LIST_PLANTS ---${NC}"
# ----------------------------------------------------------

run_test \
    "list_plants - succes" \
    "tools" "POST" \
    '{"tool": "list_plants"}' \
    "200" "success"

run_test \
    "list_plants sans params -> fonctionne" \
    "tools" "POST" \
    '{"tool": "list_plants", "params": null}' \
    "200" "success"

run_test \
    "list_plants avec params ignores -> fonctionne" \
    "tools" "POST" \
    '{"tool": "list_plants", "params": {"extra": "ignored"}}' \
    "200" "success"

# ----------------------------------------------------------
echo ""
echo -e "${YELLOW}--- 5. SEARCH_PLANTS ---${NC}"
# ----------------------------------------------------------

run_test \
    "search_plants - recherche valide 'rose'" \
    "tools" "POST" \
    '{"tool": "search_plants", "params": {"query": "rose"}}' \
    "200" "success"

run_test \
    "search_plants - recherche valide 'ficus'" \
    "tools" "POST" \
    '{"tool": "search_plants", "params": {"query": "ficus"}}' \
    "200" "success"

run_test \
    "search_plants - recherche valide 'aloe vera'" \
    "tools" "POST" \
    '{"tool": "search_plants", "params": {"query": "aloe vera"}}' \
    "200" "success"

run_test \
    "search_plants - query trop courte (1 char) -> erreur" \
    "tools" "POST" \
    '{"tool": "search_plants", "params": {"query": "a"}}' \
    "400" "min 2"

run_test \
    "search_plants - query vide -> erreur" \
    "tools" "POST" \
    '{"tool": "search_plants", "params": {"query": ""}}' \
    "400" "required"

run_test \
    "search_plants - sans param query -> erreur" \
    "tools" "POST" \
    '{"tool": "search_plants", "params": {}}' \
    "400" "required"

run_test \
    "search_plants - sans params du tout -> erreur" \
    "tools" "POST" \
    '{"tool": "search_plants"}' \
    "400" "required"

run_test \
    "search_plants - espece inexistante -> succes mais 0 resultats" \
    "tools" "POST" \
    '{"tool": "search_plants", "params": {"query": "xyzplanteinexistante"}}' \
    "200" "Aucune"

run_test \
    "search_plants - injection SQL dans query -> pas de crash" \
    "tools" "POST" \
    '{"tool": "search_plants", "params": {"query": "rose DROP TABLE app_user"}}' \
    "200" ""

run_test \
    "search_plants - XSS dans query -> pas de crash" \
    "tools" "POST" \
    '{"tool": "search_plants", "params": {"query": "scriptalert1script"}}' \
    "200" ""

# ----------------------------------------------------------
echo ""
echo -e "${YELLOW}--- 6. ADD_PLANT ---${NC}"
# ----------------------------------------------------------

run_test \
    "add_plant - ajout simple avec nickname" \
    "tools" "POST" \
    '{"tool": "add_plant", "params": {"nickname": "Test MCP Plant"}}' \
    "200" "ajoutee"

run_test \
    "add_plant - ajout avec espece" \
    "tools" "POST" \
    '{"tool": "add_plant", "params": {"nickname": "Mon Ficus MCP", "speciesName": "ficus"}}' \
    "200" "ajoutee"

run_test \
    "add_plant - ajout avec piece" \
    "tools" "POST" \
    '{"tool": "add_plant", "params": {"nickname": "Plante Salon MCP", "roomName": "Salon"}}' \
    "200" "ajoutee"

run_test \
    "add_plant - ajout complet (espece + piece + nickname)" \
    "tools" "POST" \
    '{"tool": "add_plant", "params": {"nickname": "Super Plante", "speciesName": "aloe vera", "roomName": "Chambre"}}' \
    "200" "ajoutee"

run_test \
    "add_plant - sans aucun param -> utilise nom par defaut" \
    "tools" "POST" \
    '{"tool": "add_plant", "params": {}}' \
    "200" "ajoutee"

run_test \
    "add_plant - nickname vide -> utilise nom par defaut" \
    "tools" "POST" \
    '{"tool": "add_plant", "params": {"nickname": ""}}' \
    "200" "ajoutee"

run_test \
    "add_plant - piece inexistante -> plante creee sans piece" \
    "tools" "POST" \
    '{"tool": "add_plant", "params": {"nickname": "Plante Sans Piece", "roomName": "PieceQuiExistePas123"}}' \
    "200" "ajoutee"

run_test \
    "add_plant - espece inexistante -> utilise comme customSpecies" \
    "tools" "POST" \
    '{"tool": "add_plant", "params": {"nickname": "Plante Rare", "speciesName": "EspeceInventee123"}}' \
    "200" "ajoutee"

run_test \
    "add_plant - nickname tres long (200 chars)" \
    "tools" "POST" \
    "{\"tool\": \"add_plant\", \"params\": {\"nickname\": \"$(printf 'A%.0s' {1..200})\"}}" \
    "200" ""

# ----------------------------------------------------------
echo ""
echo -e "${YELLOW}--- 7. WATER_PLANT ---${NC}"
# ----------------------------------------------------------

run_test \
    "water_plant - arroser 'Test MCP Plant'" \
    "tools" "POST" \
    '{"tool": "water_plant", "params": {"plantName": "Test MCP Plant"}}' \
    "200" "arrosee"

run_test \
    "water_plant - arroser 'Mon Ficus MCP'" \
    "tools" "POST" \
    '{"tool": "water_plant", "params": {"plantName": "Mon Ficus MCP"}}' \
    "200" "arrosee"

run_test \
    "water_plant - sans param plantName -> erreur" \
    "tools" "POST" \
    '{"tool": "water_plant", "params": {}}' \
    "400" "required"

run_test \
    "water_plant - plantName vide -> erreur" \
    "tools" "POST" \
    '{"tool": "water_plant", "params": {"plantName": ""}}' \
    "400" "required"

run_test \
    "water_plant - plante inexistante -> erreur" \
    "tools" "POST" \
    '{"tool": "water_plant", "params": {"plantName": "PlanteQuiExistePas999"}}' \
    "400" "Aucune plante"

run_test \
    "water_plant - arroser 2 fois la meme plante -> OK" \
    "tools" "POST" \
    '{"tool": "water_plant", "params": {"plantName": "Test MCP Plant"}}' \
    "200" "arrosee"

run_test \
    "water_plant - recherche partielle du nom" \
    "tools" "POST" \
    '{"tool": "water_plant", "params": {"plantName": "Test MCP"}}' \
    "200" ""

# ----------------------------------------------------------
echo ""
echo -e "${YELLOW}--- 8. WATER_ALL_PLANTS ---${NC}"
# ----------------------------------------------------------

run_test \
    "water_all_plants - arroser toutes les plantes" \
    "tools" "POST" \
    '{"tool": "water_all_plants"}' \
    "200" "arrosee"

run_test \
    "water_all_plants - avec params ignores -> fonctionne" \
    "tools" "POST" \
    '{"tool": "water_all_plants", "params": {"extra": "ignored"}}' \
    "200" "arrosee"

# ----------------------------------------------------------
echo ""
echo -e "${YELLOW}--- 9. LIST_ROOMS ---${NC}"
# ----------------------------------------------------------

run_test \
    "list_rooms - lister les pieces" \
    "tools" "POST" \
    '{"tool": "list_rooms"}' \
    "200" ""

run_test \
    "list_rooms - avec params ignores -> fonctionne" \
    "tools" "POST" \
    '{"tool": "list_rooms", "params": {"extra": "ignored"}}' \
    "200" ""

# ----------------------------------------------------------
echo ""
echo -e "${YELLOW}--- 10. CREATE_ROOM ---${NC}"
# ----------------------------------------------------------

run_test \
    "create_room - creer une piece 'Bureau MCP Test'" \
    "tools" "POST" \
    '{"tool": "create_room", "params": {"name": "Bureau MCP Test"}}' \
    "200" ""

run_test \
    "create_room - sans param name -> erreur" \
    "tools" "POST" \
    '{"tool": "create_room", "params": {}}' \
    "400" "required"

run_test \
    "create_room - name vide -> erreur" \
    "tools" "POST" \
    '{"tool": "create_room", "params": {"name": ""}}' \
    "400" "required"

run_test \
    "create_room - nom duplique -> erreur" \
    "tools" "POST" \
    '{"tool": "create_room", "params": {"name": "Bureau MCP Test"}}' \
    "400" "existe deja"

run_test \
    "create_room - nom tres long (200 chars)" \
    "tools" "POST" \
    "{\"tool\": \"create_room\", \"params\": {\"name\": \"$(printf 'R%.0s' {1..200})\"}}" \
    "200" ""

# ----------------------------------------------------------
echo ""
echo -e "${YELLOW}--- 11. MOVE_PLANT ---${NC}"
# ----------------------------------------------------------

run_test \
    "move_plant - deplacer 'Test MCP Plant' dans 'Bureau MCP Test'" \
    "tools" "POST" \
    '{"tool": "move_plant", "params": {"plantName": "Test MCP Plant", "roomName": "Bureau MCP Test"}}' \
    "200" "deplacee"

run_test \
    "move_plant - sans plantName -> erreur" \
    "tools" "POST" \
    '{"tool": "move_plant", "params": {"roomName": "Bureau MCP Test"}}' \
    "400" "required"

run_test \
    "move_plant - sans roomName -> erreur" \
    "tools" "POST" \
    '{"tool": "move_plant", "params": {"plantName": "Test MCP Plant"}}' \
    "400" "required"

run_test \
    "move_plant - plante inexistante -> erreur" \
    "tools" "POST" \
    '{"tool": "move_plant", "params": {"plantName": "PlanteInexistante999", "roomName": "Bureau MCP Test"}}' \
    "400" "Aucune plante"

run_test \
    "move_plant - piece inexistante -> erreur" \
    "tools" "POST" \
    '{"tool": "move_plant", "params": {"plantName": "Test MCP Plant", "roomName": "PieceInexistante999"}}' \
    "400" "Aucune piece"

run_test \
    "move_plant - params vides -> erreur" \
    "tools" "POST" \
    '{"tool": "move_plant", "params": {"plantName": "", "roomName": ""}}' \
    "400" "required"

# ----------------------------------------------------------
echo ""
echo -e "${YELLOW}--- 12. SCHEMA - NOUVEAUX OUTILS ---${NC}"
# ----------------------------------------------------------

run_test \
    "GET /mcp/schema - contient water_all_plants" \
    "schema" "GET" "" \
    "200" "water_all_plants"

run_test \
    "GET /mcp/schema - contient list_rooms" \
    "schema" "GET" "" \
    "200" "list_rooms"

run_test \
    "GET /mcp/schema - contient create_room" \
    "schema" "GET" "" \
    "200" "create_room"

run_test \
    "GET /mcp/schema - contient move_plant" \
    "schema" "GET" "" \
    "200" "move_plant"

run_test \
    "GET /mcp/schema - contient delete_plant" \
    "schema" "GET" "" \
    "200" "delete_plant"

run_test \
    "GET /mcp/schema - contient get_plant_detail" \
    "schema" "GET" "" \
    "200" "get_plant_detail"

run_test \
    "GET /mcp/schema - contient list_plants_needing_water" \
    "schema" "GET" "" \
    "200" "list_plants_needing_water"

run_test \
    "GET /mcp/schema - contient get_care_recommendation" \
    "schema" "GET" "" \
    "200" "get_care_recommendation"

run_test \
    "GET /mcp/schema - contient update_plant" \
    "schema" "GET" "" \
    "200" "update_plant"

run_test \
    "GET /mcp/schema - contient delete_room" \
    "schema" "GET" "" \
    "200" "delete_room"

# ----------------------------------------------------------
echo ""
echo -e "${YELLOW}--- 13. GET_PLANT_DETAIL ---${NC}"
# ----------------------------------------------------------

run_test \
    "get_plant_detail - detail d'une plante existante" \
    "tools" "POST" \
    '{"tool": "get_plant_detail", "params": {"plantName": "Test MCP Plant"}}' \
    "200" "Details"

run_test \
    "get_plant_detail - contient historique de soins" \
    "tools" "POST" \
    '{"tool": "get_plant_detail", "params": {"plantName": "Test MCP Plant"}}' \
    "200" "recentCareHistory"

run_test \
    "get_plant_detail - sans plantName -> erreur" \
    "tools" "POST" \
    '{"tool": "get_plant_detail", "params": {}}' \
    "400" "required"

run_test \
    "get_plant_detail - plantName vide -> erreur" \
    "tools" "POST" \
    '{"tool": "get_plant_detail", "params": {"plantName": ""}}' \
    "400" "required"

run_test \
    "get_plant_detail - plante inexistante -> erreur" \
    "tools" "POST" \
    '{"tool": "get_plant_detail", "params": {"plantName": "PlanteGhostInexistante"}}' \
    "400" "Aucune plante"

run_test \
    "get_plant_detail - recherche partielle -> fonctionne" \
    "tools" "POST" \
    '{"tool": "get_plant_detail", "params": {"plantName": "Test MCP"}}' \
    "200" ""

run_test \
    "get_plant_detail - injection SQL dans plantName -> pas de crash" \
    "tools" "POST" \
    '{"tool": "get_plant_detail", "params": {"plantName": "x OR 1=1; DROP TABLE app_user;--"}}' \
    "400" ""

# ----------------------------------------------------------
echo ""
echo -e "${YELLOW}--- 14. LIST_PLANTS_NEEDING_WATER ---${NC}"
# ----------------------------------------------------------

run_test \
    "list_plants_needing_water - succes" \
    "tools" "POST" \
    '{"tool": "list_plants_needing_water"}' \
    "200" "success"

run_test \
    "list_plants_needing_water - sans params -> fonctionne" \
    "tools" "POST" \
    '{"tool": "list_plants_needing_water", "params": null}' \
    "200" "success"

run_test \
    "list_plants_needing_water - avec params ignores -> fonctionne" \
    "tools" "POST" \
    '{"tool": "list_plants_needing_water", "params": {"hack": "true"}}' \
    "200" "success"

# ----------------------------------------------------------
echo ""
echo -e "${YELLOW}--- 15. GET_CARE_RECOMMENDATION ---${NC}"
# ----------------------------------------------------------

run_test \
    "get_care_recommendation - ficus" \
    "tools" "POST" \
    '{"tool": "get_care_recommendation", "params": {"speciesName": "ficus"}}' \
    "200" "Conseils"

run_test \
    "get_care_recommendation - orchidee" \
    "tools" "POST" \
    '{"tool": "get_care_recommendation", "params": {"speciesName": "orchidee"}}' \
    "200" "Conseils"

run_test \
    "get_care_recommendation - cactus" \
    "tools" "POST" \
    '{"tool": "get_care_recommendation", "params": {"speciesName": "cactus"}}' \
    "200" "Conseils"

run_test \
    "get_care_recommendation - aloe vera" \
    "tools" "POST" \
    '{"tool": "get_care_recommendation", "params": {"speciesName": "aloe vera"}}' \
    "200" "Conseils"

run_test \
    "get_care_recommendation - espece inconnue -> retourne valeurs par defaut" \
    "tools" "POST" \
    '{"tool": "get_care_recommendation", "params": {"speciesName": "planteinventee999"}}' \
    "200" "Conseils"

run_test \
    "get_care_recommendation - sans speciesName -> erreur" \
    "tools" "POST" \
    '{"tool": "get_care_recommendation", "params": {}}' \
    "400" "required"

run_test \
    "get_care_recommendation - speciesName vide -> erreur" \
    "tools" "POST" \
    '{"tool": "get_care_recommendation", "params": {"speciesName": ""}}' \
    "400" "required"

run_test \
    "get_care_recommendation - contient recommendedIntervalDays" \
    "tools" "POST" \
    '{"tool": "get_care_recommendation", "params": {"speciesName": "rose"}}' \
    "200" "recommendedIntervalDays"

run_test \
    "get_care_recommendation - contient sunlight" \
    "tools" "POST" \
    '{"tool": "get_care_recommendation", "params": {"speciesName": "rose"}}' \
    "200" "sunlight"

run_test \
    "get_care_recommendation - injection SQL -> pas de crash" \
    "tools" "POST" \
    '{"tool": "get_care_recommendation", "params": {"speciesName": "rose; DROP TABLE--"}}' \
    "200" ""

# ----------------------------------------------------------
echo ""
echo -e "${YELLOW}--- 16. UPDATE_PLANT ---${NC}"
# ----------------------------------------------------------

run_test \
    "update_plant - renommer une plante" \
    "tools" "POST" \
    '{"tool": "update_plant", "params": {"plantName": "Test MCP Plant", "newNickname": "Test MCP Renamed"}}' \
    "200" "mise a jour"

run_test \
    "update_plant - marquer malade" \
    "tools" "POST" \
    '{"tool": "update_plant", "params": {"plantName": "Test MCP Renamed", "isSick": "true"}}' \
    "200" "malade"

run_test \
    "update_plant - marquer non malade" \
    "tools" "POST" \
    '{"tool": "update_plant", "params": {"plantName": "Test MCP Renamed", "isSick": "false"}}' \
    "200" "non malade"

run_test \
    "update_plant - marquer fanee" \
    "tools" "POST" \
    '{"tool": "update_plant", "params": {"plantName": "Test MCP Renamed", "isWilted": "true"}}' \
    "200" "fanee"

run_test \
    "update_plant - marquer besoin rempotage" \
    "tools" "POST" \
    '{"tool": "update_plant", "params": {"plantName": "Test MCP Renamed", "needsRepotting": "true"}}' \
    "200" "rempotage"

run_test \
    "update_plant - changer intervalle arrosage" \
    "tools" "POST" \
    '{"tool": "update_plant", "params": {"plantName": "Test MCP Renamed", "wateringIntervalDays": "14"}}' \
    "200" "intervalle"

run_test \
    "update_plant - ajouter des notes" \
    "tools" "POST" \
    '{"tool": "update_plant", "params": {"plantName": "Test MCP Renamed", "notes": "Belle plante verte"}}' \
    "200" "notes"

run_test \
    "update_plant - modifications multiples en une fois" \
    "tools" "POST" \
    '{"tool": "update_plant", "params": {"plantName": "Test MCP Renamed", "isSick": "false", "isWilted": "false", "notes": "En pleine forme", "wateringIntervalDays": "7"}}' \
    "200" "mise a jour"

run_test \
    "update_plant - sans plantName -> erreur" \
    "tools" "POST" \
    '{"tool": "update_plant", "params": {"newNickname": "Test"}}' \
    "400" "required"

run_test \
    "update_plant - plantName vide -> erreur" \
    "tools" "POST" \
    '{"tool": "update_plant", "params": {"plantName": ""}}' \
    "400" "required"

run_test \
    "update_plant - plante inexistante -> erreur" \
    "tools" "POST" \
    '{"tool": "update_plant", "params": {"plantName": "PlanteInexistante999", "isSick": "true"}}' \
    "400" "Aucune plante"

run_test \
    "update_plant - sans parametre de mise a jour -> erreur" \
    "tools" "POST" \
    '{"tool": "update_plant", "params": {"plantName": "Test MCP Renamed"}}' \
    "400" "Aucun parametre"

run_test \
    "update_plant - intervalle invalide (texte) -> ignore" \
    "tools" "POST" \
    '{"tool": "update_plant", "params": {"plantName": "Test MCP Renamed", "wateringIntervalDays": "abc", "notes": "test"}}' \
    "200" ""

run_test \
    "update_plant - intervalle hors bornes (0) -> ignore, garde notes" \
    "tools" "POST" \
    '{"tool": "update_plant", "params": {"plantName": "Test MCP Renamed", "wateringIntervalDays": "0", "notes": "interval ignored"}}' \
    "200" "notes"

run_test \
    "update_plant - intervalle hors bornes (999) -> ignore, garde notes" \
    "tools" "POST" \
    '{"tool": "update_plant", "params": {"plantName": "Test MCP Renamed", "wateringIntervalDays": "999", "notes": "big interval ignored"}}' \
    "200" "notes"

run_test \
    "update_plant - isSick avec valeur non-boolean -> false" \
    "tools" "POST" \
    '{"tool": "update_plant", "params": {"plantName": "Test MCP Renamed", "isSick": "maybe"}}' \
    "200" "non malade"

run_test \
    "update_plant - injection SQL dans notes -> pas de crash" \
    "tools" "POST" \
    '{"tool": "update_plant", "params": {"plantName": "Test MCP Renamed", "notes": "test; DROP TABLE app_user;--"}}' \
    "200" "notes"

run_test \
    "update_plant - notes tres longues (1000 chars) -> tronque" \
    "tools" "POST" \
    "{\"tool\": \"update_plant\", \"params\": {\"plantName\": \"Test MCP Renamed\", \"notes\": \"$(printf 'X%.0s' {1..1000})\"}}" \
    "200" "notes"

run_test \
    "update_plant - renommer (retour au nom original)" \
    "tools" "POST" \
    '{"tool": "update_plant", "params": {"plantName": "Test MCP Renamed", "newNickname": "Test MCP Plant"}}' \
    "200" "mise a jour"

run_test \
    "update_plant - nickname tres long (200 chars) -> tronque" \
    "tools" "POST" \
    "{\"tool\": \"update_plant\", \"params\": {\"plantName\": \"Test MCP Plant\", \"newNickname\": \"$(printf 'N%.0s' {1..200})\"}}" \
    "200" "mise a jour"

run_test \
    "update_plant - restaurer le nom apres troncation" \
    "tools" "POST" \
    "{\"tool\": \"update_plant\", \"params\": {\"plantName\": \"$(printf 'N%.0s' {1..100})\", \"newNickname\": \"Test MCP Plant\"}}" \
    "200" "mise a jour"

# ----------------------------------------------------------
echo ""
echo -e "${YELLOW}--- 17. DELETE_ROOM ---${NC}"
# ----------------------------------------------------------

# D'abord creer une piece specifique pour la supprimer
run_test \
    "Preparation: creer 'Piece A Supprimer'" \
    "tools" "POST" \
    '{"tool": "create_room", "params": {"name": "Piece A Supprimer"}}' \
    "200" ""

run_test \
    "delete_room - supprimer 'Piece A Supprimer'" \
    "tools" "POST" \
    '{"tool": "delete_room", "params": {"roomName": "Piece A Supprimer"}}' \
    "200" "supprimee"

run_test \
    "delete_room - piece deja supprimee -> erreur" \
    "tools" "POST" \
    '{"tool": "delete_room", "params": {"roomName": "Piece A Supprimer"}}' \
    "400" "Aucune piece"

run_test \
    "delete_room - sans roomName -> erreur" \
    "tools" "POST" \
    '{"tool": "delete_room", "params": {}}' \
    "400" "required"

run_test \
    "delete_room - roomName vide -> erreur" \
    "tools" "POST" \
    '{"tool": "delete_room", "params": {"roomName": ""}}' \
    "400" "required"

run_test \
    "delete_room - piece inexistante -> erreur" \
    "tools" "POST" \
    '{"tool": "delete_room", "params": {"roomName": "PieceFantome999"}}' \
    "400" "Aucune piece"

# Scenario: supprimer une piece avec des plantes dedans
echo -e "  ${CYAN}Scenario: Supprimer piece avec plantes${NC}"
run_test \
    "  1. Creer piece 'Piece Avec Plantes'" \
    "tools" "POST" \
    '{"tool": "create_room", "params": {"name": "Piece Avec Plantes"}}' \
    "200" ""

run_test \
    "  2. Ajouter plante dans cette piece" \
    "tools" "POST" \
    '{"tool": "add_plant", "params": {"nickname": "Plante Orpheline Test", "roomName": "Piece Avec Plantes"}}' \
    "200" "ajoutee"

run_test \
    "  3. Supprimer la piece -> plantes orphelines" \
    "tools" "POST" \
    '{"tool": "delete_room", "params": {"roomName": "Piece Avec Plantes"}}' \
    "200" "orphan"

run_test \
    "  4. Plante toujours presente dans list_plants" \
    "tools" "POST" \
    '{"tool": "list_plants"}' \
    "200" "Plante Orpheline Test"

run_test \
    "delete_room - injection SQL -> pas de crash" \
    "tools" "POST" \
    '{"tool": "delete_room", "params": {"roomName": "x; DROP TABLE room;--"}}' \
    "400" "Aucune piece"

# ----------------------------------------------------------
echo ""
echo -e "${YELLOW}--- 18. DELETE_PLANT ---${NC}"
# ----------------------------------------------------------

# Creer une plante specifique pour la supprimer
run_test \
    "Preparation: creer 'Plante A Supprimer'" \
    "tools" "POST" \
    '{"tool": "add_plant", "params": {"nickname": "Plante A Supprimer"}}' \
    "200" "ajoutee"

run_test \
    "Preparation: arroser pour creer un care log" \
    "tools" "POST" \
    '{"tool": "water_plant", "params": {"plantName": "Plante A Supprimer"}}' \
    "200" "arrosee"

run_test \
    "delete_plant - supprimer 'Plante A Supprimer'" \
    "tools" "POST" \
    '{"tool": "delete_plant", "params": {"plantName": "Plante A Supprimer"}}' \
    "200" "supprimee"

run_test \
    "delete_plant - plante deja supprimee -> erreur" \
    "tools" "POST" \
    '{"tool": "delete_plant", "params": {"plantName": "Plante A Supprimer"}}' \
    "400" "Aucune plante"

run_test \
    "delete_plant - sans plantName -> erreur" \
    "tools" "POST" \
    '{"tool": "delete_plant", "params": {}}' \
    "400" "required"

run_test \
    "delete_plant - plantName vide -> erreur" \
    "tools" "POST" \
    '{"tool": "delete_plant", "params": {"plantName": ""}}' \
    "400" "required"

run_test \
    "delete_plant - plante inexistante -> erreur" \
    "tools" "POST" \
    '{"tool": "delete_plant", "params": {"plantName": "PlanteInexistante999"}}' \
    "400" "Aucune plante"

run_test \
    "delete_plant - injection SQL dans plantName -> pas de crash" \
    "tools" "POST" \
    '{"tool": "delete_plant", "params": {"plantName": "x; DELETE FROM user_plant;--"}}' \
    "400" "Aucune plante"

run_test \
    "delete_plant - XSS dans plantName -> pas de crash" \
    "tools" "POST" \
    '{"tool": "delete_plant", "params": {"plantName": "scriptalert1script"}}' \
    "400" "Aucune plante"

# ----------------------------------------------------------
echo ""
echo -e "${YELLOW}--- 19. SCENARIOS METIER COMPLEXES ---${NC}"
# ----------------------------------------------------------

# Scenario: creer une plante puis l'arroser
echo -e "  ${CYAN}Scenario: Creer puis arroser${NC}"
run_test \
    "  1. Creer 'Orchidee Test'" \
    "tools" "POST" \
    '{"tool": "add_plant", "params": {"nickname": "Orchidee Test", "speciesName": "orchidee"}}' \
    "200" "ajoutee"

run_test \
    "  2. Arroser 'Orchidee Test'" \
    "tools" "POST" \
    '{"tool": "water_plant", "params": {"plantName": "Orchidee Test"}}' \
    "200" "arrosee"

run_test \
    "  3. Verifier qu'elle apparait dans list_plants" \
    "tools" "POST" \
    '{"tool": "list_plants"}' \
    "200" "Orchidee Test"

# Scenario: "J'ai arrose toutes mes plantes" (exemple du sujet)
echo -e "  ${CYAN}Scenario: J'ai arrose toutes mes plantes${NC}"
run_test \
    "  1. Arroser toutes les plantes (water_all_plants)" \
    "tools" "POST" \
    '{"tool": "water_all_plants"}' \
    "200" "arrosee"

run_test \
    "  2. Verifier que les plantes sont a jour" \
    "tools" "POST" \
    '{"tool": "list_plants"}' \
    "200" "success"

# Scenario: "Ajoute cette plante dans ma chambre" (exemple du sujet)
echo -e "  ${CYAN}Scenario: Ajoute cette plante dans ma chambre${NC}"
run_test \
    "  1. Creer la piece 'Chambre MCP Test'" \
    "tools" "POST" \
    '{"tool": "create_room", "params": {"name": "Chambre MCP Test"}}' \
    "200" ""

run_test \
    "  2. Ajouter plante dans la chambre" \
    "tools" "POST" \
    '{"tool": "add_plant", "params": {"nickname": "Nouvelle Plante Achetee", "speciesName": "ficus", "roomName": "Chambre MCP Test"}}' \
    "200" "ajoutee"

run_test \
    "  3. Verifier la plante est dans la chambre" \
    "tools" "POST" \
    '{"tool": "list_plants"}' \
    "200" "Nouvelle Plante Achetee"

# Scenario: Deplacer une plante
echo -e "  ${CYAN}Scenario: Deplacer une plante entre pieces${NC}"
run_test \
    "  1. Deplacer la plante dans le bureau" \
    "tools" "POST" \
    '{"tool": "move_plant", "params": {"plantName": "Nouvelle Plante Achetee", "roomName": "Bureau MCP Test"}}' \
    "200" "deplacee"

# Scenario: enchainer plusieurs outils
echo -e "  ${CYAN}Scenario: Commandes en rafale${NC}"
run_test \
    "  1. Rechercher 'cactus'" \
    "tools" "POST" \
    '{"tool": "search_plants", "params": {"query": "cactus"}}' \
    "200" "success"

run_test \
    "  2. Ajouter un cactus" \
    "tools" "POST" \
    '{"tool": "add_plant", "params": {"nickname": "Cactus Bureau", "speciesName": "cactus"}}' \
    "200" "ajoutee"

run_test \
    "  3. Lister les plantes" \
    "tools" "POST" \
    '{"tool": "list_plants"}' \
    "200" "Cactus Bureau"

run_test \
    "  4. Arroser le cactus" \
    "tools" "POST" \
    '{"tool": "water_plant", "params": {"plantName": "Cactus Bureau"}}' \
    "200" "arrosee"

# Scenario: "Ma plante est malade, comment la soigner ?"
echo -e "  ${CYAN}Scenario: Plante malade - diagnostic et conseil${NC}"
run_test \
    "  1. Creer plante 'Basilic Malade'" \
    "tools" "POST" \
    '{"tool": "add_plant", "params": {"nickname": "Basilic Malade", "speciesName": "basilic"}}' \
    "200" "ajoutee"

run_test \
    "  2. Marquer la plante comme malade" \
    "tools" "POST" \
    '{"tool": "update_plant", "params": {"plantName": "Basilic Malade", "isSick": "true", "notes": "Feuilles jaunies"}}' \
    "200" "mise a jour"

run_test \
    "  3. Voir les details de la plante" \
    "tools" "POST" \
    '{"tool": "get_plant_detail", "params": {"plantName": "Basilic Malade"}}' \
    "200" "Details"

run_test \
    "  4. Demander des conseils pour le basilic" \
    "tools" "POST" \
    '{"tool": "get_care_recommendation", "params": {"speciesName": "basilic"}}' \
    "200" "Conseils"

run_test \
    "  5. Guerir la plante" \
    "tools" "POST" \
    '{"tool": "update_plant", "params": {"plantName": "Basilic Malade", "isSick": "false", "notes": "Traitee et en voie de guerison"}}' \
    "200" "non malade"

# Scenario: Cycle de vie complet
echo -e "  ${CYAN}Scenario: Cycle de vie complet d'une plante${NC}"
run_test \
    "  1. Rechercher espece 'lavande'" \
    "tools" "POST" \
    '{"tool": "search_plants", "params": {"query": "lavande"}}' \
    "200" "success"

run_test \
    "  2. Conseils d'entretien lavande" \
    "tools" "POST" \
    '{"tool": "get_care_recommendation", "params": {"speciesName": "lavande"}}' \
    "200" "Conseils"

run_test \
    "  3. Creer piece 'Terrasse MCP'" \
    "tools" "POST" \
    '{"tool": "create_room", "params": {"name": "Terrasse MCP"}}' \
    "200" ""

run_test \
    "  4. Ajouter lavande sur la terrasse" \
    "tools" "POST" \
    '{"tool": "add_plant", "params": {"nickname": "Ma Lavande", "speciesName": "lavande", "roomName": "Terrasse MCP"}}' \
    "200" "ajoutee"

run_test \
    "  5. Arroser la lavande" \
    "tools" "POST" \
    '{"tool": "water_plant", "params": {"plantName": "Ma Lavande"}}' \
    "200" "arrosee"

run_test \
    "  6. Voir les details" \
    "tools" "POST" \
    '{"tool": "get_plant_detail", "params": {"plantName": "Ma Lavande"}}' \
    "200" "recentCareHistory"

run_test \
    "  7. Deplacer vers le bureau" \
    "tools" "POST" \
    '{"tool": "move_plant", "params": {"plantName": "Ma Lavande", "roomName": "Bureau MCP Test"}}' \
    "200" "deplacee"

run_test \
    "  8. Marquer besoin de rempotage" \
    "tools" "POST" \
    '{"tool": "update_plant", "params": {"plantName": "Ma Lavande", "needsRepotting": "true"}}' \
    "200" "rempotage"

run_test \
    "  9. Supprimer la plante (fin de vie)" \
    "tools" "POST" \
    '{"tool": "delete_plant", "params": {"plantName": "Ma Lavande"}}' \
    "200" "supprimee"

run_test \
    "  10. Supprimer la terrasse vide" \
    "tools" "POST" \
    '{"tool": "delete_room", "params": {"roomName": "Terrasse MCP"}}' \
    "200" "supprimee"

# Scenario: Quelles plantes ont besoin d'eau ?
echo -e "  ${CYAN}Scenario: Verification arrosage global${NC}"
run_test \
    "  1. Verifier plantes a arroser" \
    "tools" "POST" \
    '{"tool": "list_plants_needing_water"}' \
    "200" "success"

run_test \
    "  2. Arroser toutes les plantes" \
    "tools" "POST" \
    '{"tool": "water_all_plants"}' \
    "200" "arrosee"

run_test \
    "  3. Reverifier (toutes arrosees)" \
    "tools" "POST" \
    '{"tool": "list_plants_needing_water"}' \
    "200" "success"

# ----------------------------------------------------------
echo ""
echo -e "${YELLOW}--- 20. CAS LIMITES / EDGE CASES ---${NC}"
# ----------------------------------------------------------

run_test \
    "Params avec cles inattendues -> ignore et fonctionne" \
    "tools" "POST" \
    '{"tool": "list_plants", "params": {"hack": "true", "admin": "true"}}' \
    "200" "success"

run_test \
    "Params avec valeurs null" \
    "tools" "POST" \
    '{"tool": "add_plant", "params": {"nickname": null, "speciesName": null}}' \
    "200" ""

run_test \
    "Caracteres unicode dans nickname" \
    "tools" "POST" \
    '{"tool": "add_plant", "params": {"nickname": "Plante avec accents eaeiu et emojis"}}' \
    "200" "ajoutee"

run_test \
    "Nickname avec espaces" \
    "tools" "POST" \
    '{"tool": "add_plant", "params": {"nickname": "   Plante Espaces   "}}' \
    "200" "ajoutee"

run_test \
    "Methode GET sur /mcp/tools -> 405 ou erreur" \
    "tools" "GET" "" \
    "405" ""

run_test \
    "JSON malformed -> erreur" \
    "tools" "POST" \
    '{"tool": "list_plants"' \
    "400" ""

run_test \
    "Body non-JSON (text brut) -> erreur" \
    "tools" "POST" \
    'je veux lister mes plantes' \
    "400" ""

run_test \
    "Tool name avec espaces -> erreur" \
    "tools" "POST" \
    '{"tool": "  list_plants  ", "params": {}}' \
    "400" "Unknown tool"

run_test \
    "Tool name en majuscules -> erreur" \
    "tools" "POST" \
    '{"tool": "LIST_PLANTS", "params": {}}' \
    "400" "Unknown tool"

run_test \
    "Tool name avec path traversal -> erreur" \
    "tools" "POST" \
    '{"tool": "../../etc/passwd", "params": {}}' \
    "400" "Unknown tool"

run_test \
    "Param avec valeur extremement longue (5000 chars)" \
    "tools" "POST" \
    "{\"tool\": \"search_plants\", \"params\": {\"query\": \"$(printf 'Z%.0s' {1..5000})\"}}" \
    "200" ""

run_test \
    "Param avec caractere null (unicode)" \
    "tools" "POST" \
    '{"tool": "search_plants", "params": {"query": "ro\u0000se"}}' \
    "200" ""

run_test \
    "Double outil dans un meme appel -> seul tool est utilise" \
    "tools" "POST" \
    '{"tool": "list_plants", "tool": "water_all_plants"}' \
    "200" ""

run_test \
    "Params avec types non-string (number) -> ignore gracieusement" \
    "tools" "POST" \
    '{"tool": "list_plants", "params": {"count": 42}}' \
    "200" "success"

# ============================================================
# Nettoyage des plantes de test
# ============================================================

echo ""
echo -e "${YELLOW}--- NETTOYAGE ---${NC}"
echo -e "  Les plantes de test creees restent en BDD."
echo -e "  Vous pouvez les supprimer manuellement si necessaire."

# ============================================================
# Resume
# ============================================================

echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}    RESULTATS                               ${NC}"
echo -e "${CYAN}============================================${NC}"
echo -e "  Total:  $TOTAL"
echo -e "  ${GREEN}Pass:   $PASS${NC}"
if [ $FAIL -gt 0 ]; then
    echo -e "  ${RED}Fail:   $FAIL${NC}"
else
    echo -e "  Fail:   0"
fi
echo ""

if [ $FAIL -gt 0 ]; then
    echo -e "  ${RED}CERTAINS TESTS ONT ECHOUE${NC}"
    exit 1
else
    echo -e "  ${GREEN}TOUS LES TESTS SONT PASSES${NC}"
    exit 0
fi
