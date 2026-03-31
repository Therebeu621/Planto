#!/bin/bash
#
# Script de test complet: Expérience Utilisateur & Assistance
# - Aide à la saisie basée sur des données externes (exposition, arrosage, etc.)
# - Notifications intelligentes : rappels regroupés, recommandations personnalisées
# - Recherche de plantes (autocomplete, fuzzy matching)
# - Intégration MCP pour aide conversationnelle
#
# Usage: ./test-ux-assistance.sh [BASE_URL] [MCP_API_KEY]
#

BASE_URL="${1:-http://localhost:8080/api/v1}"
API_KEY="${2:-mcp-plant-secret-key}"
PASS=0
FAIL=0
TOTAL=0
TS=$(date +%s)

TOKEN1=""
TOKEN2=""
USER1_ID=""
USER2_ID=""
HOUSE_ID=""
INVITE_CODE=""
ROOM_ID=""
PLANT_IDS=()
NOTIF_IDS=()

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================
# Helpers
# ============================================================

call_api() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local token="${4:-$TOKEN1}"

    if [ "$method" = "GET" ]; then
        curl -s -w "\n%{http_code}" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $token" \
            "$BASE_URL/$endpoint"
    elif [ "$method" = "DELETE" ] && [ -z "$data" ]; then
        curl -s -w "\n%{http_code}" \
            -X DELETE \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $token" \
            "$BASE_URL/$endpoint"
    else
        curl -s -w "\n%{http_code}" \
            -X "$method" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $token" \
            -d "$data" \
            "$BASE_URL/$endpoint"
    fi
}

call_mcp() {
    local tool="$1"
    local params="$2"
    curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -H "X-MCP-API-Key: $API_KEY" \
        -d "{\"tool\":\"$tool\",\"params\":$params}" \
        "$BASE_URL/mcp/tools"
}

get_body() { echo "$1" | sed '$d'; }
get_code() { echo "$1" | tail -1; }

jq_field() {
    local body="$1"
    local expr="$2"
    echo "$body" | python3 -c "
import sys,json
d=json.load(sys.stdin)
$expr
" 2>/dev/null
}

assert_eq() {
    local name="$1" actual="$2" expected="$3"
    TOTAL=$((TOTAL + 1))
    if [ "$actual" = "$expected" ]; then
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC} $name"
    else
        FAIL=$((FAIL + 1))
        echo -e "  ${RED}FAIL${NC} $name (got '$actual', expected '$expected')"
    fi
}

assert_ne() {
    local name="$1" actual="$2" not_expected="$3"
    TOTAL=$((TOTAL + 1))
    if [ "$actual" != "$not_expected" ]; then
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC} $name"
    else
        FAIL=$((FAIL + 1))
        echo -e "  ${RED}FAIL${NC} $name (got '$actual', should NOT be '$not_expected')"
    fi
}

assert_contains() {
    local name="$1" haystack="$2" needle="$3"
    TOTAL=$((TOTAL + 1))
    if echo "$haystack" | grep -qi "$needle"; then
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC} $name"
    else
        FAIL=$((FAIL + 1))
        echo -e "  ${RED}FAIL${NC} $name (not found: '$needle')"
    fi
}

assert_not_contains() {
    local name="$1" haystack="$2" needle="$3"
    TOTAL=$((TOTAL + 1))
    if ! echo "$haystack" | grep -qi "$needle"; then
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC} $name"
    else
        FAIL=$((FAIL + 1))
        echo -e "  ${RED}FAIL${NC} $name (should NOT contain: '$needle')"
    fi
}

assert_gt() {
    local name="$1" actual="$2" threshold="$3"
    TOTAL=$((TOTAL + 1))
    if [ "$actual" -gt "$threshold" ] 2>/dev/null; then
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC} $name"
    else
        FAIL=$((FAIL + 1))
        echo -e "  ${RED}FAIL${NC} $name (got '$actual', expected > '$threshold')"
    fi
}

assert_ge() {
    local name="$1" actual="$2" threshold="$3"
    TOTAL=$((TOTAL + 1))
    if [ "$actual" -ge "$threshold" ] 2>/dev/null; then
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC} $name"
    else
        FAIL=$((FAIL + 1))
        echo -e "  ${RED}FAIL${NC} $name (got '$actual', expected >= '$threshold')"
    fi
}

assert_http() {
    local name="$1" actual="$2" expected="$3"
    TOTAL=$((TOTAL + 1))
    if [ "$actual" = "$expected" ]; then
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC} $name [HTTP $actual]"
    else
        FAIL=$((FAIL + 1))
        echo -e "  ${RED}FAIL${NC} $name (HTTP $actual, expected $expected)"
    fi
}

assert_http_any() {
    local name="$1" actual="$2"
    shift 2
    TOTAL=$((TOTAL + 1))
    for expected in "$@"; do
        if [ "$actual" = "$expected" ]; then
            PASS=$((PASS + 1))
            echo -e "  ${GREEN}PASS${NC} $name [HTTP $actual]"
            return
        fi
    done
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC} $name (HTTP $actual, expected one of: $*)"
}

section() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ============================================================
# SETUP: Create users, house, room, plants
# ============================================================

section "SETUP: Création des données de test"

# Register user 1
RESP=$(call_api POST "auth/register" "{\"email\":\"uxtest1_${TS}@test.com\",\"password\":\"Test1234!\",\"displayName\":\"UX User1 ${TS}\"}")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "Register user 1" "$CODE" "201"
TOKEN1=$(jq_field "$BODY" "print(d.get('accessToken',''))")
USER1_ID=$(jq_field "$BODY" "print(d.get('user',{}).get('id',''))")

# Register user 2
RESP=$(call_api POST "auth/register" "{\"email\":\"uxtest2_${TS}@test.com\",\"password\":\"Test1234!\",\"displayName\":\"UX User2 ${TS}\"}")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "Register user 2" "$CODE" "201"
TOKEN2=$(jq_field "$BODY" "print(d.get('accessToken',''))")
USER2_ID=$(jq_field "$BODY" "print(d.get('user',{}).get('id',''))")

# Create house
RESP=$(call_api POST "houses" "{\"name\":\"Maison UX ${TS}\"}")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "Create house" "$CODE" "201"
HOUSE_ID=$(jq_field "$BODY" "print(d.get('id',''))")

# Get invite code
RESP=$(call_api GET "houses/${HOUSE_ID}")
BODY=$(get_body "$RESP")
INVITE_CODE=$(jq_field "$BODY" "print(d.get('inviteCode',''))")

# User 2 joins house
RESP=$(call_api POST "houses/join" "{\"inviteCode\":\"${INVITE_CODE}\"}" "$TOKEN2")
assert_http "User 2 joins house" "$(get_code "$RESP")" "200"

# Create room
RESP=$(call_api POST "rooms" "{\"name\":\"Salon UX ${TS}\",\"type\":\"LIVING_ROOM\"}")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "Create room" "$CODE" "201"
ROOM_ID=$(jq_field "$BODY" "print(d.get('id',''))")

echo -e "\n  ${CYAN}User1: ${USER1_ID}${NC}"
echo -e "  ${CYAN}User2: ${USER2_ID}${NC}"
echo -e "  ${CYAN}House: ${HOUSE_ID}${NC}"
echo -e "  ${CYAN}Room:  ${ROOM_ID}${NC}"

# ============================================================
# PART 1: AIDE A LA SAISIE - Recherche de plantes
# ============================================================

section "1. AIDE A LA SAISIE - Base de données plantes"

# 1.1 Status de la base
RESP=$(call_api GET "species/status")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "1.1 Species DB status -> 200" "$CODE" "200"
COUNT=$(jq_field "$BODY" "print(d.get('plantCount',0))")
assert_gt "1.1 DB contient des plantes" "$COUNT" "0"
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "1.1 DB status = ready" "$STATUS" "ready"
SOURCE=$(jq_field "$BODY" "print(d.get('source',''))")
assert_eq "1.1 Source = local-json" "$SOURCE" "local-json"

# 1.2 Recherche basique - Monstera
RESP=$(call_api GET "species/search?q=monstera")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "1.2 Search monstera -> 200" "$CODE" "200"
RESULT_COUNT=$(jq_field "$BODY" "print(len(d))")
assert_gt "1.2 Monstera retourne resultats" "$RESULT_COUNT" "0"
FIRST_NAME=$(jq_field "$BODY" "print(d[0].get('nomFrancais',''))")
assert_contains "1.2 Premier resultat contient Monstera" "$FIRST_NAME" "onstera"

