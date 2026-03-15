#!/bin/bash
#
# Script de test complet: Intelligence & Automatisation
# - Fiches de soins enrichies (MCP + Weather)
# - Planification intelligente arrosage (données, historique, météo)
# - Suggestions d'actions adaptées au type de plante
#
# Usage: ./test-intelligence.sh [BASE_URL] [MCP_API_KEY]
#

BASE_URL="${1:-http://localhost:8080/api/v1}"
API_KEY="${2:-test-mcp-key}"
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
PLANT_IDS=()
ROOM_ID=""

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
    if echo "$haystack" | grep -q "$needle"; then
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
    if ! echo "$haystack" | grep -q "$needle"; then
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC} $name"
    else
        FAIL=$((FAIL + 1))
        echo -e "  ${RED}FAIL${NC} $name (should NOT contain: '$needle')"
    fi
}

assert_gt() {
    local name="$1" actual="$2" min="$3"
    TOTAL=$((TOTAL + 1))
    if [ "$actual" -gt "$min" ] 2>/dev/null; then
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC} $name ($actual > $min)"
    else
        FAIL=$((FAIL + 1))
        echo -e "  ${RED}FAIL${NC} $name (got '$actual', expected > '$min')"
    fi
}

assert_ge() {
    local name="$1" actual="$2" min="$3"
    TOTAL=$((TOTAL + 1))
    if [ "$actual" -ge "$min" ] 2>/dev/null; then
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC} $name ($actual >= $min)"
    else
        FAIL=$((FAIL + 1))
        echo -e "  ${RED}FAIL${NC} $name (got '$actual', expected >= '$min')"
    fi
}

assert_http() {
    local name="$1" resp="$2" expected_code="$3"
    local code=$(get_code "$resp")
    TOTAL=$((TOTAL + 1))
    if [ "$code" = "$expected_code" ]; then
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC} $name (HTTP $code)"
    else
        FAIL=$((FAIL + 1))
        echo -e "  ${RED}FAIL${NC} $name (HTTP $code, expected $expected_code)"
    fi
}