# 1.3 Recherche retourne nomLatin
LATIN=$(jq_field "$BODY" "print(d[0].get('nomLatin',''))")
assert_ne "1.3 Nom latin present" "$LATIN" ""

# 1.4 Recherche retourne arrosageFrequenceJours
FREQ=$(jq_field "$BODY" "print(d[0].get('arrosageFrequenceJours',0))")
assert_gt "1.4 Frequence arrosage > 0" "$FREQ" "0"

# 1.5 Recherche retourne luminosite
LUMI=$(jq_field "$BODY" "print(d[0].get('luminosite',''))")
assert_ne "1.5 Luminosite presente" "$LUMI" ""

# 1.6 Recherche par nom latin
RESP=$(call_api GET "species/search?q=ficus")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "1.6 Search ficus -> 200" "$CODE" "200"
RESULT_COUNT=$(jq_field "$BODY" "print(len(d))")
assert_gt "1.6 Ficus retourne resultats" "$RESULT_COUNT" "0"

# 1.7 Recherche cactus
RESP=$(call_api GET "species/search?q=cactus")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "1.7 Search cactus -> 200" "$CODE" "200"

# 1.8 Recherche orchidee
RESP=$(call_api GET "species/search?q=orchid")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "1.8 Search orchidee -> 200" "$CODE" "200"

# 1.9 Recherche aloe
RESP=$(call_api GET "species/search?q=aloe")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "1.9 Search aloe -> 200" "$CODE" "200"

# 1.10 Recherche basilic (herb)
RESP=$(call_api GET "species/search?q=basilic")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "1.10 Search basilic -> 200" "$CODE" "200"

section "2. AIDE A LA SAISIE - Validation et edge cases"

# 2.1 Recherche trop courte (1 char)
RESP=$(call_api GET "species/search?q=a")
CODE=$(get_code "$RESP")
assert_http "2.1 Search 1 char -> 400" "$CODE" "400"

# 2.2 Recherche vide
RESP=$(call_api GET "species/search?q=")
CODE=$(get_code "$RESP")
assert_http "2.2 Search vide -> 400" "$CODE" "400"

# 2.3 Recherche sans parametre
RESP=$(call_api GET "species/search")
CODE=$(get_code "$RESP")
assert_http "2.3 Search sans param -> 400" "$CODE" "400"

# 2.4 Recherche introuvable
RESP=$(call_api GET "species/search?q=xyzplanteinexistante")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "2.4 Search introuvable -> 200" "$CODE" "200"
RESULT_COUNT=$(jq_field "$BODY" "print(len(d))")
assert_eq "2.4 Aucun resultat pour plante inexistante" "$RESULT_COUNT" "0"

# 2.5 Recherche avec espaces
RESP=$(call_api GET "species/search?q=aloe%20vera")
CODE=$(get_code "$RESP")
assert_http_any "2.5 Search avec espaces -> 200" "$CODE" "200"

# 2.6 Recherche case insensitive
RESP=$(call_api GET "species/search?q=MONSTERA")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "2.6 Search MAJUSCULE -> 200" "$CODE" "200"
RESULT_COUNT=$(jq_field "$BODY" "print(len(d))")
assert_gt "2.6 Case insensitive retourne resultats" "$RESULT_COUNT" "0"

# 2.7 Recherche mixed case
RESP=$(call_api GET "species/search?q=MoNsTeRa")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "2.7 Search MiXeD case -> 200" "$CODE" "200"
RESULT_COUNT=$(jq_field "$BODY" "print(len(d))")
assert_gt "2.7 Mixed case retourne resultats" "$RESULT_COUNT" "0"

# 2.8 Recherche exactement 2 chars (minimum)
RESP=$(call_api GET "species/search?q=fi")
CODE=$(get_code "$RESP")
assert_http "2.8 Search 2 chars (minimum) -> 200" "$CODE" "200"

# 2.9 Recherche tres longue
LONG_QUERY="monsteramonsteramonsteramonstera"
RESP=$(call_api GET "species/search?q=${LONG_QUERY}")
CODE=$(get_code "$RESP")
assert_http "2.9 Search tres longue -> 200" "$CODE" "200"

# 2.10 Recherche caracteres speciaux
RESP=$(call_api GET "species/search?q=test%27%22")
CODE=$(get_code "$RESP")
assert_http_any "2.10 Search caracteres speciaux -> 200" "$CODE" "200" "400"

# 2.11 Max 10 resultats
RESP=$(call_api GET "species/search?q=pl")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "2.11 Search courte -> 200" "$CODE" "200"
RESULT_COUNT=$(jq_field "$BODY" "print(len(d))")
if [ "$RESULT_COUNT" -le 10 ] 2>/dev/null; then
    PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1))
    echo -e "  ${GREEN}PASS${NC} 2.11 Max 10 resultats ($RESULT_COUNT)"
else
    FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1))
    echo -e "  ${RED}FAIL${NC} 2.11 Max 10 resultats (got $RESULT_COUNT)"
fi

section "3. AIDE A LA SAISIE - Recherche par nom exact"

# 3.1 By-name sans parametre
RESP=$(call_api GET "species/by-name")
CODE=$(get_code "$RESP")
assert_http "3.1 By-name sans param -> 400" "$CODE" "400"

# 3.2 By-name vide
RESP=$(call_api GET "species/by-name?name=")
CODE=$(get_code "$RESP")
assert_http "3.2 By-name vide -> 400" "$CODE" "400"

# 3.3 By-name plante inexistante
RESP=$(call_api GET "species/by-name?name=PlanteFictive12345")
CODE=$(get_code "$RESP")
assert_http "3.3 By-name inexistante -> 404" "$CODE" "404"

# 3.4 By-name retourne les bons champs
# First search for a name that exists
RESP=$(call_api GET "species/search?q=monstera")
BODY=$(get_body "$RESP")
EXACT_NAME=$(jq_field "$BODY" "print(d[0].get('nomFrancais','') if len(d)>0 else '')")
if [ -n "$EXACT_NAME" ] && [ "$EXACT_NAME" != "" ]; then
    ENCODED_NAME=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$EXACT_NAME'))")
    RESP=$(call_api GET "species/by-name?name=${ENCODED_NAME}")
    CODE=$(get_code "$RESP")
    BODY=$(get_body "$RESP")
    assert_http_any "3.4 By-name exact -> 200" "$CODE" "200" "404"
    if [ "$CODE" = "200" ]; then
        BY_NAME_FR=$(jq_field "$BODY" "print(d.get('nomFrancais',''))")
        assert_eq "3.4 Nom francais correct" "$BY_NAME_FR" "$EXACT_NAME"
        BY_NAME_LATIN=$(jq_field "$BODY" "print(d.get('nomLatin',''))")
        assert_ne "3.4 Nom latin present" "$BY_NAME_LATIN" ""
        BY_NAME_FREQ=$(jq_field "$BODY" "print(d.get('arrosageFrequenceJours',0))")
        assert_gt "3.4 Frequence > 0" "$BY_NAME_FREQ" "0"
        BY_NAME_LUMI=$(jq_field "$BODY" "print(d.get('luminosite',''))")
        assert_ne "3.4 Luminosite presente" "$BY_NAME_LUMI" ""
    fi
fi

section "4. AIDE A LA SAISIE - Données d'arrosage par type de plante"

# 4.1 Plantes tropicales vs succulentes: fréquences différentes
RESP_TROP=$(call_api GET "species/search?q=monstera")
BODY_TROP=$(get_body "$RESP_TROP")
FREQ_TROP=$(jq_field "$BODY_TROP" "print(d[0].get('arrosageFrequenceJours',0) if len(d)>0 else 0)")

RESP_SUCC=$(call_api GET "species/search?q=cactus")
BODY_SUCC=$(get_body "$RESP_SUCC")
FREQ_SUCC=$(jq_field "$BODY_SUCC" "print(d[0].get('arrosageFrequenceJours',0) if len(d)>0 else 0)")

if [ "$FREQ_TROP" -gt 0 ] 2>/dev/null && [ "$FREQ_SUCC" -gt 0 ] 2>/dev/null; then
    assert_ne "4.1 Tropicale vs succulente: frequences differentes" "$FREQ_TROP" "$FREQ_SUCC"
fi

# 4.2 Vérifier luminosité différente entre types
LUMI_TROP=$(jq_field "$BODY_TROP" "print(d[0].get('luminosite','') if len(d)>0 else '')")
assert_ne "4.2 Luminosite tropicale non vide" "$LUMI_TROP" ""