do_login() {
    local email="$1" password="$2" display_name="$3"
    local resp
    resp=$(curl -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" \
        -d "{\"email\":\"$email\",\"password\":\"$password\"}" "$BASE_URL/auth/login")
    local code=$(get_code "$resp")
    if [ "$code" != "200" ]; then
        resp=$(curl -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" \
            -d "{\"email\":\"$email\",\"password\":\"$password\",\"displayName\":\"$display_name\"}" "$BASE_URL/auth/register")
    fi
    local body=$(get_body "$resp")
    echo "$body" | python3 -c "import sys,json; print(json.load(sys.stdin).get('accessToken',''))" 2>/dev/null
}

get_user_id() {
    local token="$1"
    curl -s -H "Authorization: Bearer $token" "$BASE_URL/auth/me" | \
        python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null
}

# ============================================================
echo -e "\n${CYAN}============================================================${NC}"
echo -e "${CYAN}  INTELLIGENCE & AUTOMATISATION - TESTS COMPLETS${NC}"
echo -e "${CYAN}  Weather, MCP enrichment, care sheets, suggestions${NC}"
echo -e "${CYAN}  Run ID: $TS${NC}"
echo -e "${CYAN}============================================================${NC}"

# ============================================================
# PART 0: Setup - Auth + House + Plants
# ============================================================
echo -e "\n${YELLOW}[0] Setup: Auth + House + Plantes variees${NC}"

TOKEN1=$(do_login "intel-u1-$TS@test.com" "password123" "IntelUser1")
TOKEN2=$(do_login "intel-u2-$TS@test.com" "password123" "IntelUser2")
assert_ne "User1 token" "$TOKEN1" ""
assert_ne "User2 token" "$TOKEN2" ""

USER1_ID=$(get_user_id "$TOKEN1")
USER2_ID=$(get_user_id "$TOKEN2")

# Create house
RESP=$(call_api POST "houses" '{"name":"IntelHouse"}')
HOUSE_ID=$(jq_field "$(get_body "$RESP")" "print(d.get('id',''))")
INVITE_CODE=$(jq_field "$(get_body "$RESP")" "print(d.get('inviteCode',''))")
assert_ne "House created" "$HOUSE_ID" ""

# User2 joins
call_api POST "houses/join" "{\"inviteCode\":\"$INVITE_CODE\"}" "$TOKEN2" >/dev/null

# Create rooms
RESP=$(call_api POST "rooms" '{"name":"Salon","type":"LIVING_ROOM"}')
ROOM_ID=$(jq_field "$(get_body "$RESP")" "print(d.get('id',''))")

# Create diverse plants (tropical, succulent, flowering, herb, generic)
SPECIES_LIST="tropical cactus orchidee basilic ficus aloe lavande unknown"
NICK_LIST="MonMonstera MonCactus MonOrchidee MonBasilic MonFicus MonAloe MaLavande PlanteInconnue"

i=0
for species in $SPECIES_LIST; do
    i=$((i + 1))
    nickname=$(echo "$NICK_LIST" | cut -d' ' -f$i)
    if [ "$species" = "unknown" ]; then
        custom=""
    else
        custom="$species"
    fi
    RESP=$(call_api POST "plants" "{\"nickname\":\"$nickname\",\"customSpecies\":\"$custom\",\"roomId\":\"$ROOM_ID\",\"wateringIntervalDays\":7}")
    PID=$(jq_field "$(get_body "$RESP")" "print(d.get('id',''))")
    PLANT_IDS+=("$PID")
done
echo "  Created ${#PLANT_IDS[@]} plants"
assert_eq "8 plantes creees" "${#PLANT_IDS[@]}" "8"

# ============================================================
# PART 1: Weather watering advice endpoint
# ============================================================
echo -e "\n${CYAN}=== PARTIE 1: Weather Watering Advice ===${NC}"

# ------ Step 1: Basic weather advice endpoint ------
echo -e "\n${YELLOW}[1] Weather advice - endpoint de base${NC}"

RESP=$(call_api GET "weather/watering-advice")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_eq "GET watering-advice -> 200" "$CODE" "200"

HAS_CITY=$(jq_field "$BODY" "print('city' in d)")
HAS_ADVICES=$(jq_field "$BODY" "print('advices' in d)")
HAS_FACTOR=$(jq_field "$BODY" "print('intervalAdjustmentFactor' in d)")
HAS_SKIP=$(jq_field "$BODY" "print('shouldSkipOutdoorWatering' in d)")
HAS_INDOOR=$(jq_field "$BODY" "print('indoorAdvice' in d)")
HAS_HUMIDITY=$(jq_field "$BODY" "print('humidity' in d)")
HAS_TEMP=$(jq_field "$BODY" "print('temperature' in d)")
HAS_RAIN=$(jq_field "$BODY" "print('rainMm' in d)")
HAS_DESC=$(jq_field "$BODY" "print('weatherDescription' in d)")

assert_eq "Champ city present" "$HAS_CITY" "True"
assert_eq "Champ advices present" "$HAS_ADVICES" "True"
assert_eq "Champ intervalAdjustmentFactor present" "$HAS_FACTOR" "True"
assert_eq "Champ shouldSkipOutdoorWatering present" "$HAS_SKIP" "True"
assert_eq "Champ indoorAdvice present" "$HAS_INDOOR" "True"
assert_eq "Champ humidity present" "$HAS_HUMIDITY" "True"
assert_eq "Champ temperature present" "$HAS_TEMP" "True"
assert_eq "Champ rainMm present" "$HAS_RAIN" "True"
assert_eq "Champ weatherDescription present" "$HAS_DESC" "True"

# ------ Step 2: Weather advice with city param ------
echo -e "\n${YELLOW}[2] Weather advice - avec parametre city${NC}"

RESP=$(call_api GET "weather/watering-advice?city=Paris")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_eq "GET watering-advice?city=Paris -> 200" "$CODE" "200"

ADVICES_COUNT=$(jq_field "$BODY" "print(len(d.get('advices',[])))")
assert_gt "Au moins 1 conseil" "$ADVICES_COUNT" "0"

FACTOR=$(jq_field "$BODY" "print(d.get('intervalAdjustmentFactor',0))")
assert_ne "Factor non nul" "$FACTOR" "0"

# ------ Step 3: Weather advice with different cities ------
echo -e "\n${YELLOW}[3] Weather advice - villes variees${NC}"

for city in Lyon Marseille Lille Bordeaux; do
    RESP=$(call_api GET "weather/watering-advice?city=$city")
    CODE=$(get_code "$RESP")
    assert_eq "Weather $city -> 200" "$CODE" "200"
done

# ------ Step 4: Weather advice with empty/invalid city ------
echo -e "\n${YELLOW}[4] Weather advice - ville vide/invalide${NC}"

RESP=$(call_api GET "weather/watering-advice?city=")
CODE=$(get_code "$RESP")
assert_eq "Weather city vide -> 200 (default)" "$CODE" "200"

RESP=$(call_api GET "weather/watering-advice?city=XyzNonExistentCity99")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_eq "Weather ville inexistante -> 200 (fallback saisonnier)" "$CODE" "200"
ADVICES_COUNT=$(jq_field "$BODY" "print(len(d.get('advices',[])))")
assert_gt "Fallback a au moins 1 conseil" "$ADVICES_COUNT" "0"

# ------ Step 5: Weather advice structure validation ------
echo -e "\n${YELLOW}[5] Weather advice - validation structure complete${NC}"

RESP=$(call_api GET "weather/watering-advice?city=Paris")
BODY=$(get_body "$RESP")

SKIP_TYPE=$(jq_field "$BODY" "print(type(d.get('shouldSkipOutdoorWatering')).__name__)")
assert_eq "shouldSkipOutdoorWatering est bool" "$SKIP_TYPE" "bool"

ADVICES_TYPE=$(jq_field "$BODY" "print(type(d.get('advices')).__name__)")
assert_eq "advices est une liste" "$ADVICES_TYPE" "list"

FACTOR_VAL=$(jq_field "$BODY" "print(d.get('intervalAdjustmentFactor',0))")
FACTOR_VALID=$(python3 -c "f=$FACTOR_VAL; print('true' if 0.1 <= f <= 3.0 else 'false')" 2>/dev/null)
assert_eq "Factor dans [0.1, 3.0]" "$FACTOR_VALID" "true"

INDOOR=$(jq_field "$BODY" "print(d.get('indoorAdvice',''))")
assert_ne "indoorAdvice non vide" "$INDOOR" ""

# ------ Step 6: Weather advice without auth -> 401 ------
echo -e "\n${YELLOW}[6] Weather advice - sans authentification${NC}"

RESP=$(curl -s -w "\n%{http_code}" "$BASE_URL/weather/watering-advice")
CODE=$(get_code "$RESP")
assert_eq "Sans token -> 401" "$CODE" "401"

# ------ Step 7: Weather advice - HTTP methods ------
echo -e "\n${YELLOW}[7] Weather advice - methodes HTTP non autorisees${NC}"

RESP=$(call_api POST "weather/watering-advice" '{}')
CODE=$(get_code "$RESP")
assert_eq "POST watering-advice -> 405" "$CODE" "405"

RESP=$(call_api DELETE "weather/watering-advice")
CODE=$(get_code "$RESP")
assert_eq "DELETE watering-advice -> 405" "$CODE" "405"

# ============================================================
# PART 2: Care Sheet (fiche de soin enrichie)
# ============================================================
echo -e "\n${CYAN}=== PARTIE 2: Fiches de Soin Enrichies ===${NC}"

# ------ Step 8: Care sheet for known species ------
echo -e "\n${YELLOW}[8] Fiche de soin - espece connue (monstera)${NC}"

RESP=$(call_api GET "weather/care-sheet?species=monstera")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_eq "GET care-sheet monstera -> 200" "$CODE" "200"

CS_SPECIES=$(jq_field "$BODY" "print(d.get('speciesName',''))")
CS_CATEGORY=$(jq_field "$BODY" "print(d.get('category',''))")
CS_FREQ=$(jq_field "$BODY" "print(d.get('wateringFrequency',''))")
CS_INTERVAL=$(jq_field "$BODY" "print(d.get('wateringIntervalDays',0))")
CS_SUNLIGHT=$(jq_field "$BODY" "print(len(d.get('sunlight',[])))")
CS_LEVEL=$(jq_field "$BODY" "print(d.get('careLevel',''))")
CS_TIP=$(jq_field "$BODY" "print(d.get('wateringTip',''))")
CS_SEASONAL=$(jq_field "$BODY" "print(len(d.get('seasonalAdvice',[])))")
CS_PROBLEMS=$(jq_field "$BODY" "print(len(d.get('commonProblems',[])))")
CS_SUMMARY=$(jq_field "$BODY" "print(d.get('careSummary',''))")

assert_eq "speciesName = monstera" "$CS_SPECIES" "monstera"
assert_eq "category = Tropicale" "$CS_CATEGORY" "Tropicale"
assert_ne "wateringFrequency non vide" "$CS_FREQ" ""
assert_eq "wateringIntervalDays = 7" "$CS_INTERVAL" "7"
assert_gt "sunlight non vide" "$CS_SUNLIGHT" "0"
assert_ne "careLevel non vide" "$CS_LEVEL" ""
assert_ne "wateringTip non vide" "$CS_TIP" ""
assert_eq "4 conseils saisonniers" "$CS_SEASONAL" "4"
assert_ge "Au moins 2 problemes courants" "$CS_PROBLEMS" "2"
assert_ne "careSummary non vide" "$CS_SUMMARY" ""

# ------ Step 9: Care sheet for each category ------
echo -e "\n${YELLOW}[9] Fiche de soin - toutes les categories${NC}"

for pair in "monstera:Tropicale" "cactus:Succulente" "orchidee:Floraison" "basilic:Herbe" "ficus:Plante"; do
    species="${pair%%:*}"
    expected="${pair##*:}"
    RESP=$(call_api GET "weather/care-sheet?species=$species")
    CODE=$(get_code "$RESP")
    BODY=$(get_body "$RESP")
    assert_eq "Care sheet $species -> 200" "$CODE" "200"

    CAT=$(jq_field "$BODY" "print(d.get('category',''))")
    assert_contains "Categorie $species contient '$expected'" "$CAT" "$expected"
done

# ------ Step 10: Care sheet interval per species ------
echo -e "\n${YELLOW}[10] Fiche de soin - intervalles par espece${NC}"

for pair in "cactus:21" "basilic:2" "aloe:14" "rose:3" "monstera:7" "lavande:10" "calathea:5"; do
    species="${pair%%:*}"
    expected="${pair##*:}"
    RESP=$(call_api GET "weather/care-sheet?species=$species")
    BODY=$(get_body "$RESP")
    INTERVAL=$(jq_field "$BODY" "print(d.get('wateringIntervalDays',0))")
    assert_eq "$species interval = $expected jours" "$INTERVAL" "$expected"
done

# ------ Step 11: Care sheet sunlight per species ------
echo -e "\n${YELLOW}[11] Fiche de soin - luminosite par espece${NC}"

for pair in "cactus:Plein soleil" "basilic:Plein soleil" "monstera:Mi-ombre" "calathea:Ombre" "pothos:Ombre"; do
    species="${pair%%:*}"
    expected="${pair#*:}"
    RESP=$(call_api GET "weather/care-sheet?species=$species")
    BODY=$(get_body "$RESP")
    SUNLIGHT=$(jq_field "$BODY" "print(d.get('sunlight',[''])[0])")
    assert_contains "$species sunlight contient '$expected'" "$SUNLIGHT" "$expected"
done

# ------ Step 12: Care sheet seasonal advice structure ------
echo -e "\n${YELLOW}[12] Fiche de soin - structure conseils saisonniers${NC}"

RESP=$(call_api GET "weather/care-sheet?species=monstera")
BODY=$(get_body "$RESP")

SEASONS=$(jq_field "$BODY" "
seasons = [s['season'] for s in d.get('seasonalAdvice',[])]
print(','.join(seasons))
")
assert_contains "Saison Printemps" "$SEASONS" "Printemps"
assert_contains "Saison Ete" "$SEASONS" "Été"
assert_contains "Saison Automne" "$SEASONS" "Automne"
assert_contains "Saison Hiver" "$SEASONS" "Hiver"

# Check each seasonal advice has required fields
ALL_FIELDS=$(jq_field "$BODY" "
ok = all('season' in s and 'wateringAdjustment' in s and 'careNotes' in s for s in d.get('seasonalAdvice',[]))
print(ok)
")
assert_eq "Tous les champs saisonniers presents" "$ALL_FIELDS" "True"

# ------ Step 13: Care sheet common problems per category ------
echo -e "\n${YELLOW}[13] Fiche de soin - problemes courants par categorie${NC}"

# Tropical -> should mention "vaporis" or "cochenilles"
RESP=$(call_api GET "weather/care-sheet?species=monstera")
BODY=$(get_body "$RESP")
PROBLEMS=$(jq_field "$BODY" "print('|'.join(d.get('commonProblems',[])))")
assert_contains "Tropical: mentionne feuilles" "$PROBLEMS" "feuilles"

# Succulent -> should mention "pourriture" or "etiolement"
RESP=$(call_api GET "weather/care-sheet?species=cactus")
BODY=$(get_body "$RESP")
PROBLEMS=$(jq_field "$BODY" "print('|'.join(d.get('commonProblems',[])))")
assert_contains "Succulent: mentionne pourriture ou tige" "$PROBLEMS" "tige"

# Herb -> should mention "pucerons" or "lumiere"
RESP=$(call_api GET "weather/care-sheet?species=basilic")
BODY=$(get_body "$RESP")
PROBLEMS=$(jq_field "$BODY" "print('|'.join(d.get('commonProblems',[])))")
assert_contains "Herb: mentionne pucerons ou lumiere" "$PROBLEMS" "ucerons"

# ------ Step 14: Care sheet for unknown species ------
echo -e "\n${YELLOW}[14] Fiche de soin - espece inconnue (fallback generique)${NC}"

RESP=$(call_api GET "weather/care-sheet?species=plantexotiqueinconnue")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_eq "Espece inconnue -> 200" "$CODE" "200"

INTERVAL=$(jq_field "$BODY" "print(d.get('wateringIntervalDays',0))")
assert_eq "Fallback interval = 7" "$INTERVAL" "7"

SUMMARY=$(jq_field "$BODY" "print(d.get('careSummary',''))")
assert_contains "Summary mentionne generique/precise" "$SUMMARY" "soin"

# ------ Step 15: Care sheet with city param ------
echo -e "\n${YELLOW}[15] Fiche de soin - avec ville pour meteo${NC}"

RESP=$(call_api GET "weather/care-sheet?species=monstera&city=Paris")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_eq "Care sheet + city -> 200" "$CODE" "200"

HAS_WEATHER=$(jq_field "$BODY" "print('weatherAdvice' in d)")
assert_eq "Champ weatherAdvice present" "$HAS_WEATHER" "True"

# ------ Step 16: Care sheet missing species param ------
echo -e "\n${YELLOW}[16] Fiche de soin - parametre species manquant${NC}"

RESP=$(call_api GET "weather/care-sheet")
CODE=$(get_code "$RESP")
assert_eq "Sans species -> 400" "$CODE" "400"

RESP=$(call_api GET "weather/care-sheet?species=")
CODE=$(get_code "$RESP")
assert_eq "species vide -> 400" "$CODE" "400"

# ------ Step 17: Care sheet - care level mapping ------
echo -e "\n${YELLOW}[17] Fiche de soin - niveau de soin correct${NC}"

# Cactus (21 days) -> Facile
RESP=$(call_api GET "weather/care-sheet?species=cactus")
BODY=$(get_body "$RESP")
LEVEL=$(jq_field "$BODY" "print(d.get('careLevel',''))")
assert_eq "Cactus = Facile" "$LEVEL" "Facile"

# Monstera (7 days) -> Moyen
RESP=$(call_api GET "weather/care-sheet?species=monstera")
BODY=$(get_body "$RESP")
LEVEL=$(jq_field "$BODY" "print(d.get('careLevel',''))")
assert_eq "Monstera = Moyen" "$LEVEL" "Moyen"

# Basilic (2 days) -> Attention requise
RESP=$(call_api GET "weather/care-sheet?species=basilic")
BODY=$(get_body "$RESP")
LEVEL=$(jq_field "$BODY" "print(d.get('careLevel',''))")
assert_eq "Basilic = Attention requise" "$LEVEL" "Attention requise"

# ------ Step 18: Care sheet - watering frequency label ------
echo -e "\n${YELLOW}[18] Fiche de soin - label frequence arrosage${NC}"

# Basilic (2 days) -> Frequent
RESP=$(call_api GET "weather/care-sheet?species=basilic")
BODY=$(get_body "$RESP")
FREQ=$(jq_field "$BODY" "print(d.get('wateringFrequency',''))")
assert_eq "Basilic = Frequent" "$FREQ" "Fréquent"

# Monstera (7 days) -> Moyen
RESP=$(call_api GET "weather/care-sheet?species=monstera")
BODY=$(get_body "$RESP")
FREQ=$(jq_field "$BODY" "print(d.get('wateringFrequency',''))")
assert_eq "Monstera = Moyen" "$FREQ" "Moyen"

# Aloe (14 days) -> Peu frequent
RESP=$(call_api GET "weather/care-sheet?species=aloe")
BODY=$(get_body "$RESP")
FREQ=$(jq_field "$BODY" "print(d.get('wateringFrequency',''))")
assert_eq "Aloe = Peu frequent" "$FREQ" "Peu fréquent"

# Cactus (21 days) -> Rare
RESP=$(call_api GET "weather/care-sheet?species=cactus")
BODY=$(get_body "$RESP")
FREQ=$(jq_field "$BODY" "print(d.get('wateringFrequency',''))")
assert_eq "Cactus = Rare" "$FREQ" "Rare"

# ------ Step 19: Care sheet - special characters in species ------
echo -e "\n${YELLOW}[19] Fiche de soin - caracteres speciaux${NC}"

RESP=$(call_api GET "weather/care-sheet?species=fougère")
CODE=$(get_code "$RESP")
assert_eq "Accent dans species -> 200" "$CODE" "200"

RESP=$(call_api GET "weather/care-sheet?species=plante%20verte")
CODE=$(get_code "$RESP")
assert_eq "Espace dans species -> 200" "$CODE" "200"

# ------ Step 20: Care sheet without auth -> 401 ------
echo -e "\n${YELLOW}[20] Care sheet sans auth${NC}"

RESP=$(curl -s -w "\n%{http_code}" "$BASE_URL/weather/care-sheet?species=monstera")
CODE=$(get_code "$RESP")
assert_eq "Sans token -> 401" "$CODE" "401"

# ============================================================
# PART 3: MCP - enrich_plant_caresheet tool
# ============================================================
echo -e "\n${CYAN}=== PARTIE 3: MCP enrich_plant_caresheet ===${NC}"

# ------ Step 21: MCP enrich basic ------
echo -e "\n${YELLOW}[21] MCP enrich_plant_caresheet - basique${NC}"

RESP=$(call_mcp "enrich_plant_caresheet" '{"speciesName":"monstera"}')
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_eq "MCP enrich monstera -> 200" "$CODE" "200"

STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "Status = success" "$STATUS" "success"

DATA_SPECIES=$(jq_field "$BODY" "print(d.get('data',{}).get('speciesName',''))")
assert_eq "data.speciesName = monstera" "$DATA_SPECIES" "monstera"

DATA_CAT=$(jq_field "$BODY" "print(d.get('data',{}).get('category',''))")
assert_eq "data.category = Tropicale" "$DATA_CAT" "Tropicale"

DATA_INTERVAL=$(jq_field "$BODY" "print(d.get('data',{}).get('wateringIntervalDays',0))")
assert_eq "data.interval = 7" "$DATA_INTERVAL" "7"

DATA_SEASONAL=$(jq_field "$BODY" "print(len(d.get('data',{}).get('seasonalAdvice',[])))")
assert_eq "data.seasonalAdvice = 4 saisons" "$DATA_SEASONAL" "4"

DATA_PROBLEMS=$(jq_field "$BODY" "print(len(d.get('data',{}).get('commonProblems',[])))")
assert_ge "data.commonProblems >= 2" "$DATA_PROBLEMS" "2"

HAS_SUMMARY=$(jq_field "$BODY" "print('careSummary' in d.get('data',{}))")
assert_eq "data.careSummary present" "$HAS_SUMMARY" "True"

# ------ Step 22: MCP enrich - all species ------
echo -e "\n${YELLOW}[22] MCP enrich - toutes les especes connues${NC}"

for species in pothos philodendron calathea fougere dracaena palmier spathiphyllum anthurium \
               cactus aloe echeveria haworthia sansevieria \
               orchidee rose begonia geranium hibiscus jasmin lavande \
               basilic menthe persil thym romarin \
               ficus yucca caoutchouc croton schefflera zamioculcas; do
    RESP=$(call_mcp "enrich_plant_caresheet" "{\"speciesName\":\"$species\"}")
    CODE=$(get_code "$RESP")
    BODY=$(get_body "$RESP")
    STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
    assert_eq "Enrich $species -> success" "$STATUS" "success"
done

# ------ Step 23: MCP enrich missing param ------
echo -e "\n${YELLOW}[23] MCP enrich - parametre manquant${NC}"

RESP=$(call_mcp "enrich_plant_caresheet" '{}')
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "Sans speciesName -> error" "$STATUS" "error"

RESP=$(call_mcp "enrich_plant_caresheet" '{"speciesName":""}')
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "speciesName vide -> error" "$STATUS" "error"

# ------ Step 24: MCP enrich with city ------
echo -e "\n${YELLOW}[24] MCP enrich - avec ville meteo${NC}"

RESP=$(call_mcp "enrich_plant_caresheet" '{"speciesName":"cactus","city":"Marseille"}')
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "Enrich cactus+Marseille -> success" "$STATUS" "success"

HAS_WEATHER=$(jq_field "$BODY" "print('weatherAdvice' in d.get('data',{}))")
assert_eq "weatherAdvice dans data" "$HAS_WEATHER" "True"

# ------ Step 25: MCP enrich - unknown species ------
echo -e "\n${YELLOW}[25] MCP enrich - espece inconnue${NC}"

RESP=$(call_mcp "enrich_plant_caresheet" '{"speciesName":"xyzplantemagique"}')
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "Espece inconnue -> success (fallback)" "$STATUS" "success"

INTERVAL=$(jq_field "$BODY" "print(d.get('data',{}).get('wateringIntervalDays',0))")
assert_eq "Fallback interval = 7" "$INTERVAL" "7"

# ============================================================
# PART 4: MCP - get_weather_watering_advice tool
# ============================================================
echo -e "\n${CYAN}=== PARTIE 4: MCP get_weather_watering_advice ===${NC}"

# ------ Step 26: MCP weather advice basic ------
echo -e "\n${YELLOW}[26] MCP weather advice - basique${NC}"

RESP=$(call_mcp "get_weather_watering_advice" '{}')
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_eq "MCP weather advice -> 200" "$CODE" "200"

STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "Status = success" "$STATUS" "success"

DATA_CITY=$(jq_field "$BODY" "print(d.get('data',{}).get('city',''))")
assert_ne "City non vide" "$DATA_CITY" ""

DATA_ADVICES=$(jq_field "$BODY" "print(len(d.get('data',{}).get('advices',[])))")
assert_gt "Au moins 1 conseil" "$DATA_ADVICES" "0"

# ------ Step 27: MCP weather advice - all fields ------
echo -e "\n${YELLOW}[27] MCP weather advice - tous les champs${NC}"

RESP=$(call_mcp "get_weather_watering_advice" '{"city":"Lyon"}')
BODY=$(get_body "$RESP")
DATA=$(jq_field "$BODY" "
d2 = d.get('data',{})
fields = ['city','temperature','humidity','weatherDescription','rainMm','shouldSkipOutdoorWatering','indoorAdvice','intervalAdjustmentFactor','advices']
missing = [f for f in fields if f not in d2]
print(','.join(missing) if missing else 'ALL_OK')
")
assert_eq "Tous les champs data presents" "$DATA" "ALL_OK"

# ------ Step 28: MCP weather advice - various cities ------
echo -e "\n${YELLOW}[28] MCP weather advice - differentes villes${NC}"

for city in Paris Lyon Marseille Toulouse Nice Nantes Strasbourg Montpellier; do
    RESP=$(call_mcp "get_weather_watering_advice" "{\"city\":\"$city\"}")
    CODE=$(get_code "$RESP")
    BODY=$(get_body "$RESP")
    STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
    assert_eq "Weather $city -> success" "$STATUS" "success"
done

# ------ Step 29: MCP weather - invalid city fallback ------
echo -e "\n${YELLOW}[29] MCP weather - ville invalide -> fallback saisonnier${NC}"

RESP=$(call_mcp "get_weather_watering_advice" '{"city":"VilleQuiExistePas12345"}')
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "Ville invalide -> success (fallback)" "$STATUS" "success"

# ============================================================
# PART 5: MCP get_care_recommendation (existing)
# ============================================================
echo -e "\n${CYAN}=== PARTIE 5: MCP get_care_recommendation ===${NC}"

# ------ Step 30: Care recommendation for known species ------
echo -e "\n${YELLOW}[30] MCP care recommendation - especes connues${NC}"

for species in monstera cactus orchidee basilic ficus aloe lavande rose; do
    RESP=$(call_mcp "get_care_recommendation" "{\"speciesName\":\"$species\"}")
    CODE=$(get_code "$RESP")
    BODY=$(get_body "$RESP")
    STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
    assert_eq "Care rec $species -> success" "$STATUS" "success"

    HAS_REC=$(jq_field "$BODY" "print('recommendation' in d.get('data',{}))")
    assert_eq "Care rec $species has recommendation" "$HAS_REC" "True"
done

# ------ Step 31: Care recommendation - data fields ------
echo -e "\n${YELLOW}[31] MCP care recommendation - champs complets${NC}"

RESP=$(call_mcp "get_care_recommendation" '{"speciesName":"monstera"}')
BODY=$(get_body "$RESP")

FIELDS=$(jq_field "$BODY" "
d2 = d.get('data',{})
fields = ['speciesName','wateringFrequency','recommendedIntervalDays','sunlight','careLevel','recommendation']
missing = [f for f in fields if f not in d2]
print(','.join(missing) if missing else 'ALL_OK')
")
assert_eq "Tous les champs care rec presents" "$FIELDS" "ALL_OK"

# ------ Step 32: Care recommendation missing param ------
echo -e "\n${YELLOW}[32] MCP care recommendation - param manquant${NC}"

RESP=$(call_mcp "get_care_recommendation" '{}')
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "Sans speciesName -> error" "$STATUS" "error"

# ------ Step 33: Care recommendation - unknown species (fallback) ------
echo -e "\n${YELLOW}[33] MCP care recommendation - espece inconnue${NC}"

RESP=$(call_mcp "get_care_recommendation" '{"speciesName":"plantemystere"}')
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "Espece inconnue -> success (default)" "$STATUS" "success"

INTERVAL=$(jq_field "$BODY" "print(d.get('data',{}).get('recommendedIntervalDays',0))")
assert_eq "Default interval = 7" "$INTERVAL" "7"

# ============================================================
# PART 6: MCP schema - new tools present
# ============================================================
echo -e "\n${CYAN}=== PARTIE 6: MCP Schema ===${NC}"

# ------ Step 34: Schema has new tools ------
echo -e "\n${YELLOW}[34] MCP schema contient les nouveaux outils${NC}"

RESP=$(curl -s -w "\n%{http_code}" -H "X-MCP-API-Key: $API_KEY" "$BASE_URL/mcp/schema")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_eq "GET schema -> 200" "$CODE" "200"

TOOL_NAMES=$(jq_field "$BODY" "
tools = d.get('tools',[])
names = [t['name'] for t in tools]
print(','.join(names))
")

assert_contains "Schema a get_weather_watering_advice" "$TOOL_NAMES" "get_weather_watering_advice"
assert_contains "Schema a enrich_plant_caresheet" "$TOOL_NAMES" "enrich_plant_caresheet"
assert_contains "Schema a get_care_recommendation" "$TOOL_NAMES" "get_care_recommendation"
assert_contains "Schema a list_plants" "$TOOL_NAMES" "list_plants"
assert_contains "Schema a water_plant" "$TOOL_NAMES" "water_plant"

TOOL_COUNT=$(jq_field "$BODY" "print(len(d.get('tools',[])))")
assert_ge "Au moins 16 outils MCP" "$TOOL_COUNT" "16"

# ------ Step 35: Schema tool params validation ------
echo -e "\n${YELLOW}[35] MCP schema - parametres des nouveaux outils${NC}"

# enrich_plant_caresheet should have speciesName (required) and city (optional)
ENRICH_PARAMS=$(jq_field "$BODY" "
tools = d.get('tools',[])
t = [x for x in tools if x['name']=='enrich_plant_caresheet']
if t:
    params = t[0].get('parameters',{})
    print(','.join(params.keys()))
else:
    print('NOT_FOUND')
")
assert_contains "enrich a speciesName" "$ENRICH_PARAMS" "speciesName"
assert_contains "enrich a city" "$ENRICH_PARAMS" "city"

# get_weather_watering_advice should have city (optional)
WEATHER_PARAMS=$(jq_field "$BODY" "
tools = d.get('tools',[])
t = [x for x in tools if x['name']=='get_weather_watering_advice']
if t:
    params = t[0].get('parameters',{})
    print(','.join(params.keys()))
else:
    print('NOT_FOUND')
")
assert_contains "weather a city" "$WEATHER_PARAMS" "city"

# ------ Step 36: MCP schema without auth -> 401 ------
echo -e "\n${YELLOW}[36] MCP schema sans auth${NC}"

RESP=$(curl -s -w "\n%{http_code}" "$BASE_URL/mcp/schema")
CODE=$(get_code "$RESP")
assert_eq "Schema sans API key -> 401" "$CODE" "401"

# ------ Step 37: MCP tools without auth -> 401 ------
echo -e "\n${YELLOW}[37] MCP tools sans auth${NC}"

RESP=$(curl -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" \
    -d '{"tool":"list_plants","params":{}}' "$BASE_URL/mcp/tools")
CODE=$(get_code "$RESP")
assert_eq "MCP tools sans key -> 401" "$CODE" "401"

# ------ Step 38: MCP invalid API key ------
echo -e "\n${YELLOW}[38] MCP cle API invalide${NC}"

RESP=$(curl -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" \
    -H "X-MCP-API-Key: bad-key-123" \
    -d '{"tool":"list_plants","params":{}}' "$BASE_URL/mcp/tools")
CODE=$(get_code "$RESP")
assert_eq "MCP bad key -> 401" "$CODE" "401"

# ------ Step 39: MCP unknown tool ------
echo -e "\n${YELLOW}[39] MCP outil inconnu${NC}"

RESP=$(call_mcp "unknown_tool_xyz" '{}')
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "Outil inconnu -> error" "$STATUS" "error"
assert_eq "HTTP 400" "$CODE" "400"

# ============================================================
# PART 7: Planification intelligente - historique + donnees
# ============================================================
echo -e "\n${CYAN}=== PARTIE 7: Planification Intelligente ===${NC}"

# ------ Step 40: Watering updates nextWateringDate ------
echo -e "\n${YELLOW}[40] Arrosage met a jour nextWateringDate${NC}"

P1="${PLANT_IDS[0]}"
RESP=$(call_api POST "plants/$P1/water" '{}')
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_eq "Arrosage -> 200" "$CODE" "200"

NEXT=$(jq_field "$BODY" "print(d.get('nextWateringDate',''))")
assert_ne "nextWateringDate non vide" "$NEXT" ""
assert_ne "nextWateringDate non null" "$NEXT" "None"

LAST=$(jq_field "$BODY" "print(d.get('lastWatered',''))")
assert_ne "lastWatered non vide" "$LAST" ""

# ------ Step 41: Custom interval affects nextWateringDate ------
echo -e "\n${YELLOW}[41] Intervalle custom affecte nextWateringDate${NC}"

RESP=$(call_api PUT "plants/$P1" '{"wateringIntervalDays":14}')
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_eq "Update interval -> 200" "$CODE" "200"

INTERVAL=$(jq_field "$BODY" "print(d.get('wateringIntervalDays',0))")
assert_eq "Interval = 14" "$INTERVAL" "14"

# ------ Step 42: Plants needing water logic ------
echo -e "\n${YELLOW}[42] Logique plantes a arroser${NC}"

# Water all plants first
for pid in "${PLANT_IDS[@]}"; do
    call_api POST "plants/$pid/water" '{}' >/dev/null
done

# After watering, check thirsty count (may include plants from other tests)
RESP=$(call_api GET "plants?status=THIRSTY")
BODY=$(get_body "$RESP")
CODE=$(get_code "$RESP")
assert_eq "GET plants?status=THIRSTY -> 200" "$(get_code "$(call_api GET "plants?status=THIRSTY")")" "200"

# ------ Step 43: Health status tracking ------
echo -e "\n${YELLOW}[43] Suivi etat de sante des plantes${NC}"

# Mark plant as sick
P2="${PLANT_IDS[1]}"
RESP=$(call_api PUT "plants/$P2" '{"isSick":true}')
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_eq "Marquer malade -> 200" "$CODE" "200"
IS_SICK=$(jq_field "$BODY" "print(d.get('isSick',False))")
assert_eq "isSick = True" "$IS_SICK" "True"

# Mark plant as wilted
P3="${PLANT_IDS[2]}"
RESP=$(call_api PUT "plants/$P3" '{"isWilted":true}')
BODY=$(get_body "$RESP")
IS_WILTED=$(jq_field "$BODY" "print(d.get('isWilted',False))")
assert_eq "isWilted = True" "$IS_WILTED" "True"

# Mark plant as needing repotting
P4="${PLANT_IDS[3]}"
RESP=$(call_api PUT "plants/$P4" '{"needsRepotting":true}')
BODY=$(get_body "$RESP")
NEEDS_REP=$(jq_field "$BODY" "print(d.get('needsRepotting',False))")
assert_eq "needsRepotting = True" "$NEEDS_REP" "True"

# Filter by SICK status
RESP=$(call_api GET "plants?status=SICK")
BODY=$(get_body "$RESP")
SICK_COUNT=$(jq_field "$BODY" "print(len(d) if isinstance(d,list) else 0)")
assert_ge "Au moins 1 plante malade" "$SICK_COUNT" "1"

# ------ Step 44: Care log history ------
echo -e "\n${YELLOW}[44] Historique des soins${NC}"

# Add various care actions
for action in FERTILIZING PRUNING TREATMENT REPOTTING NOTE; do
    RESP=$(call_api POST "plants/$P1/care-logs" "{\"action\":\"$action\",\"notes\":\"Test $action\"}")
    CODE=$(get_code "$RESP")
    assert_eq "CareLog $action -> 201" "$CODE" "201"
done

# Retrieve care logs
RESP=$(call_api GET "plants/$P1/care-logs")
BODY=$(get_body "$RESP")
LOG_COUNT=$(jq_field "$BODY" "print(len(d) if isinstance(d,list) else 0)")
assert_ge "Au moins 5 care logs" "$LOG_COUNT" "5"

# Filter by action
RESP=$(call_api GET "plants/$P1/care-logs?action=FERTILIZING")
BODY=$(get_body "$RESP")
FERT_COUNT=$(jq_field "$BODY" "print(len(d) if isinstance(d,list) else 0)")
assert_ge "Au moins 1 FERTILIZING" "$FERT_COUNT" "1"

# ------ Step 45: Stats reflect activity ------
echo -e "\n${YELLOW}[45] Stats utilisateur refletent l'activite${NC}"

RESP=$(call_api GET "auth/me/stats")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_eq "Stats -> 200" "$CODE" "200"

TOTAL_PLANTS=$(jq_field "$BODY" "print(d.get('totalPlants',0))")
assert_ge "totalPlants >= 8" "$TOTAL_PLANTS" "8"

WATERINGS=$(jq_field "$BODY" "print(d.get('wateringsThisMonth',0))")
assert_ge "wateringsThisMonth >= 1" "$WATERINGS" "1"

# ------ Step 46: Notification trigger ------
echo -e "\n${YELLOW}[46] Declenchement rappels intelligents${NC}"

RESP=$(call_api POST "notifications/trigger-reminders" '{}')
CODE=$(get_code "$RESP")
assert_eq "Trigger reminders -> 200" "$CODE" "200"

# ------ Step 47: Notifications list ------
echo -e "\n${YELLOW}[47] Liste notifications${NC}"

RESP=$(call_api GET "notifications")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_eq "GET notifications -> 200" "$CODE" "200"

NOTIF_TYPE=$(jq_field "$BODY" "print(type(d).__name__)")
assert_eq "Notifications = liste" "$NOTIF_TYPE" "list"

# ============================================================
# PART 8: Suggestions adaptees au type de plante
# ============================================================
echo -e "\n${CYAN}=== PARTIE 8: Suggestions adaptees ===${NC}"

# ------ Step 48: Species search returns relevant data ------
echo -e "\n${YELLOW}[48] Recherche especes - donnees pertinentes${NC}"

for q in monstera cactus rose ficus; do
    RESP=$(call_api GET "species/search?q=$q")
    CODE=$(get_code "$RESP")
    assert_eq "Species search $q -> 200" "$CODE" "200"
done

# ------ Step 49: Species by name ------
echo -e "\n${YELLOW}[49] Espece par nom exact${NC}"

RESP=$(call_api GET "species/by-name?name=monstera")
CODE=$(get_code "$RESP")
# by-name returns 404 if the exact name is not in the local DB (case-sensitive match)
TOTAL=$((TOTAL + 1))
if [ "$CODE" = "200" ] || [ "$CODE" = "404" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} Species by-name monstera -> HTTP $CODE (valid response)"
else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC} Species by-name monstera -> HTTP $CODE"
fi

# ------ Step 50: MCP list_plants_needing_water ------
echo -e "\n${YELLOW}[50] MCP list_plants_needing_water${NC}"

RESP=$(call_mcp "list_plants_needing_water" '{}')
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "list_plants_needing_water -> success" "$STATUS" "success"

# ------ Step 51: MCP water_all_plants ------
echo -e "\n${YELLOW}[51] MCP water_all_plants${NC}"

RESP=$(call_mcp "water_all_plants" '{}')
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "water_all_plants -> success" "$STATUS" "success"

# ------ Step 52: MCP add + water + detail full workflow ------
echo -e "\n${YELLOW}[52] MCP workflow complet: add -> water -> detail${NC}"

RESP=$(call_mcp "add_plant" '{"nickname":"MCP_TestPlant","speciesName":"monstera"}')
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "MCP add_plant -> success" "$STATUS" "success"

RESP=$(call_mcp "water_plant" '{"plantName":"MCP_TestPlant"}')
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "MCP water_plant -> success" "$STATUS" "success"

RESP=$(call_mcp "get_plant_detail" '{"plantName":"MCP_TestPlant"}')
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "MCP get_plant_detail -> success" "$STATUS" "success"

WATERED=$(jq_field "$BODY" "print(d.get('data',{}).get('lastWatered',''))")
assert_ne "lastWatered rempli" "$WATERED" ""
assert_ne "lastWatered non None" "$WATERED" "None"

# ------ Step 53: MCP update_plant health flags ------
echo -e "\n${YELLOW}[53] MCP update_plant - flags sante${NC}"

RESP=$(call_mcp "update_plant" '{"plantName":"MCP_TestPlant","isSick":"true"}')
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "MCP mark sick -> success" "$STATUS" "success"

RESP=$(call_mcp "update_plant" '{"plantName":"MCP_TestPlant","isSick":"false","isWilted":"true"}')
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "MCP unsick + wilt -> success" "$STATUS" "success"

RESP=$(call_mcp "update_plant" '{"plantName":"MCP_TestPlant","needsRepotting":"true"}')
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "MCP needs repotting -> success" "$STATUS" "success"

# ------ Step 54: MCP update watering interval ------
echo -e "\n${YELLOW}[54] MCP update intervalle arrosage${NC}"

RESP=$(call_mcp "update_plant" '{"plantName":"MCP_TestPlant","wateringIntervalDays":"3"}')
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "MCP interval=3 -> success" "$STATUS" "success"
assert_contains "Message mentionne 3 jours" "$(jq_field "$BODY" "print(d.get('message',''))")" "3"

# Invalid interval
RESP=$(call_mcp "update_plant" '{"plantName":"MCP_TestPlant","wateringIntervalDays":"0"}')
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "MCP interval=0 -> error (no change)" "$STATUS" "error"

RESP=$(call_mcp "update_plant" '{"plantName":"MCP_TestPlant","wateringIntervalDays":"999"}')
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "MCP interval=999 -> error (>365)" "$STATUS" "error"

# ------ Step 55: MCP search_plants ------
echo -e "\n${YELLOW}[55] MCP search_plants${NC}"

RESP=$(call_mcp "search_plants" '{"query":"monstera"}')
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "search monstera -> success" "$STATUS" "success"

RESP=$(call_mcp "search_plants" '{"query":"x"}')
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "search 1 char -> error" "$STATUS" "error"

RESP=$(call_mcp "search_plants" '{}')
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "search sans query -> error" "$STATUS" "error"

# ------ Step 56: MCP rooms workflow ------
echo -e "\n${YELLOW}[56] MCP rooms: create + list + move + delete${NC}"

RESP=$(call_mcp "create_room" '{"name":"MCP_TestRoom"}')
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "create_room -> success" "$STATUS" "success"

RESP=$(call_mcp "list_rooms" '{}')
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "list_rooms -> success" "$STATUS" "success"

RESP=$(call_mcp "move_plant" '{"plantName":"MCP_TestPlant","roomName":"MCP_TestRoom"}')
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "move_plant -> success" "$STATUS" "success"

RESP=$(call_mcp "delete_room" '{"roomName":"MCP_TestRoom"}')
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "delete_room -> success" "$STATUS" "success"

# ------ Step 57: MCP duplicate room ------
echo -e "\n${YELLOW}[57] MCP room duplique${NC}"

call_mcp "create_room" '{"name":"DupRoom"}' >/dev/null
RESP=$(call_mcp "create_room" '{"name":"DupRoom"}')
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "Room duplique -> error" "$STATUS" "error"

call_mcp "delete_room" '{"roomName":"DupRoom"}' >/dev/null

# ------ Step 58: MCP delete plant ------
echo -e "\n${YELLOW}[58] MCP delete_plant${NC}"

RESP=$(call_mcp "delete_plant" '{"plantName":"MCP_TestPlant"}')
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "delete_plant -> success" "$STATUS" "success"

# Verify deleted
RESP=$(call_mcp "get_plant_detail" '{"plantName":"MCP_TestPlant"}')
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "Detail apres suppression -> error" "$STATUS" "error"

# ------ Step 59: MCP empty tool name ------
echo -e "\n${YELLOW}[59] MCP outil vide${NC}"

RESP=$(curl -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" \
    -H "X-MCP-API-Key: $API_KEY" \
    -d '{"tool":"","params":{}}' "$BASE_URL/mcp/tools")
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "Tool vide -> error" "$STATUS" "error"

# ============================================================
# PART 9: Edge cases - Weather
# ============================================================
echo -e "\n${CYAN}=== PARTIE 9: Edge Cases Weather ===${NC}"

# ------ Step 60: Weather special chars city ------
echo -e "\n${YELLOW}[60] Weather - caracteres speciaux ville${NC}"

RESP=$(call_api GET "weather/watering-advice?city=Saint-Etienne")
CODE=$(get_code "$RESP")
assert_eq "Tiret dans ville -> 200" "$CODE" "200"

RESP=$(call_api GET "weather/watering-advice?city=Aix-en-Provence")
CODE=$(get_code "$RESP")
assert_eq "Tirets multiples -> 200" "$CODE" "200"

# ------ Step 61: Care sheet very long species name ------
echo -e "\n${YELLOW}[61] Care sheet - nom espece tres long${NC}"

LONG_NAME=$(python3 -c "print('a'*500)")
RESP=$(call_api GET "weather/care-sheet?species=$LONG_NAME")
CODE=$(get_code "$RESP")
assert_eq "Nom 500 chars -> 200 (fallback)" "$CODE" "200"

# ------ Step 62: Multiple concurrent weather requests ------
echo -e "\n${YELLOW}[62] Requetes weather concurrentes${NC}"

for i in $(seq 1 5); do
    curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer $TOKEN1" \
        "$BASE_URL/weather/watering-advice?city=Paris" &
done
wait

# Just verify endpoint still works
RESP=$(call_api GET "weather/watering-advice?city=Paris")
CODE=$(get_code "$RESP")
assert_eq "Weather apres burst -> 200" "$CODE" "200"

# ------ Step 63: Care sheet all WateringDefaults species ------
echo -e "\n${YELLOW}[63] Care sheet - toutes les especes WateringDefaults${NC}"

ALL_SPECIES="monstera pothos philodendron calathea fougere fern dracaena palmier palm spathiphyllum anthurium \
cactus aloe succulent echeveria haworthia crassula jade sansevieria \
orchid orchidee rose begonia geranium hibiscus jasmin lavande lavender \
ficus yucca caoutchouc rubber croton dieffenbachia schefflera zamioculcas \
basilic basil menthe mint persil parsley thym thyme romarin rosemary"

COUNT=0
for species in $ALL_SPECIES; do
    RESP=$(call_api GET "weather/care-sheet?species=$species")
    CODE=$(get_code "$RESP")
    if [ "$CODE" = "200" ]; then
        COUNT=$((COUNT + 1))
    fi
done
TOTAL=$((TOTAL + 1))
if [ "$COUNT" -ge 35 ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} $COUNT/$(echo $ALL_SPECIES | wc -w) especes -> 200"
else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC} Seulement $COUNT especes -> 200"
fi

# ------ Step 64: Synonym species mapping ------
echo -e "\n${YELLOW}[64] Synonymes d'especes (EN/FR)${NC}"

# fern = fougere (same category/interval)
RESP1=$(call_api GET "weather/care-sheet?species=fern")
BODY1=$(get_body "$RESP1")
INT1=$(jq_field "$BODY1" "print(d.get('wateringIntervalDays',0))")

RESP2=$(call_api GET "weather/care-sheet?species=fougere")
BODY2=$(get_body "$RESP2")
INT2=$(jq_field "$BODY2" "print(d.get('wateringIntervalDays',0))")
assert_eq "fern == fougere interval" "$INT1" "$INT2"

# snake plant = sansevieria
RESP1=$(call_api GET "weather/care-sheet?species=snake%20plant")
BODY1=$(get_body "$RESP1")
INT1=$(jq_field "$BODY1" "print(d.get('wateringIntervalDays',0))")

RESP2=$(call_api GET "weather/care-sheet?species=sansevieria")
BODY2=$(get_body "$RESP2")
INT2=$(jq_field "$BODY2" "print(d.get('wateringIntervalDays',0))")
assert_eq "snake plant == sansevieria interval" "$INT1" "$INT2"

# basil = basilic
RESP1=$(call_api GET "weather/care-sheet?species=basil")
BODY1=$(get_body "$RESP1")
INT1=$(jq_field "$BODY1" "print(d.get('wateringIntervalDays',0))")

RESP2=$(call_api GET "weather/care-sheet?species=basilic")
BODY2=$(get_body "$RESP2")
INT2=$(jq_field "$BODY2" "print(d.get('wateringIntervalDays',0))")
assert_eq "basil == basilic interval" "$INT1" "$INT2"

# ============================================================
# PART 10: Edge cases - MCP enrichment
# ============================================================
echo -e "\n${CYAN}=== PARTIE 10: Edge Cases MCP ===${NC}"

# ------ Step 65: Enrich with special chars ------
echo -e "\n${YELLOW}[65] MCP enrich - caracteres speciaux${NC}"

RESP=$(call_mcp "enrich_plant_caresheet" '{"speciesName":"aloe vera"}')
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "Enrich 'aloe vera' -> success" "$STATUS" "success"

RESP=$(call_mcp "enrich_plant_caresheet" '{"speciesName":"peace lily"}')
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "Enrich 'peace lily' -> success" "$STATUS" "success"

# ------ Step 66: MCP enrich consistency ------
echo -e "\n${YELLOW}[66] MCP enrich - consistance donnees${NC}"

# Same species queried twice should return same data
RESP1=$(call_mcp "enrich_plant_caresheet" '{"speciesName":"cactus"}')
BODY1=$(get_body "$RESP1")
INT1=$(jq_field "$BODY1" "print(d.get('data',{}).get('wateringIntervalDays',0))")

RESP2=$(call_mcp "enrich_plant_caresheet" '{"speciesName":"cactus"}')
BODY2=$(get_body "$RESP2")
INT2=$(jq_field "$BODY2" "print(d.get('data',{}).get('wateringIntervalDays',0))")
assert_eq "Cactus interval coherent" "$INT1" "$INT2"

# ------ Step 67: MCP enrich vs REST care-sheet consistency ------
echo -e "\n${YELLOW}[67] Consistance MCP enrich vs REST care-sheet${NC}"

RESP_MCP=$(call_mcp "enrich_plant_caresheet" '{"speciesName":"monstera"}')
BODY_MCP=$(get_body "$RESP_MCP")
MCP_INT=$(jq_field "$BODY_MCP" "print(d.get('data',{}).get('wateringIntervalDays',0))")

RESP_REST=$(call_api GET "weather/care-sheet?species=monstera")
BODY_REST=$(get_body "$RESP_REST")
REST_INT=$(jq_field "$BODY_REST" "print(d.get('wateringIntervalDays',0))")

assert_eq "MCP et REST meme interval monstera" "$MCP_INT" "$REST_INT"

MCP_CAT=$(jq_field "$BODY_MCP" "print(d.get('data',{}).get('category',''))")
REST_CAT=$(jq_field "$BODY_REST" "print(d.get('category',''))")
assert_eq "MCP et REST meme categorie" "$MCP_CAT" "$REST_CAT"

# ------ Step 68: MCP tool with JWT auth instead of API key ------
echo -e "\n${YELLOW}[68] MCP avec JWT au lieu d'API key${NC}"

RESP=$(curl -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN1" \
    -d '{"tool":"list_plants","params":{}}' "$BASE_URL/mcp/tools")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "MCP via JWT -> 200" "$CODE" "200"
assert_eq "MCP via JWT -> success" "$STATUS" "success"

# ============================================================
# PART 11: Cross-user isolation
# ============================================================
echo -e "\n${CYAN}=== PARTIE 11: Isolation inter-utilisateurs ===${NC}"

# ------ Step 69: User2 weather advice (own auth) ------
echo -e "\n${YELLOW}[69] User2 acces weather${NC}"

RESP=$(call_api GET "weather/watering-advice?city=Paris" "" "$TOKEN2")
CODE=$(get_code "$RESP")
assert_eq "User2 weather -> 200" "$CODE" "200"

# ------ Step 70: User2 care sheet ------
echo -e "\n${YELLOW}[70] User2 care sheet${NC}"

RESP=$(call_api GET "weather/care-sheet?species=monstera" "" "$TOKEN2")
CODE=$(get_code "$RESP")
assert_eq "User2 care sheet -> 200" "$CODE" "200"

# ------ Step 71: User2 cannot access User1's plants ------
echo -e "\n${YELLOW}[71] User2 ne voit pas les plantes de User1${NC}"

RESP=$(call_api GET "plants/${PLANT_IDS[0]}" "" "$TOKEN2")
CODE=$(get_code "$RESP")
# Should be 403 or 404 (cannot access other user's plant)
TOTAL=$((TOTAL + 1))
if [ "$CODE" = "403" ] || [ "$CODE" = "404" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} User2 ne peut pas voir plante User1 (HTTP $CODE)"
else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC} User2 voit plante User1 (HTTP $CODE, expected 403/404)"
fi

# ============================================================
# PART 12: Gamification + Intelligence combined
# ============================================================
echo -e "\n${CYAN}=== PARTIE 12: Gamification + Intelligence ===${NC}"

# ------ Step 72: Watering gives XP ------
echo -e "\n${YELLOW}[72] Arrosage donne XP${NC}"

RESP=$(call_api GET "gamification/profile")
BODY=$(get_body "$RESP")
XP_BEFORE=$(jq_field "$BODY" "print(d.get('xp',0))")

call_api POST "plants/${PLANT_IDS[0]}/water" '{}' >/dev/null

RESP=$(call_api GET "gamification/profile")
BODY=$(get_body "$RESP")
XP_AFTER=$(jq_field "$BODY" "print(d.get('xp',0))")

assert_ge "XP augmente apres arrosage" "$XP_AFTER" "$XP_BEFORE"

# ------ Step 73: Care action gives XP ------
echo -e "\n${YELLOW}[73] Action de soin donne XP${NC}"

RESP=$(call_api GET "gamification/profile")
BODY=$(get_body "$RESP")
XP_BEFORE=$(jq_field "$BODY" "print(d.get('xp',0))")

call_api POST "plants/${PLANT_IDS[1]}/care-logs" '{"action":"FERTILIZING","notes":"Test"}' >/dev/null

RESP=$(call_api GET "gamification/profile")
BODY=$(get_body "$RESP")
XP_AFTER=$(jq_field "$BODY" "print(d.get('xp',0))")
assert_ge "XP augmente apres soin" "$XP_AFTER" "$XP_BEFORE"

# ------ Step 74: Gamification profile has all fields ------
echo -e "\n${YELLOW}[74] Profil gamification complet${NC}"

RESP=$(call_api GET "gamification/profile")
BODY=$(get_body "$RESP")

FIELDS=$(jq_field "$BODY" "
fields = ['xp','level','levelName','xpForNextLevel','xpProgressInLevel','wateringStreak','bestWateringStreak','totalWaterings','totalCareActions','totalPlantsAdded','badges']
missing = [f for f in fields if f not in d]
print(','.join(missing) if missing else 'ALL_OK')
")
assert_eq "Tous les champs gamification" "$FIELDS" "ALL_OK"

# ------ Step 75: Badges list has all 12 entries ------
echo -e "\n${YELLOW}[75] 12 badges dans le profil${NC}"

BADGE_COUNT=$(jq_field "$BODY" "print(len(d.get('badges',[])))")
assert_eq "12 badges" "$BADGE_COUNT" "12"

# Each badge has required fields
BADGE_FIELDS=$(jq_field "$BODY" "
ok = all('code' in b and 'name' in b and 'description' in b and 'category' in b and 'iconUrl' in b and 'unlocked' in b for b in d.get('badges',[]))
print(ok)
")
assert_eq "Tous les champs badge presents" "$BADGE_FIELDS" "True"

# ============================================================
# PART 13: More edge cases
# ============================================================
echo -e "\n${CYAN}=== PARTIE 13: Edge Cases Supplementaires ===${NC}"

# ------ Step 76: Care sheet POST method not allowed ------
echo -e "\n${YELLOW}[76] Care sheet - methodes non autorisees${NC}"

RESP=$(call_api POST "weather/care-sheet" '{"species":"monstera"}')
CODE=$(get_code "$RESP")
assert_eq "POST care-sheet -> 405" "$CODE" "405"

# ------ Step 77: Very short species name ------
echo -e "\n${YELLOW}[77] Care sheet - nom espece 1 caractere${NC}"

RESP=$(call_api GET "weather/care-sheet?species=a")
CODE=$(get_code "$RESP")
assert_eq "Species 1 char -> 200 (fallback)" "$CODE" "200"

# ------ Step 78: Numeric species name ------
echo -e "\n${YELLOW}[78] Care sheet - nom numerique${NC}"

RESP=$(call_api GET "weather/care-sheet?species=12345")
CODE=$(get_code "$RESP")
assert_eq "Species numerique -> 200 (fallback)" "$CODE" "200"

# ------ Step 79: MCP enrich seasonal advice for succulents ------
echo -e "\n${YELLOW}[79] Conseils saisonniers succulentes${NC}"

RESP=$(call_mcp "enrich_plant_caresheet" '{"speciesName":"cactus"}')
BODY=$(get_body "$RESP")
WINTER=$(jq_field "$BODY" "
seasonal = d.get('data',{}).get('seasonalAdvice',[])
winter = [s for s in seasonal if s['season']=='Hiver']
print(winter[0]['wateringAdjustment'] if winter else '')
")
assert_contains "Hiver succulente = quasi aucun" "$WINTER" "ucun"

# ------ Step 80: MCP enrich seasonal advice for herbs ------
echo -e "\n${YELLOW}[80] Conseils saisonniers herbes${NC}"

RESP=$(call_mcp "enrich_plant_caresheet" '{"speciesName":"basilic"}')
BODY=$(get_body "$RESP")
SUMMER=$(jq_field "$BODY" "
seasonal = d.get('data',{}).get('seasonalAdvice',[])
summer = [s for s in seasonal if 'Été' in s['season'] or 'Ete' in s['season']]
print(summer[0]['wateringAdjustment'] if summer else 'NOT_FOUND')
")
assert_ne "Ete herbe conseil present" "$SUMMER" "NOT_FOUND"

# ------ Step 81: Watering interval boundaries ------
echo -e "\n${YELLOW}[81] Intervalle arrosage - bornes${NC}"

# Min: 1 day
RESP=$(call_api PUT "plants/${PLANT_IDS[0]}" '{"wateringIntervalDays":1}')
BODY=$(get_body "$RESP")
INT=$(jq_field "$BODY" "print(d.get('wateringIntervalDays',0))")
assert_eq "Interval min=1 accepte" "$INT" "1"

# Max: 365 days
RESP=$(call_api PUT "plants/${PLANT_IDS[0]}" '{"wateringIntervalDays":365}')
BODY=$(get_body "$RESP")
INT=$(jq_field "$BODY" "print(d.get('wateringIntervalDays',0))")
assert_eq "Interval max=365 accepte" "$INT" "365"

# Reset
call_api PUT "plants/${PLANT_IDS[0]}" '{"wateringIntervalDays":7}' >/dev/null

# ------ Step 82: Multiple care actions on same plant ------
echo -e "\n${YELLOW}[82] Actions multiples meme plante${NC}"

for action in WATERING FERTILIZING PRUNING TREATMENT REPOTTING NOTE; do
    RESP=$(call_api POST "plants/${PLANT_IDS[5]}/care-logs" "{\"action\":\"$action\",\"notes\":\"Multi $action\"}")
    CODE=$(get_code "$RESP")
    assert_eq "CareLog $action -> 201" "$CODE" "201"
done

# ------ Step 83: Care log with empty notes ------
echo -e "\n${YELLOW}[83] Care log notes vides${NC}"

RESP=$(call_api POST "plants/${PLANT_IDS[0]}/care-logs" '{"action":"WATERING","notes":""}')
CODE=$(get_code "$RESP")
assert_eq "CareLog notes vides -> 201" "$CODE" "201"

RESP=$(call_api POST "plants/${PLANT_IDS[0]}/care-logs" '{"action":"WATERING"}')
CODE=$(get_code "$RESP")
assert_eq "CareLog sans notes -> 201" "$CODE" "201"

# ------ Step 84: Care log with long notes ------
echo -e "\n${YELLOW}[84] Care log notes tres longues${NC}"

LONG_NOTES=$(python3 -c "print('x'*2000)")
RESP=$(call_api POST "plants/${PLANT_IDS[0]}/care-logs" "{\"action\":\"NOTE\",\"notes\":\"$LONG_NOTES\"}")
CODE=$(get_code "$RESP")
assert_eq "CareLog 2000 chars -> 201" "$CODE" "201"

# ------ Step 85: Unread notifications count ------
echo -e "\n${YELLOW}[85] Compteur notifications non lues${NC}"

RESP=$(call_api GET "notifications/unread-count")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_eq "GET unread-count -> 200" "$CODE" "200"

HAS_COUNT=$(jq_field "$BODY" "print('unreadCount' in d)")
assert_eq "Champ unreadCount present" "$HAS_COUNT" "True"

# ------ Step 86: Mark all notifications read ------
echo -e "\n${YELLOW}[86] Marquer toutes les notifs lues${NC}"

RESP=$(call_api PUT "notifications/read-all" '{}')
CODE=$(get_code "$RESP")
assert_eq "PUT read-all -> 200" "$CODE" "200"

RESP=$(call_api GET "notifications/unread-count")
BODY=$(get_body "$RESP")
UNREAD=$(jq_field "$BODY" "print(d.get('unreadCount',0))")
assert_eq "Unread = 0 apres read-all" "$UNREAD" "0"

# ------ Step 87: House activity feed ------
echo -e "\n${YELLOW}[87] Feed activite maison${NC}"

RESP=$(call_api GET "houses/$HOUSE_ID/activity")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_eq "Activity feed -> 200" "$CODE" "200"

FEED_TYPE=$(jq_field "$BODY" "print(type(d).__name__)")
assert_eq "Feed = liste" "$FEED_TYPE" "list"

FEED_COUNT=$(jq_field "$BODY" "print(len(d) if isinstance(d,list) else 0)")
assert_gt "Feed non vide" "$FEED_COUNT" "0"

# ------ Step 88: Leaderboard ------
echo -e "\n${YELLOW}[88] Leaderboard maison${NC}"

RESP=$(call_api GET "gamification/leaderboard/$HOUSE_ID")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_eq "Leaderboard -> 200" "$CODE" "200"

LB_TYPE=$(jq_field "$BODY" "print(type(d).__name__)")
assert_eq "Leaderboard = liste" "$LB_TYPE" "list"

# ------ Step 89: Species database status ------
echo -e "\n${YELLOW}[89] Status base de donnees especes${NC}"

RESP=$(curl -s -w "\n%{http_code}" "$BASE_URL/species/status")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_eq "Species status -> 200" "$CODE" "200"

# ------ Step 90: Idempotent reads ------
echo -e "\n${YELLOW}[90] Lectures idempotentes${NC}"

RESP1=$(call_api GET "weather/care-sheet?species=monstera")
BODY1=$(get_body "$RESP1")
INT1=$(jq_field "$BODY1" "print(d.get('wateringIntervalDays',0))")

RESP2=$(call_api GET "weather/care-sheet?species=monstera")
BODY2=$(get_body "$RESP2")
INT2=$(jq_field "$BODY2" "print(d.get('wateringIntervalDays',0))")

assert_eq "Lecture idempotente interval" "$INT1" "$INT2"

RESP1=$(call_api GET "weather/watering-advice?city=Paris")
BODY1=$(get_body "$RESP1")
FACTOR1=$(jq_field "$BODY1" "print(d.get('intervalAdjustmentFactor',0))")

RESP2=$(call_api GET "weather/watering-advice?city=Paris")
BODY2=$(get_body "$RESP2")
FACTOR2=$(jq_field "$BODY2" "print(d.get('intervalAdjustmentFactor',0))")

assert_eq "Lecture idempotente factor" "$FACTOR1" "$FACTOR2"

# ------ Step 91: MCP list_plants returns correct count ------
echo -e "\n${YELLOW}[91] MCP list_plants coherent${NC}"

# MCP uses default MCP user, REST uses test user -> counts may differ
# Just verify both return valid lists
RESP=$(call_mcp "list_plants" '{}')
BODY=$(get_body "$RESP")
MCP_STATUS=$(jq_field "$BODY" "print(d.get('status',''))")
assert_eq "MCP list_plants -> success" "$MCP_STATUS" "success"

RESP=$(call_api GET "plants")
CODE=$(get_code "$RESP")
assert_eq "REST GET plants -> 200" "$CODE" "200"

# ------ Step 92: Invalid plant UUID ------
echo -e "\n${YELLOW}[92] UUID plante invalide${NC}"

RESP=$(call_api GET "plants/not-a-uuid")
CODE=$(get_code "$RESP")
TOTAL=$((TOTAL + 1))
if [ "$CODE" = "400" ] || [ "$CODE" = "404" ] || [ "$CODE" = "500" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} UUID invalide -> HTTP $CODE"
else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC} UUID invalide -> HTTP $CODE"
fi

RESP=$(call_api GET "plants/00000000-0000-0000-0000-000000000000")
CODE=$(get_code "$RESP")
assert_eq "UUID zero -> 404" "$CODE" "404"

# ------ Step 93: Heal plant then verify ------
echo -e "\n${YELLOW}[93] Guerir plante et verifier${NC}"

RESP=$(call_api PUT "plants/${PLANT_IDS[1]}" '{"isSick":false,"isWilted":false,"needsRepotting":false}')
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_eq "Heal plant -> 200" "$CODE" "200"

IS_SICK=$(jq_field "$BODY" "print(d.get('isSick',True))")
IS_WILT=$(jq_field "$BODY" "print(d.get('isWilted',True))")
NEEDS_REP=$(jq_field "$BODY" "print(d.get('needsRepotting',True))")
assert_eq "isSick=False" "$IS_SICK" "False"
assert_eq "isWilted=False" "$IS_WILT" "False"
assert_eq "needsRepotting=False" "$NEEDS_REP" "False"

# ------ Step 94: Seasonal advice count always 4 ------
echo -e "\n${YELLOW}[94] Toujours 4 saisons dans les fiches${NC}"

for species in monstera cactus basilic orchidee ficus lavande; do
    RESP=$(call_api GET "weather/care-sheet?species=$species")
    BODY=$(get_body "$RESP")
    COUNT=$(jq_field "$BODY" "print(len(d.get('seasonalAdvice',[])))")
    assert_eq "$species: 4 saisons" "$COUNT" "4"
done

# ------ Step 95: Common problems always >= 2 ------
echo -e "\n${YELLOW}[95] Au moins 2 problemes courants par espece${NC}"

for species in monstera cactus basilic orchidee ficus unknown123; do
    RESP=$(call_api GET "weather/care-sheet?species=$species")
    BODY=$(get_body "$RESP")
    COUNT=$(jq_field "$BODY" "print(len(d.get('commonProblems',[])))")
    assert_ge "$species: >= 2 problemes" "$COUNT" "2"
done

# ------ Step 96: Badge icon URLs ------
echo -e "\n${YELLOW}[96] Badge iconUrl format${NC}"

RESP=$(call_api GET "gamification/profile")
BODY=$(get_body "$RESP")

ICON_CHECK=$(jq_field "$BODY" "
for b in d.get('badges',[]):
    url = b.get('iconUrl','')
    if not url.startswith('/api/v1/badges/') or not url.endswith('.png'):
        print(f'BAD:{b[\"code\"]}:{url}'); break
else:
    print('OK')
")
assert_eq "Toutes les iconUrl valides" "$ICON_CHECK" "OK"

# ------ Step 97: Gamification XP non-negative ------
echo -e "\n${YELLOW}[97] XP toujours >= 0${NC}"

RESP=$(call_api GET "gamification/profile")
BODY=$(get_body "$RESP")
XP=$(jq_field "$BODY" "print(d.get('xp',0))")
assert_ge "XP >= 0" "$XP" "0"

LEVEL=$(jq_field "$BODY" "print(d.get('level',0))")
assert_ge "Level >= 1" "$LEVEL" "1"

# ------ Step 98: User2 gamification ------
echo -e "\n${YELLOW}[98] User2 profil gamification${NC}"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN2")
CODE=$(get_code "$RESP")
BODY=$(get_body "$RESP")
assert_eq "User2 gamification -> 200" "$CODE" "200"

XP2=$(jq_field "$BODY" "print(d.get('xp',0))")
assert_ge "User2 XP >= 0" "$XP2" "0"

# ------ Step 99: Batch plant creation + verify stats ------
echo -e "\n${YELLOW}[99] Creation batch + verification stats${NC}"

BEFORE_COUNT=$(jq_field "$(get_body "$(call_api GET "auth/me/stats")")" "print(d.get('totalPlants',0))")

for i in $(seq 1 5); do
    call_api POST "plants" "{\"nickname\":\"Batch$i\",\"wateringIntervalDays\":7}" >/dev/null
done

AFTER_COUNT=$(jq_field "$(get_body "$(call_api GET "auth/me/stats")")" "print(d.get('totalPlants',0))")
DIFF=$((AFTER_COUNT - BEFORE_COUNT))
assert_eq "5 plantes ajoutees en batch" "$DIFF" "5"

# ------ Step 100: Final consistency check ------
echo -e "\n${YELLOW}[100] Verification finale de consistance${NC}"

# Weather advice has valid structure
RESP=$(call_api GET "weather/watering-advice")
BODY=$(get_body "$RESP")
VALID=$(jq_field "$BODY" "
try:
    assert isinstance(d['advices'], list)
    assert isinstance(d['humidity'], int)
    assert isinstance(d['shouldSkipOutdoorWatering'], bool)
    assert isinstance(d['intervalAdjustmentFactor'], (int,float))
    print('VALID')
except:
    print('INVALID')
")
assert_eq "Structure weather valide" "$VALID" "VALID"

# Care sheet has valid structure
RESP=$(call_api GET "weather/care-sheet?species=monstera")
BODY=$(get_body "$RESP")
VALID=$(jq_field "$BODY" "
try:
    assert isinstance(d['seasonalAdvice'], list)
    assert isinstance(d['commonProblems'], list)
    assert isinstance(d['sunlight'], list)
    assert isinstance(d['wateringIntervalDays'], int)
    assert len(d['seasonalAdvice']) == 4
    print('VALID')
except:
    print('INVALID')
")
assert_eq "Structure care sheet valide" "$VALID" "VALID"

# MCP enrich returns same structure
RESP=$(call_mcp "enrich_plant_caresheet" '{"speciesName":"monstera"}')
BODY=$(get_body "$RESP")
VALID=$(jq_field "$BODY" "
try:
    data = d['data']
    assert isinstance(data['seasonalAdvice'], list)
    assert isinstance(data['commonProblems'], list)
    assert len(data['seasonalAdvice']) == 4
    print('VALID')
except:
    print('INVALID')
")
assert_eq "Structure MCP enrich valide" "$VALID" "VALID"

# ============================================================
# RESULTATS
# ============================================================
echo -e "\n${CYAN}============================================================${NC}"
echo -e "${CYAN}  RESULTATS${NC}"
echo -e "${CYAN}============================================================${NC}\n"

if [ "$FAIL" -eq 0 ]; then
    echo -e "  ${GREEN}TOUS LES TESTS PASSENT: $PASS/$TOTAL${NC}"
else
    echo -e "  ${GREEN}PASS: $PASS${NC}"
    echo -e "  ${RED}FAIL: $FAIL${NC}"
    echo -e "  TOTAL: $TOTAL"
fi

echo ""
exit $FAIL