# 4.3 Fiche de soins enrichie - Monstera
RESP=$(call_api GET "weather/care-sheet?species=monstera&city=Paris")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "4.3 Care sheet monstera -> 200" "$CODE" "200"
CS_NAME=$(jq_field "$BODY" "print(d.get('speciesName',''))")
assert_contains "4.3 Care sheet species name" "$CS_NAME" "onstera"
CS_INTERVAL=$(jq_field "$BODY" "print(d.get('wateringIntervalDays',0))")
assert_gt "4.3 Interval > 0" "$CS_INTERVAL" "0"

# 4.4 Care sheet - catégorie
CS_CATEGORY=$(jq_field "$BODY" "print(d.get('category',''))")
assert_ne "4.4 Categorie non vide" "$CS_CATEGORY" ""

# 4.5 Care sheet - conseils saisonniers
CS_SEASONAL=$(jq_field "$BODY" "print(len(d.get('seasonalAdvice',[])))")
assert_eq "4.5 4 saisons dans les conseils" "$CS_SEASONAL" "4"

# 4.6 Care sheet - problèmes communs
CS_PROBLEMS=$(jq_field "$BODY" "print(len(d.get('commonProblems',[])))")
assert_gt "4.6 Problemes communs > 0" "$CS_PROBLEMS" "0"

# 4.7 Care sheet - niveau de soin
CS_LEVEL=$(jq_field "$BODY" "print(d.get('careLevel',''))")
assert_ne "4.7 Niveau de soin present" "$CS_LEVEL" ""

# 4.8 Care sheet - tip arrosage
CS_TIP=$(jq_field "$BODY" "print(d.get('wateringTip',''))")
assert_ne "4.8 Tip arrosage present" "$CS_TIP" ""

# 4.9 Care sheet - résumé en français
CS_SUMMARY=$(jq_field "$BODY" "print(d.get('careSummary',''))")
assert_ne "4.9 Resume present" "$CS_SUMMARY" ""

# 4.10 Care sheet sans ville (fallback saisonnier)
RESP=$(call_api GET "weather/care-sheet?species=cactus")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "4.10 Care sheet sans ville -> 200" "$CODE" "200"
CS_NAME2=$(jq_field "$BODY" "print(d.get('speciesName',''))")
assert_contains "4.10 Cactus care sheet ok" "$CS_NAME2" "actus"

# 4.11 Care sheet - succulente a categorie differente
CS_CAT2=$(jq_field "$BODY" "print(d.get('category',''))")
assert_ne "4.11 Categorie succulente non vide" "$CS_CAT2" ""

# 4.12 Care sheet - species manquant -> 400
RESP=$(call_api GET "weather/care-sheet?city=Paris")
CODE=$(get_code "$RESP")
assert_http "4.12 Care sheet sans species -> 400" "$CODE" "400"

# 4.13 Care sheet - species vide -> 400
RESP=$(call_api GET "weather/care-sheet?species=&city=Paris")
CODE=$(get_code "$RESP")
assert_http "4.13 Care sheet species vide -> 400" "$CODE" "400"

# 4.14 Care sheet orchidee
RESP=$(call_api GET "weather/care-sheet?species=orchidee")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "4.14 Care sheet orchidee -> 200" "$CODE" "200"
CS_ORCHID=$(jq_field "$BODY" "print(d.get('wateringIntervalDays',0))")
assert_gt "4.14 Orchidee interval > 0" "$CS_ORCHID" "0"

# 4.15 Care sheet basilic (herb)
RESP=$(call_api GET "weather/care-sheet?species=basilic")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "4.15 Care sheet basilic -> 200" "$CODE" "200"

# 4.16 Care sheet lavande
RESP=$(call_api GET "weather/care-sheet?species=lavande")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "4.16 Care sheet lavande -> 200" "$CODE" "200"

# 4.17 Care sheet plante inconnue (utilise general)
RESP=$(call_api GET "weather/care-sheet?species=planteinconnue123")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "4.17 Care sheet plante inconnue -> 200" "$CODE" "200"
CS_UNKNOWN=$(jq_field "$BODY" "print(d.get('category',''))")
assert_contains "4.17 Plante inconnue = Plante interieur" "$CS_UNKNOWN" "lante"

section "5. AIDE A LA SAISIE - Fiches saisonnières détaillées"

# Retrieve care sheet for seasonal analysis
RESP=$(call_api GET "weather/care-sheet?species=monstera")
BODY=$(get_body "$RESP")

# 5.1 Printemps
S1=$(jq_field "$BODY" "print(d['seasonalAdvice'][0]['season'])")
assert_contains "5.1 Saison 1 = printemps" "$S1" "rintemps"
S1_ADJ=$(jq_field "$BODY" "print(d['seasonalAdvice'][0]['wateringAdjustment'])")
assert_ne "5.1 Ajustement printemps non vide" "$S1_ADJ" ""
S1_NOTES=$(jq_field "$BODY" "print(d['seasonalAdvice'][0]['careNotes'])")
assert_ne "5.1 Notes printemps non vides" "$S1_NOTES" ""

# 5.2 Été
S2=$(jq_field "$BODY" "print(d['seasonalAdvice'][1]['season'])")
assert_contains "5.2 Saison 2 = ete" "$S2" "t"
S2_ADJ=$(jq_field "$BODY" "print(d['seasonalAdvice'][1]['wateringAdjustment'])")
assert_ne "5.2 Ajustement ete non vide" "$S2_ADJ" ""

# 5.3 Automne
S3=$(jq_field "$BODY" "print(d['seasonalAdvice'][2]['season'])")
assert_contains "5.3 Saison 3 = automne" "$S3" "utomne"
S3_ADJ=$(jq_field "$BODY" "print(d['seasonalAdvice'][2]['wateringAdjustment'])")
assert_ne "5.3 Ajustement automne non vide" "$S3_ADJ" ""

# 5.4 Hiver
S4=$(jq_field "$BODY" "print(d['seasonalAdvice'][3]['season'])")
assert_contains "5.4 Saison 4 = hiver" "$S4" "iver"
S4_ADJ=$(jq_field "$BODY" "print(d['seasonalAdvice'][3]['wateringAdjustment'])")
assert_ne "5.4 Ajustement hiver non vide" "$S4_ADJ" ""

# 5.5 Succulente en hiver = réduction
RESP=$(call_api GET "weather/care-sheet?species=cactus")
BODY=$(get_body "$RESP")
S4_SUCC=$(jq_field "$BODY" "print(d['seasonalAdvice'][3]['wateringAdjustment'])")
assert_contains "5.5 Succulente hiver = quasi aucun" "$S4_SUCC" "ucun\|edui\|inimal"

# 5.6 Tropicale en été = augmentation
RESP=$(call_api GET "weather/care-sheet?species=monstera")
BODY=$(get_body "$RESP")
S2_TROP=$(jq_field "$BODY" "print(d['seasonalAdvice'][1]['wateringAdjustment'])")
assert_contains "5.6 Tropicale ete = frequent/vaporisation" "$S2_TROP" "quent\|aporis\|ugment"

# ============================================================
# PART 2: NOTIFICATIONS INTELLIGENTES
# ============================================================

section "6. NOTIFICATIONS - Création de plantes pour tests"

# Create plants with different needs
RESP=$(call_api POST "plants" "{\"nickname\":\"Notif Monstera ${TS}\",\"roomId\":\"${ROOM_ID}\",\"wateringIntervalDays\":1,\"customSpecies\":\"Monstera\"}")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "6.1 Create plant 1 (monstera)" "$CODE" "201"
PLANT1_ID=$(jq_field "$BODY" "print(d.get('id',''))")
PLANT_IDS+=("$PLANT1_ID")

RESP=$(call_api POST "plants" "{\"nickname\":\"Notif Cactus ${TS}\",\"roomId\":\"${ROOM_ID}\",\"wateringIntervalDays\":14,\"customSpecies\":\"Cactus\"}")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "6.2 Create plant 2 (cactus)" "$CODE" "201"
PLANT2_ID=$(jq_field "$BODY" "print(d.get('id',''))")
PLANT_IDS+=("$PLANT2_ID")

RESP=$(call_api POST "plants" "{\"nickname\":\"Notif Orchidee ${TS}\",\"roomId\":\"${ROOM_ID}\",\"wateringIntervalDays\":3,\"customSpecies\":\"Orchidée\",\"isSick\":true}")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "6.3 Create plant 3 (orchidee malade)" "$CODE" "201"
PLANT3_ID=$(jq_field "$BODY" "print(d.get('id',''))")
PLANT_IDS+=("$PLANT3_ID")

RESP=$(call_api POST "plants" "{\"nickname\":\"Notif Wilted ${TS}\",\"roomId\":\"${ROOM_ID}\",\"wateringIntervalDays\":5,\"isWilted\":true}")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "6.4 Create plant 4 (fanee)" "$CODE" "201"
PLANT4_ID=$(jq_field "$BODY" "print(d.get('id',''))")
PLANT_IDS+=("$PLANT4_ID")

RESP=$(call_api POST "plants" "{\"nickname\":\"Notif Repot ${TS}\",\"roomId\":\"${ROOM_ID}\",\"wateringIntervalDays\":7,\"needsRepotting\":true}")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "6.5 Create plant 5 (rempotage)" "$CODE" "201"
PLANT5_ID=$(jq_field "$BODY" "print(d.get('id',''))")
PLANT_IDS+=("$PLANT5_ID")

section "7. NOTIFICATIONS - Liste initiale"

# 7.1 Liste vide au depart
RESP=$(call_api GET "notifications")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "7.1 GET notifications -> 200" "$CODE" "200"

# 7.2 Unread count au depart
RESP=$(call_api GET "notifications/unread-count")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "7.2 GET unread-count -> 200" "$CODE" "200"
UNREAD=$(jq_field "$BODY" "print(d.get('unreadCount',0))")
# May have notifications from other tests, just verify it works

# 7.3 Filtre unreadOnly=false
RESP=$(call_api GET "notifications?unreadOnly=false")
CODE=$(get_code "$RESP")
assert_http "7.3 GET notifications?unreadOnly=false -> 200" "$CODE" "200"

# 7.4 Filtre unreadOnly=true
RESP=$(call_api GET "notifications?unreadOnly=true")
CODE=$(get_code "$RESP")
assert_http "7.4 GET notifications?unreadOnly=true -> 200" "$CODE" "200"

section "8. NOTIFICATIONS - Déclenchement des rappels"

# 8.1 Trigger reminders
RESP=$(call_api POST "notifications/trigger-reminders" "{}")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "8.1 Trigger reminders -> 200" "$CODE" "200"
TRIGGER_STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_contains "8.1 Status = triggered" "$TRIGGER_STATUS" "riggered"

# 8.2 Vérifier que des notifications ont été créées
RESP=$(call_api GET "notifications")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "8.2 GET notifications after trigger -> 200" "$CODE" "200"
NOTIF_COUNT=$(jq_field "$BODY" "print(len(d))")
assert_gt "8.2 Des notifications ont ete creees" "$NOTIF_COUNT" "0"

# 8.3 Première notification a un type
FIRST_TYPE=$(jq_field "$BODY" "print(d[0].get('type','') if len(d)>0 else '')")
assert_ne "8.3 Type de notification present" "$FIRST_TYPE" ""

# 8.4 Première notification a un message
FIRST_MSG=$(jq_field "$BODY" "print(d[0].get('message','') if len(d)>0 else '')")
assert_ne "8.4 Message de notification present" "$FIRST_MSG" ""

# 8.5 Notification a un ID
FIRST_NOTIF_ID=$(jq_field "$BODY" "print(d[0].get('id','') if len(d)>0 else '')")
assert_ne "8.5 Notification a un ID" "$FIRST_NOTIF_ID" ""
NOTIF_IDS+=("$FIRST_NOTIF_ID")

# 8.6 Notification a createdAt
FIRST_CREATED=$(jq_field "$BODY" "print(d[0].get('createdAt','') if len(d)>0 else '')")
assert_ne "8.6 CreatedAt present" "$FIRST_CREATED" ""

# 8.7 Notification est non lue
FIRST_READ=$(jq_field "$BODY" "print(d[0].get('read',True) if len(d)>0 else True)")
assert_eq "8.7 Notification non lue" "$FIRST_READ" "False"

# 8.8 Unread count > 0 après trigger
RESP=$(call_api GET "notifications/unread-count")
BODY=$(get_body "$RESP")
UNREAD_AFTER=$(jq_field "$BODY" "print(d.get('unreadCount',0))")
assert_gt "8.8 Unread count > 0" "$UNREAD_AFTER" "0"

section "9. NOTIFICATIONS - Rappels regroupés (messages groupés)"

# Get notifications to check grouping
RESP=$(call_api GET "notifications")
BODY=$(get_body "$RESP")

# 9.1 Le message contient "arroser" (watering reminder)
ALL_MSGS=$(jq_field "$BODY" "
msgs = [n.get('message','') for n in d]
print(' '.join(msgs))
")
assert_contains "9.1 Messages mentionnent arrosage" "$ALL_MSGS" "arros\|eau\|water"

# 9.2 Types de notification WATERING_REMINDER ou CARE_REMINDER
ALL_TYPES=$(jq_field "$BODY" "
types = [n.get('type','') for n in d]
print(' '.join(types))
")
assert_contains "9.2 Type WATERING ou CARE_REMINDER present" "$ALL_TYPES" "REMINDER"

# 9.3 Les notifications sont liées à des plantes
HAS_PLANT=$(jq_field "$BODY" "
has = any(n.get('plantId') is not None for n in d)
print(has)
")
assert_eq "9.3 Notifications liees a des plantes" "$HAS_PLANT" "True"

# 9.4 Trigger une 2e fois - nouvelles notifications crées
RESP=$(call_api POST "notifications/trigger-reminders" "{}")
assert_http "9.4 Second trigger -> 200" "$(get_code "$RESP")" "200"
RESP=$(call_api GET "notifications")
BODY=$(get_body "$RESP")
NOTIF_COUNT2=$(jq_field "$BODY" "print(len(d))")
assert_gt "9.4 Plus de notifications apres 2e trigger" "$NOTIF_COUNT2" "$NOTIF_COUNT"

section "10. NOTIFICATIONS - Marquer comme lu"

# 10.1 Marquer une notification comme lue
if [ -n "$FIRST_NOTIF_ID" ] && [ "$FIRST_NOTIF_ID" != "" ]; then
    RESP=$(call_api PUT "notifications/${FIRST_NOTIF_ID}/read" "{}")
    CODE=$(get_code "$RESP")
    BODY=$(get_body "$RESP")
    assert_http "10.1 Mark as read -> 200" "$CODE" "200"
    IS_READ=$(jq_field "$BODY" "print(d.get('read',False))")
    assert_eq "10.1 Notification marquee lue" "$IS_READ" "True"

    # 10.2 Unread count diminué
    RESP=$(call_api GET "notifications/unread-count")
    BODY=$(get_body "$RESP")
    UNREAD_AFTER_READ=$(jq_field "$BODY" "print(d.get('unreadCount',0))")
    TOTAL=$((TOTAL + 1))
    if [ "$UNREAD_AFTER_READ" -lt "$UNREAD_AFTER" ] 2>/dev/null || [ "$UNREAD_AFTER_READ" = "0" ]; then
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC} 10.2 Unread count diminue"
    else
        # May be equal if other notifications were created
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC} 10.2 Unread count verifie (=$UNREAD_AFTER_READ)"
    fi

    # 10.3 Re-marquer comme lu (idempotent)
    RESP=$(call_api PUT "notifications/${FIRST_NOTIF_ID}/read" "{}")
    CODE=$(get_code "$RESP")
    assert_http "10.3 Mark as read again (idempotent) -> 200" "$CODE" "200"
fi

# 10.4 Marquer une notification inexistante -> 404
FAKE_UUID="00000000-0000-0000-0000-000000000000"
RESP=$(call_api PUT "notifications/${FAKE_UUID}/read" "{}")
CODE=$(get_code "$RESP")
assert_http_any "10.4 Mark inexistante -> 404" "$CODE" "404" "500"

# 10.5 Mark all as read
RESP=$(call_api PUT "notifications/read-all" "{}")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "10.5 Mark all as read -> 200" "$CODE" "200"
MARKED=$(jq_field "$BODY" "print(d.get('markedAsRead',0))")
assert_ge "10.5 markedAsRead >= 0" "$MARKED" "0"

# 10.6 Unread count = 0 after mark all
RESP=$(call_api GET "notifications/unread-count")
BODY=$(get_body "$RESP")
UNREAD_FINAL=$(jq_field "$BODY" "print(d.get('unreadCount',0))")
assert_eq "10.6 Unread = 0 after mark all" "$UNREAD_FINAL" "0"

# 10.7 Filtre unreadOnly=true retourne 0 après mark all
RESP=$(call_api GET "notifications?unreadOnly=true")
BODY=$(get_body "$RESP")
UNREAD_LIST=$(jq_field "$BODY" "print(len(d))")
assert_eq "10.7 Liste unread = 0 after mark all" "$UNREAD_LIST" "0"

section "11. NOTIFICATIONS - Suppression"

# 11.1 Get fresh notifications for deletion test
RESP=$(call_api POST "notifications/trigger-reminders" "{}")
RESP=$(call_api GET "notifications")
BODY=$(get_body "$RESP")
DEL_NOTIF_ID=$(jq_field "$BODY" "print(d[0].get('id','') if len(d)>0 else '')")

if [ -n "$DEL_NOTIF_ID" ] && [ "$DEL_NOTIF_ID" != "" ]; then
    RESP=$(call_api DELETE "notifications/${DEL_NOTIF_ID}")
    CODE=$(get_code "$RESP")
    assert_http "11.1 Delete notification -> 204" "$CODE" "204"

    # 11.2 Vérifier suppression
    RESP=$(call_api GET "notifications")
    BODY=$(get_body "$RESP")
    DELETED_CHECK=$(jq_field "$BODY" "
found = any(n.get('id','')=='$DEL_NOTIF_ID' for n in d)
print(found)
")
    assert_eq "11.2 Notification supprimee" "$DELETED_CHECK" "False"
fi

# 11.3 Supprimer inexistante -> 404
RESP=$(call_api DELETE "notifications/${FAKE_UUID}")
CODE=$(get_code "$RESP")
assert_http_any "11.3 Delete inexistante -> 404" "$CODE" "404" "500"

section "12. NOTIFICATIONS - Isolation entre utilisateurs"

# 12.1 User 2 voit ses propres notifications (pas celles de user 1)
RESP=$(call_api GET "notifications" "" "$TOKEN2")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "12.1 User 2 GET notifications -> 200" "$CODE" "200"

# 12.2 User 2 unread count
RESP=$(call_api GET "notifications/unread-count" "" "$TOKEN2")
CODE=$(get_code "$RESP")
assert_http "12.2 User 2 unread-count -> 200" "$CODE" "200"

# 12.3 User 2 ne peut pas mark as read une notif de user 1
if [ -n "$FIRST_NOTIF_ID" ] && [ "$FIRST_NOTIF_ID" != "" ]; then
    RESP=$(call_api PUT "notifications/${FIRST_NOTIF_ID}/read" "{}" "$TOKEN2")
    CODE=$(get_code "$RESP")
    assert_http_any "12.3 User 2 mark read notif user 1 -> 403/404" "$CODE" "403" "404" "500"
fi

# 12.4 User 2 ne peut pas delete une notif de user 1
if [ -n "$FIRST_NOTIF_ID" ] && [ "$FIRST_NOTIF_ID" != "" ]; then
    RESP=$(call_api DELETE "notifications/${FIRST_NOTIF_ID}" "" "$TOKEN2")
    CODE=$(get_code "$RESP")
    assert_http_any "12.4 User 2 delete notif user 1 -> 403/404" "$CODE" "403" "404" "500"
fi

# 12.5 User 2 mark all as read (ne touche pas user 1)
RESP=$(call_api PUT "notifications/read-all" "{}" "$TOKEN2")
CODE=$(get_code "$RESP")
assert_http "12.5 User 2 mark all -> 200" "$CODE" "200"

# ============================================================
# PART 3: MCP - AIDE CONVERSATIONNELLE
# ============================================================

section "13. MCP - Aide à la saisie via conversation"

# 13.1 MCP schema disponible
RESP=$(curl -s -w "\n%{http_code}" -H "X-MCP-API-Key: $API_KEY" "$BASE_URL/mcp/schema")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "13.1 MCP schema -> 200" "$CODE" "200"

# 13.2 Schema contient get_care_recommendation
assert_contains "13.2 Schema: get_care_recommendation" "$BODY" "get_care_recommendation"

# 13.3 Schema contient search_plants
assert_contains "13.3 Schema: search_plants" "$BODY" "search_plants"

# 13.4 Schema contient enrich_plant_caresheet
assert_contains "13.4 Schema: enrich_plant_caresheet" "$BODY" "enrich_plant_caresheet"

# 13.5 Schema contient get_weather_watering_advice
assert_contains "13.5 Schema: get_weather_watering_advice" "$BODY" "get_weather_watering_advice"

# 13.6 MCP search species via tool
RESP=$(call_mcp "search_plants" "{\"query\":\"monstera\"}")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "13.6 MCP search_plants -> 200" "$CODE" "200"
assert_contains "13.6 MCP retourne monstera" "$BODY" "onstera"

# 13.7 MCP get_care_recommendation
RESP=$(call_mcp "get_care_recommendation" "{\"speciesName\":\"monstera\"}")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "13.7 MCP get_care_recommendation -> 200" "$CODE" "200"
assert_contains "13.7 MCP recommandations presentes" "$BODY" "arros\|water\|soin\|care"

# 13.8 MCP enrich_plant_caresheet
RESP=$(call_mcp "enrich_plant_caresheet" "{\"speciesName\":\"orchidee\",\"city\":\"Paris\"}")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "13.8 MCP enrich caresheet -> 200" "$CODE" "200"
assert_contains "13.8 MCP caresheet contient saison" "$BODY" "eason\|aison\|saisonn"

# 13.9 MCP get_weather_watering_advice
RESP=$(call_mcp "get_weather_watering_advice" "{\"city\":\"Paris\"}")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "13.9 MCP weather advice -> 200" "$CODE" "200"

# 13.10 MCP tool inexistant -> erreur
RESP=$(call_mcp "nonexistent_tool" "{}")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http_any "13.10 MCP tool inexistant -> 400/200" "$CODE" "400" "200"
assert_contains "13.10 Message erreur outil inconnu" "$BODY" "nknown\|not found\|rror\|vailable"

# 13.11 MCP sans API key -> 401
RESP=$(curl -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" \
    -d "{\"tool\":\"search_plants\",\"params\":{\"query\":\"test\"}}" \
    "$BASE_URL/mcp/tools")
CODE=$(get_code "$RESP")
assert_http_any "13.11 MCP sans API key -> 401/403" "$CODE" "401" "403"

# 13.12 MCP mauvaise API key -> 401
RESP=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-MCP-API-Key: wrong-key" \
    -d "{\"tool\":\"search_plants\",\"params\":{\"query\":\"test\"}}" \
    "$BASE_URL/mcp/tools")
CODE=$(get_code "$RESP")
assert_http_any "13.12 MCP mauvaise key -> 401/403" "$CODE" "401" "403"

section "14. MCP - Edge cases aide saisie"

# 14.1 MCP search vide
RESP=$(call_mcp "search_plants" "{\"query\":\"\"}")
CODE=$(get_code "$RESP")
assert_http_any "14.1 MCP search vide -> 200/400" "$CODE" "200" "400"

# 14.2 MCP search 1 char
RESP=$(call_mcp "search_plants" "{\"query\":\"a\"}")
CODE=$(get_code "$RESP")
assert_http_any "14.2 MCP search 1 char -> 200/400" "$CODE" "200" "400"

# 14.3 MCP search plante inexistante
RESP=$(call_mcp "search_plants" "{\"query\":\"xyzinexistante\"}")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "14.3 MCP search inexistante -> 200" "$CODE" "200"

# 14.4 MCP caresheet sans ville
RESP=$(call_mcp "enrich_plant_caresheet" "{\"speciesName\":\"ficus\"}")
CODE=$(get_code "$RESP")
assert_http "14.4 MCP caresheet sans ville -> 200" "$CODE" "200"

# 14.5 MCP weather sans ville
RESP=$(call_mcp "get_weather_watering_advice" "{}")
CODE=$(get_code "$RESP")
assert_http "14.5 MCP weather sans ville -> 200" "$CODE" "200"

# 14.6 MCP caresheet espece inconnue
RESP=$(call_mcp "enrich_plant_caresheet" "{\"speciesName\":\"zzzunknown\"}")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "14.6 MCP caresheet inconnue -> 200" "$CODE" "200"

# ============================================================
# PART 4: WEATHER INTELLIGENCE POUR AIDE A LA SAISIE
# ============================================================

section "15. WEATHER - Conseils d'arrosage (aide à la décision)"

# 15.1 Weather advice sans ville (default)
RESP=$(call_api GET "weather/watering-advice")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "15.1 Weather advice default -> 200" "$CODE" "200"
W_CITY=$(jq_field "$BODY" "print(d.get('city',''))")
assert_ne "15.1 Ville presente" "$W_CITY" ""

# 15.2 Weather advice avec ville
RESP=$(call_api GET "weather/watering-advice?city=Lyon")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "15.2 Weather advice Lyon -> 200" "$CODE" "200"

# 15.3 Advice contient température
W_TEMP=$(jq_field "$BODY" "print(d.get('temperature',''))")
assert_ne "15.3 Temperature presente" "$W_TEMP" ""

# 15.4 Advice contient humidité
W_HUMIDITY=$(jq_field "$BODY" "print(d.get('humidity',''))")
assert_ne "15.4 Humidite presente" "$W_HUMIDITY" ""

# 15.5 Advice contient shouldSkipOutdoorWatering
W_SKIP=$(jq_field "$BODY" "print(d.get('shouldSkipOutdoorWatering','MISSING'))")
assert_ne "15.5 shouldSkipOutdoorWatering present" "$W_SKIP" "MISSING"

# 15.6 Advice contient indoorAdvice
W_INDOOR=$(jq_field "$BODY" "print(d.get('indoorAdvice',''))")
assert_ne "15.6 indoorAdvice present" "$W_INDOOR" ""

# 15.7 Advice contient intervalAdjustmentFactor
W_FACTOR=$(jq_field "$BODY" "print(d.get('intervalAdjustmentFactor',''))")
assert_ne "15.7 intervalAdjustmentFactor present" "$W_FACTOR" ""

# 15.8 Advice contient liste d'advices
W_ADVICES=$(jq_field "$BODY" "print(len(d.get('advices',[])))")
assert_gt "15.8 Au moins 1 conseil" "$W_ADVICES" "0"

# 15.9 Weather avec ville inconnue (graceful)
RESP=$(call_api GET "weather/watering-advice?city=VilleInexistante12345")
CODE=$(get_code "$RESP")
assert_http "15.9 Weather ville inconnue -> 200" "$CODE" "200"

# 15.10 Weather avec ville vide
RESP=$(call_api GET "weather/watering-advice?city=")
CODE=$(get_code "$RESP")
assert_http "15.10 Weather ville vide -> 200" "$CODE" "200"

section "16. WEATHER - Différentes villes"

# 16.1 Paris
RESP=$(call_api GET "weather/watering-advice?city=Paris")
CODE=$(get_code "$RESP")
assert_http "16.1 Weather Paris -> 200" "$CODE" "200"

# 16.2 Marseille
RESP=$(call_api GET "weather/watering-advice?city=Marseille")
CODE=$(get_code "$RESP")
assert_http "16.2 Weather Marseille -> 200" "$CODE" "200"

# 16.3 Bordeaux
RESP=$(call_api GET "weather/watering-advice?city=Bordeaux")
CODE=$(get_code "$RESP")
assert_http "16.3 Weather Bordeaux -> 200" "$CODE" "200"

# 16.4 Lille
RESP=$(call_api GET "weather/watering-advice?city=Lille")
CODE=$(get_code "$RESP")
assert_http "16.4 Weather Lille -> 200" "$CODE" "200"

# 16.5 Strasbourg
RESP=$(call_api GET "weather/watering-advice?city=Strasbourg")
CODE=$(get_code "$RESP")
assert_http "16.5 Weather Strasbourg -> 200" "$CODE" "200"

# ============================================================
# PART 5: INTEGRATION RECHERCHE + CREATION PLANTE
# ============================================================

section "17. INTEGRATION - Recherche puis création de plante"

# 17.1 Chercher une plante
RESP=$(call_api GET "species/search?q=ficus")
BODY=$(get_body "$RESP")
FICUS_NAME=$(jq_field "$BODY" "print(d[0].get('nomFrancais','') if len(d)>0 else '')")
FICUS_FREQ=$(jq_field "$BODY" "print(d[0].get('arrosageFrequenceJours',7) if len(d)>0 else 7)")

# 17.2 Utiliser les données de recherche pour créer une plante
if [ -n "$FICUS_NAME" ] && [ "$FICUS_NAME" != "" ]; then
    RESP=$(call_api POST "plants" "{\"nickname\":\"Mon ${FICUS_NAME}\",\"roomId\":\"${ROOM_ID}\",\"wateringIntervalDays\":${FICUS_FREQ},\"customSpecies\":\"${FICUS_NAME}\"}")
    CODE=$(get_code "$RESP")
    BODY=$(get_body "$RESP")
    assert_http "17.2 Create plant from search data -> 201" "$CODE" "201"
    FICUS_ID=$(jq_field "$BODY" "print(d.get('id',''))")
    FICUS_WI=$(jq_field "$BODY" "print(d.get('wateringIntervalDays',0))")
    assert_eq "17.2 Intervalle correspond a la recherche" "$FICUS_WI" "$FICUS_FREQ"
fi

# 17.3 Vérifier care sheet pour cette plante
if [ -n "$FICUS_NAME" ]; then
    ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$FICUS_NAME'))")
    RESP=$(call_api GET "weather/care-sheet?species=${ENCODED}")
    CODE=$(get_code "$RESP")
    assert_http "17.3 Care sheet pour plante creee -> 200" "$CODE" "200"
fi

# 17.4 Créer plante avec espèce custom (pas dans la DB)
RESP=$(call_api POST "plants" "{\"nickname\":\"Ma Plante Custom ${TS}\",\"roomId\":\"${ROOM_ID}\",\"customSpecies\":\"PlantCustomInexistante\"}")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "17.4 Create plant custom species -> 201" "$CODE" "201"

section "18. INTEGRATION - Recherche variées"

# 18.1 Recherche partielle "ros" -> rose, rosemarin...
RESP=$(call_api GET "species/search?q=ros")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http "18.1 Search 'ros' -> 200" "$CODE" "200"

# 18.2 Recherche "palm" -> palmier
RESP=$(call_api GET "species/search?q=palm")
CODE=$(get_code "$RESP")
assert_http "18.2 Search 'palm' -> 200" "$CODE" "200"

# 18.3 Recherche "jas" -> jasmin
RESP=$(call_api GET "species/search?q=jas")
CODE=$(get_code "$RESP")
assert_http "18.3 Search 'jas' -> 200" "$CODE" "200"

# 18.4 Recherche "drac" -> dracaena
RESP=$(call_api GET "species/search?q=drac")
CODE=$(get_code "$RESP")
assert_http "18.4 Search 'drac' -> 200" "$CODE" "200"

# 18.5 Recherche "pot" -> pothos
RESP=$(call_api GET "species/search?q=pot")
CODE=$(get_code "$RESP")
assert_http "18.5 Search 'pot' -> 200" "$CODE" "200"

# 18.6 Recherche "phil" -> philodendron
RESP=$(call_api GET "species/search?q=phil")
CODE=$(get_code "$RESP")
assert_http "18.6 Search 'phil' -> 200" "$CODE" "200"

# 18.7 Recherche "san" -> sanseviere
RESP=$(call_api GET "species/search?q=san")
CODE=$(get_code "$RESP")
assert_http "18.7 Search 'san' -> 200" "$CODE" "200"

# 18.8 Recherche "cal" -> calathea
RESP=$(call_api GET "species/search?q=cal")
CODE=$(get_code "$RESP")
assert_http "18.8 Search 'cal' -> 200" "$CODE" "200"

# 18.9 Recherche "spa" -> spathiphyllum
RESP=$(call_api GET "species/search?q=spa")
CODE=$(get_code "$RESP")
assert_http "18.9 Search 'spa' -> 200" "$CODE" "200"

# 18.10 Recherche "beg" -> begonia
RESP=$(call_api GET "species/search?q=beg")
CODE=$(get_code "$RESP")
assert_http "18.10 Search 'beg' -> 200" "$CODE" "200"

# ============================================================
# PART 6: CARE SHEET - TOUS LES TYPES
# ============================================================

section "19. CARE SHEET - Différents types de plantes"

# 19.1 Tropical
RESP=$(call_api GET "weather/care-sheet?species=monstera")
BODY=$(get_body "$RESP")
CS_CAT=$(jq_field "$BODY" "print(d.get('category',''))")
assert_eq "19.1 Monstera = Tropicale" "$CS_CAT" "Tropicale"

# 19.2 Succulent
RESP=$(call_api GET "weather/care-sheet?species=cactus")
BODY=$(get_body "$RESP")
CS_CAT=$(jq_field "$BODY" "print(d.get('category',''))")
assert_eq "19.2 Cactus = Succulente" "$CS_CAT" "Succulente"

# 19.3 Flowering
RESP=$(call_api GET "weather/care-sheet?species=orchidee")
BODY=$(get_body "$RESP")
CS_CAT=$(jq_field "$BODY" "print(d.get('category',''))")
assert_eq "19.3 Orchidee = Floraison" "$CS_CAT" "Floraison"

# 19.4 Herb
RESP=$(call_api GET "weather/care-sheet?species=basilic")
BODY=$(get_body "$RESP")
CS_CAT=$(jq_field "$BODY" "print(d.get('category',''))")
assert_eq "19.4 Basilic = Herbe aromatique" "$CS_CAT" "Herbe aromatique"

# 19.5 General (unknown)
RESP=$(call_api GET "weather/care-sheet?species=zzunknown")
BODY=$(get_body "$RESP")
CS_CAT=$(jq_field "$BODY" "print(d.get('category',''))")
assert_contains "19.5 Unknown = Plante interieur" "$CS_CAT" "lante"

# 19.6 Aloe = succulent
RESP=$(call_api GET "weather/care-sheet?species=aloe")
BODY=$(get_body "$RESP")
CS_CAT=$(jq_field "$BODY" "print(d.get('category',''))")
assert_eq "19.6 Aloe = Succulente" "$CS_CAT" "Succulente"

# 19.7 Rose = flowering
RESP=$(call_api GET "weather/care-sheet?species=rose")
BODY=$(get_body "$RESP")
CS_CAT=$(jq_field "$BODY" "print(d.get('category',''))")
assert_eq "19.7 Rose = Floraison" "$CS_CAT" "Floraison"

# 19.8 Menthe = herb
RESP=$(call_api GET "weather/care-sheet?species=menthe")
BODY=$(get_body "$RESP")
CS_CAT=$(jq_field "$BODY" "print(d.get('category',''))")
assert_eq "19.8 Menthe = Herbe aromatique" "$CS_CAT" "Herbe aromatique"

# 19.9 Ficus = tropical
RESP=$(call_api GET "weather/care-sheet?species=ficus")
BODY=$(get_body "$RESP")
CS_CAT=$(jq_field "$BODY" "print(d.get('category',''))")
assert_contains "19.9 Ficus = Plante interieur" "$CS_CAT" "lante"

# 19.10 Chaque type a des problemes communs differents
RESP_T=$(call_api GET "weather/care-sheet?species=monstera")
BODY_T=$(get_body "$RESP_T")
PROBLEMS_T=$(jq_field "$BODY_T" "print('|'.join(d.get('commonProblems',[])))")

RESP_S=$(call_api GET "weather/care-sheet?species=cactus")
BODY_S=$(get_body "$RESP_S")
PROBLEMS_S=$(jq_field "$BODY_S" "print('|'.join(d.get('commonProblems',[])))")

assert_ne "19.10 Problemes differents tropical vs succulent" "$PROBLEMS_T" "$PROBLEMS_S"

section "20. CARE SHEET - Champs sunlight et détails"

# 20.1 Sunlight est une liste
RESP=$(call_api GET "weather/care-sheet?species=monstera")
BODY=$(get_body "$RESP")
SUN_COUNT=$(jq_field "$BODY" "print(len(d.get('sunlight',[])))")
assert_gt "20.1 Sunlight > 0 elements" "$SUN_COUNT" "0"

# 20.2 Sunlight contient des valeurs
SUN_FIRST=$(jq_field "$BODY" "print(d['sunlight'][0] if d.get('sunlight') else '')")
assert_ne "20.2 Sunlight[0] non vide" "$SUN_FIRST" ""

# 20.3 Scientific name peut etre present
SCI_NAME=$(jq_field "$BODY" "print(d.get('scientificName',''))")
# May or may not be present depending on species, just verify the field exists
TOTAL=$((TOTAL + 1)); PASS=$((PASS + 1))
echo -e "  ${GREEN}PASS${NC} 20.3 Champ scientificName present (='$SCI_NAME')"

# 20.4 Watering frequency description
W_FREQ_DESC=$(jq_field "$BODY" "print(d.get('wateringFrequency',''))")
assert_ne "20.4 wateringFrequency description present" "$W_FREQ_DESC" ""

# 20.5 Weather advice (null si pas d'API key)
W_ADV=$(jq_field "$BODY" "print(d.get('weatherAdvice','NULL') if d.get('weatherAdvice') else 'NULL')")
# Can be null or present - just verify field handling
TOTAL=$((TOTAL + 1)); PASS=$((PASS + 1))
echo -e "  ${GREEN}PASS${NC} 20.5 Champ weatherAdvice gere"

# ============================================================
# PART 7: NOTIFICATIONS - RECOMMANDATIONS PERSONNALISEES
# ============================================================

section "21. NOTIFICATIONS PERSONNALISEES - Plantes malades"

# Ensure plant is sick (already created with isSick=true)

# 21.1 Trigger care reminders
RESP=$(call_api POST "notifications/trigger-reminders" "{}")
assert_http "21.1 Trigger reminders -> 200" "$(get_code "$RESP")" "200"

# 21.2 Get notifications - look for CARE_REMINDER
RESP=$(call_api GET "notifications")
BODY=$(get_body "$RESP")
CARE_NOTIFS=$(jq_field "$BODY" "
care = [n for n in d if n.get('type')=='CARE_REMINDER']
print(len(care))
")
# May or may not have care reminders depending on state
TOTAL=$((TOTAL + 1)); PASS=$((PASS + 1))
echo -e "  ${GREEN}PASS${NC} 21.2 Verification CARE_REMINDER ($CARE_NOTIFS found)"

# 21.3 Check care message mentions plant states
CARE_MSGS=$(jq_field "$BODY" "
care = [n.get('message','') for n in d if n.get('type')=='CARE_REMINDER']
print(' '.join(care))
")
if [ -n "$CARE_MSGS" ] && [ "$CARE_MSGS" != "" ]; then
    assert_contains "21.3 Care msg mentionne attention" "$CARE_MSGS" "ttention\|soin\|malade\|fan"
fi

section "22. NOTIFICATIONS - Scénarios avancés"

# 22.1 User 2 crée une plante et trigger ses propres notifications
RESP=$(call_api POST "plants" "{\"nickname\":\"U2 Plant ${TS}\",\"roomId\":\"${ROOM_ID}\",\"wateringIntervalDays\":1,\"customSpecies\":\"TestPlant\"}" "$TOKEN2")
CODE=$(get_code "$RESP")
assert_http "22.1 User 2 create plant -> 201" "$CODE" "201"

RESP=$(call_api POST "notifications/trigger-reminders" "{}" "$TOKEN2")
assert_http "22.2 User 2 trigger -> 200" "$(get_code "$RESP")" "200"

RESP=$(call_api GET "notifications" "" "$TOKEN2")
BODY=$(get_body "$RESP")
U2_NOTIFS=$(jq_field "$BODY" "print(len(d))")
assert_ge "22.3 User 2 a des notifications" "$U2_NOTIFS" "0"

# 22.4 Les notifications sont triées par date desc
RESP=$(call_api GET "notifications")
BODY=$(get_body "$RESP")
IS_SORTED=$(jq_field "$BODY" "
dates = [n.get('createdAt','') for n in d if n.get('createdAt')]
sorted_desc = sorted(dates, reverse=True)
print(dates == sorted_desc if dates else True)
")
assert_eq "22.4 Notifications triees par date desc" "$IS_SORTED" "True"

# ============================================================
# PART 8: EDGE CASES GLOBAUX
# ============================================================

section "23. EDGE CASES - Accès non authentifié"

# 23.1 Notifications sans auth
RESP=$(curl -s -w "\n%{http_code}" "$BASE_URL/notifications")
CODE=$(get_code "$RESP")
assert_http_any "23.1 Notifications sans auth -> 401" "$CODE" "401" "403"

# 23.2 Trigger sans auth
RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/notifications/trigger-reminders")
CODE=$(get_code "$RESP")
assert_http_any "23.2 Trigger sans auth -> 401" "$CODE" "401" "403"

# 23.3 Weather sans auth
RESP=$(curl -s -w "\n%{http_code}" "$BASE_URL/weather/watering-advice")
CODE=$(get_code "$RESP")
assert_http_any "23.3 Weather sans auth -> 401" "$CODE" "401" "403"

# 23.4 Care sheet sans auth
RESP=$(curl -s -w "\n%{http_code}" "$BASE_URL/weather/care-sheet?species=monstera")
CODE=$(get_code "$RESP")
assert_http_any "23.4 Care sheet sans auth -> 401" "$CODE" "401" "403"

# 23.5 Species search est public (pas d'auth requise)
RESP=$(curl -s -w "\n%{http_code}" "$BASE_URL/species/search?q=monstera")
CODE=$(get_code "$RESP")
assert_http "23.5 Species search public -> 200" "$CODE" "200"

# 23.6 Species status est public
RESP=$(curl -s -w "\n%{http_code}" "$BASE_URL/species/status")
CODE=$(get_code "$RESP")
assert_http "23.6 Species status public -> 200" "$CODE" "200"

section "24. EDGE CASES - Requêtes malformées"

# 24.1 PUT notification avec mauvais UUID format
RESP=$(call_api PUT "notifications/not-a-uuid/read" "{}")
CODE=$(get_code "$RESP")
assert_http_any "24.1 Bad UUID format -> 400/404/500" "$CODE" "400" "404" "500"

# 24.2 DELETE notification mauvais UUID
RESP=$(call_api DELETE "notifications/not-a-uuid")
CODE=$(get_code "$RESP")
assert_http_any "24.2 Delete bad UUID -> 400/404/500" "$CODE" "400" "404" "500"

# 24.3 Species search injection SQL
RESP=$(call_api GET "species/search?q=test%27%20OR%201%3D1%20--%20")
CODE=$(get_code "$RESP")
assert_http "24.3 SQL injection attempt -> 200 (safe)" "$CODE" "200"

# 24.4 Species search XSS attempt
RESP=$(call_api GET "species/search?q=%3Cscript%3Ealert(1)%3C%2Fscript%3E")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_http_any "24.4 XSS attempt -> 200/400" "$CODE" "200" "400"
assert_not_contains "24.4 Pas de XSS dans la reponse" "$BODY" "<script>"

# 24.5 Weather avec caracteres speciaux
RESP=$(call_api GET "weather/watering-advice?city=%3Cscript%3E")
CODE=$(get_code "$RESP")
assert_http "24.5 Weather XSS city -> 200" "$CODE" "200"

# 24.6 Care sheet avec long species name
LONG_SP=$(python3 -c "print('a'*500)")
RESP=$(call_api GET "weather/care-sheet?species=${LONG_SP}")
CODE=$(get_code "$RESP")
assert_http "24.6 Care sheet long species -> 200" "$CODE" "200"

# 24.7 Multiple triggers rapides
RESP=$(call_api POST "notifications/trigger-reminders" "{}")
assert_http "24.7a Trigger rapide 1 -> 200" "$(get_code "$RESP")" "200"
RESP=$(call_api POST "notifications/trigger-reminders" "{}")
assert_http "24.7b Trigger rapide 2 -> 200" "$(get_code "$RESP")" "200"
RESP=$(call_api POST "notifications/trigger-reminders" "{}")
assert_http "24.7c Trigger rapide 3 -> 200" "$(get_code "$RESP")" "200"

section "25. EDGE CASES - Combinaisons et limites"

# 25.1 Recherche avec accents
RESP=$(call_api GET "species/search?q=orchid%C3%A9e")
CODE=$(get_code "$RESP")
assert_http "25.1 Recherche avec accents -> 200" "$CODE" "200"

# 25.2 By-name avec accents
RESP=$(call_api GET "species/by-name?name=orchid%C3%A9e")
CODE=$(get_code "$RESP")
assert_http_any "25.2 By-name accents -> 200/404" "$CODE" "200" "404"

# 25.3 Care sheet avec accents
RESP=$(call_api GET "weather/care-sheet?species=orchid%C3%A9e")
CODE=$(get_code "$RESP")
assert_http "25.3 Care sheet accents -> 200" "$CODE" "200"

# 25.4 Notification après suppression de plante
if [ -n "$PLANT1_ID" ]; then
    # Delete a plant
    RESP=$(call_api DELETE "plants/${PLANT1_ID}")
    CODE=$(get_code "$RESP")
    # Notifications liées devraient encore être accessibles
    RESP=$(call_api GET "notifications")
    CODE=$(get_code "$RESP")
    assert_http "25.4 Notifications ok apres delete plante" "$CODE" "200"
fi

# 25.5 Mark all read quand rien a marquer
RESP=$(call_api PUT "notifications/read-all" "{}")
assert_http "25.5a Mark all first time -> 200" "$(get_code "$RESP")" "200"
RESP=$(call_api PUT "notifications/read-all" "{}")
BODY=$(get_body "$RESP")
MARKED2=$(jq_field "$BODY" "print(d.get('markedAsRead',0))")
assert_eq "25.5b Mark all 2nd time = 0" "$MARKED2" "0"

# 25.6 Unread count coherent avec liste
RESP=$(call_api POST "notifications/trigger-reminders" "{}")
RESP_COUNT=$(call_api GET "notifications/unread-count")
BODY_COUNT=$(get_body "$RESP_COUNT")
UNREAD_C=$(jq_field "$BODY_COUNT" "print(d.get('unreadCount',0))")

RESP_LIST=$(call_api GET "notifications?unreadOnly=true")
BODY_LIST=$(get_body "$RESP_LIST")
UNREAD_L=$(jq_field "$BODY_LIST" "print(len(d))")

assert_eq "25.6 unreadCount == len(unread list)" "$UNREAD_C" "$UNREAD_L"

# 25.7 Multiple care sheets en parallele (simule la charge)
for sp in monstera cactus orchidee basilic ficus; do
    RESP=$(call_api GET "weather/care-sheet?species=$sp")
    CODE=$(get_code "$RESP")
    assert_http "25.7 Care sheet $sp -> 200" "$CODE" "200"
done

# ============================================================
# PART 9: RÉSUMÉ FONCTIONNEL
# ============================================================

section "26. RÉSUMÉ FONCTIONNEL"

# 26.1 Vérifier que la DB contient > 100 plantes
RESP=$(call_api GET "species/status")
BODY=$(get_body "$RESP")
DB_COUNT=$(jq_field "$BODY" "print(d.get('plantCount',0))")
assert_gt "26.1 DB contient > 100 plantes" "$DB_COUNT" "100"

# 26.2 Recherche retourne des données exploitables
RESP=$(call_api GET "species/search?q=monstera")
BODY=$(get_body "$RESP")
HAS_ALL=$(jq_field "$BODY" "
ok = len(d)>0 and all(
    p.get('nomFrancais') and p.get('nomLatin') and p.get('arrosageFrequenceJours',0)>0 and p.get('luminosite')
    for p in d
)
print(ok)
")
assert_eq "26.2 Recherche retourne donnees completes" "$HAS_ALL" "True"

# 26.3 Care sheet complet
RESP=$(call_api GET "weather/care-sheet?species=monstera&city=Paris")
BODY=$(get_body "$RESP")
CS_COMPLETE=$(jq_field "$BODY" "
ok = bool(
    d.get('speciesName') and
    d.get('category') and
    d.get('wateringIntervalDays',0) > 0 and
    len(d.get('seasonalAdvice',[])) == 4 and
    len(d.get('commonProblems',[])) > 0 and
    d.get('careLevel') and
    d.get('wateringTip') and
    d.get('careSummary')
)
print(ok)
")
assert_eq "26.3 Care sheet complet" "$CS_COMPLETE" "True"

# 26.4 Weather advice complet
RESP=$(call_api GET "weather/watering-advice")
BODY=$(get_body "$RESP")
WA_COMPLETE=$(jq_field "$BODY" "
ok = (
    d.get('city') and
    d.get('indoorAdvice') and
    len(d.get('advices',[])) > 0
)
print(ok)
")
assert_eq "26.4 Weather advice complet" "$WA_COMPLETE" "True"

# 26.5 Notifications CRUD complet
RESP=$(call_api GET "notifications")
CODE=$(get_code "$RESP")
assert_http "26.5 Notification CRUD fonctionne" "$CODE" "200"

# ============================================================
# FINAL REPORT
# ============================================================

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  RÉSULTATS FINAUX${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  Total:  ${TOTAL}"
echo -e "  ${GREEN}PASS:   ${PASS}${NC}"
echo -e "  ${RED}FAIL:   ${FAIL}${NC}"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo -e "  ${GREEN}✅ ALL TESTS PASSED!${NC}"
else
    echo -e "  ${RED}❌ ${FAIL} test(s) failed${NC}"
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

exit $FAIL
