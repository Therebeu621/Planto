#!/bin/bash
#
# Script de test complet du systeme de gamification
# Usage: ./test-gamification.sh [BASE_URL]
#
# Prerequis: le backend doit tourner (./mvnw quarkus:dev)
# Utilise des emails uniques (timestamp) pour chaque run
#

BASE_URL="${1:-http://localhost:8080/api/v1}"
PASS=0
FAIL=0
TOTAL=0

# Unique suffix per run to avoid stale data
TS=$(date +%s)

TOKEN1=""
TOKEN2=""
TOKEN3=""
TOKEN4=""
USER1_ID=""
USER2_ID=""
USER3_ID=""
HOUSE_ID=""
INVITE_CODE=""
PLANT1_ID=""
PLANT2_ID=""
PLANT3_ID=""
PLANT4_ID=""
PLANT5_ID=""
PLANT_U2=""

# Couleurs
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

run_test() {
    local test_name="$1"
    local response="$2"
    local expected_code="$3"
    local check_field="$4"

    TOTAL=$((TOTAL + 1))

    local http_code
    http_code=$(echo "$response" | tail -1)
    local body
    body=$(echo "$response" | sed '$d')

    local passed=true

    if [ "$http_code" != "$expected_code" ]; then
        passed=false
    fi

    if [ -n "$check_field" ] && ! echo "$body" | grep -q "$check_field"; then
        passed=false
    fi

    if [ "$passed" = true ]; then
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC} $test_name (HTTP $http_code)"
    else
        FAIL=$((FAIL + 1))
        echo -e "  ${RED}FAIL${NC} $test_name (HTTP $http_code, expected $expected_code)"
        if [ -n "$check_field" ] && ! echo "$body" | grep -q "$check_field"; then
            echo -e "       Expected to find: $check_field"
        fi
        echo -e "       Body: $(echo "$body" | head -3)"
    fi
}

run_test_value() {
    local test_name="$1"
    local response="$2"
    local expected_code="$3"
    local field="$4"
    local expected_value="$5"

    TOTAL=$((TOTAL + 1))

    local http_code
    http_code=$(echo "$response" | tail -1)
    local body
    body=$(echo "$response" | sed '$d')

    local passed=true

    if [ "$http_code" != "$expected_code" ]; then
        passed=false
    fi

    if [ -n "$field" ] && [ -n "$expected_value" ]; then
        local actual
        actual=$(echo "$body" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('$field',''))" 2>/dev/null)
        if [ "$actual" != "$expected_value" ]; then
            FAIL=$((FAIL + 1))
            echo -e "  ${RED}FAIL${NC} $test_name (HTTP $http_code) - $field: got '$actual', expected '$expected_value'"
            return
        fi
    fi

    if [ "$passed" = true ]; then
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC} $test_name (HTTP $http_code)"
    else
        FAIL=$((FAIL + 1))
        echo -e "  ${RED}FAIL${NC} $test_name (HTTP $http_code, expected $expected_code)"
    fi
}

get_field() {
    local body="$1"
    local field="$2"
    echo "$body" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('$field',''))" 2>/dev/null
}

has_badge() {
    local body="$1"
    local badge_code="$2"
    echo "$body" | python3 -c "
import sys,json
d=json.load(sys.stdin)
badges = d.get('badges',[])
b = [x for x in badges if x['code']=='$badge_code']
print('true' if b and b[0]['unlocked'] else 'false')
" 2>/dev/null
}

count_unlocked() {
    local body="$1"
    echo "$body" | python3 -c "
import sys,json
d=json.load(sys.stdin)
print(sum(1 for b in d.get('badges',[]) if b['unlocked']))
" 2>/dev/null
}

do_login() {
    local email="$1"
    local password="$2"
    local display_name="$3"

    local resp
    resp=$(curl -s -w "\n%{http_code}" \
        -X POST -H "Content-Type: application/json" \
        -d "{\"email\":\"$email\",\"password\":\"$password\"}" \
        "$BASE_URL/auth/login")
    local code=$(echo "$resp" | tail -1)
    local body=$(echo "$resp" | sed '$d')

    if [ "$code" != "200" ]; then
        resp=$(curl -s -w "\n%{http_code}" \
            -X POST -H "Content-Type: application/json" \
            -d "{\"email\":\"$email\",\"password\":\"$password\",\"displayName\":\"$display_name\"}" \
            "$BASE_URL/auth/register")
        code=$(echo "$resp" | tail -1)
        body=$(echo "$resp" | sed '$d')
    fi

    echo "$body" | python3 -c "import sys,json; print(json.load(sys.stdin).get('accessToken',''))" 2>/dev/null
}

get_user_id() {
    local token="$1"
    local resp
    resp=$(curl -s -H "Authorization: Bearer $token" "$BASE_URL/auth/me")
    echo "$resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null
}

# assert: check a condition
assert_eq() {
    local test_name="$1"
    local actual="$2"
    local expected="$3"
    TOTAL=$((TOTAL + 1))
    if [ "$actual" = "$expected" ]; then
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC} $test_name"
    else
        FAIL=$((FAIL + 1))
        echo -e "  ${RED}FAIL${NC} $test_name (got '$actual', expected '$expected')"
    fi
}

assert_gt() {
    local test_name="$1"
    local actual="$2"
    local min="$3"
    TOTAL=$((TOTAL + 1))
    if [ "$actual" -gt "$min" ] 2>/dev/null; then
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC} $test_name ($actual > $min)"
    else
        FAIL=$((FAIL + 1))
        echo -e "  ${RED}FAIL${NC} $test_name (got '$actual', expected > '$min')"
    fi
}

assert_ge() {
    local test_name="$1"
    local actual="$2"
    local min="$3"
    TOTAL=$((TOTAL + 1))
    if [ "$actual" -ge "$min" ] 2>/dev/null; then
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC} $test_name ($actual >= $min)"
    else
        FAIL=$((FAIL + 1))
        echo -e "  ${RED}FAIL${NC} $test_name (got '$actual', expected >= '$min')"
    fi
}

# ============================================================
echo -e "\n${CYAN}============================================================${NC}"
echo -e "${CYAN}  GAMIFICATION - TESTS COMPLETS (XP, niveaux, badges, etc.)${NC}"
echo -e "${CYAN}  Run ID: $TS${NC}"
echo -e "${CYAN}============================================================${NC}"

# ============================================================
# Step 0: Authentication (4 fresh users)
# ============================================================

echo -e "\n${YELLOW}[0] Authentication - 4 utilisateurs frais${NC}"

TOKEN1=$(do_login "gam${TS}u1@test.com" "TestGam1234" "GamUser1-$TS")
if [ -z "$TOKEN1" ]; then echo -e "${RED}FATAL: Cannot login user 1${NC}"; exit 1; fi
USER1_ID=$(get_user_id "$TOKEN1")
echo -e "  User 1: $USER1_ID"

TOKEN2=$(do_login "gam${TS}u2@test.com" "TestGam1234" "GamUser2-$TS")
if [ -z "$TOKEN2" ]; then echo -e "${RED}FATAL: Cannot login user 2${NC}"; exit 1; fi
USER2_ID=$(get_user_id "$TOKEN2")
echo -e "  User 2: $USER2_ID"

TOKEN3=$(do_login "gam${TS}u3@test.com" "TestGam1234" "GamUser3-$TS")
if [ -z "$TOKEN3" ]; then echo -e "${RED}FATAL: Cannot login user 3${NC}"; exit 1; fi
USER3_ID=$(get_user_id "$TOKEN3")
echo -e "  User 3: $USER3_ID"

TOKEN4=$(do_login "gam${TS}u4@test.com" "TestGam1234" "GamUser4-$TS")
if [ -z "$TOKEN4" ]; then echo -e "${RED}FATAL: Cannot login user 4${NC}"; exit 1; fi
echo -e "  User 4: $(get_user_id "$TOKEN4")"

# ============================================================
# Step 1: Initial profile (fresh user = all zeros)
# ============================================================

echo -e "\n${YELLOW}[1] Profil initial - auto-creation${NC}"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN1")
BODY=$(echo "$RESP" | sed '$d')
run_test "Profil User1 auto-cree" "$RESP" "200" "xp"
run_test_value "XP initial = 0" "$RESP" "200" "xp" "0"
run_test_value "Niveau initial = 1" "$RESP" "200" "level" "1"
run_test_value "Nom niveau = Graine" "$RESP" "200" "levelName" "Graine"
run_test_value "Streak initial = 0" "$RESP" "200" "wateringStreak" "0"
run_test_value "Total waterings = 0" "$RESP" "200" "totalWaterings" "0"
run_test_value "Total care actions = 0" "$RESP" "200" "totalCareActions" "0"
run_test_value "Total plants added = 0" "$RESP" "200" "totalPlantsAdded" "0"

BADGE_COUNT=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('badges',[])))" 2>/dev/null)
assert_eq "12 badges presents dans le profil" "$BADGE_COUNT" "12"

UNLOCKED=$(count_unlocked "$BODY")
assert_eq "0 badges debloques initialement" "$UNLOCKED" "0"

# ============================================================
# Step 2: Create house + members join -> TEAM_PLAYER badge
# ============================================================

echo -e "\n${YELLOW}[2] Maison + TEAM_PLAYER badge${NC}"

RESP=$(call_api POST "houses" "{\"name\":\"Maison Gam $TS\"}" "$TOKEN1")
HTTP=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')
HOUSE_ID=$(get_field "$BODY" "id")
INVITE_CODE=$(get_field "$BODY" "inviteCode")
run_test "User1 cree la maison" "$RESP" "201" "inviteCode"
echo -e "  House: $HOUSE_ID | Invite: $INVITE_CODE"

# User2 joins -> triggers TEAM_PLAYER
RESP=$(call_api POST "houses/join" "{\"inviteCode\":\"$INVITE_CODE\"}" "$TOKEN2")
run_test "User2 rejoint la maison" "$RESP" "200" "$HOUSE_ID"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN2")
BODY=$(echo "$RESP" | sed '$d')
assert_eq "User2 a le badge TEAM_PLAYER" "$(has_badge "$BODY" "TEAM_PLAYER")" "true"

# User3 joins
RESP=$(call_api POST "houses/join" "{\"inviteCode\":\"$INVITE_CODE\"}" "$TOKEN3")
run_test "User3 rejoint la maison" "$RESP" "200" "$HOUSE_ID"

# Verify User3 also gets TEAM_PLAYER
RESP=$(call_api GET "gamification/profile" "" "$TOKEN3")
BODY=$(echo "$RESP" | sed '$d')
assert_eq "User3 a le badge TEAM_PLAYER" "$(has_badge "$BODY" "TEAM_PLAYER")" "true"

# ============================================================
# Step 3: Add plants -> XP + level up + COLLECTOR badge
# ============================================================

echo -e "\n${YELLOW}[3] Ajout de plantes -> XP + badges collection${NC}"

# User1 adds plant 1
RESP=$(call_api POST "plants" '{"nickname":"Ficus Gam","wateringIntervalDays":3}' "$TOKEN1")
BODY=$(echo "$RESP" | sed '$d')
PLANT1_ID=$(get_field "$BODY" "id")
run_test "User1 ajoute plante 1 (Ficus)" "$RESP" "201"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN1")
run_test_value "XP apres 1 plante = 20" "$RESP" "200" "xp" "20"
run_test_value "totalPlantsAdded = 1" "$RESP" "200" "totalPlantsAdded" "1"

# Add 4 more plants
RESP=$(call_api POST "plants" '{"nickname":"Monstera Gam","wateringIntervalDays":5}' "$TOKEN1")
BODY=$(echo "$RESP" | sed '$d')
PLANT2_ID=$(get_field "$BODY" "id")
run_test "User1 ajoute plante 2" "$RESP" "201"

RESP=$(call_api POST "plants" '{"nickname":"Cactus Gam","wateringIntervalDays":14}' "$TOKEN1")
BODY=$(echo "$RESP" | sed '$d')
PLANT3_ID=$(get_field "$BODY" "id")
run_test "User1 ajoute plante 3" "$RESP" "201"

RESP=$(call_api POST "plants" '{"nickname":"Orchidee Gam","wateringIntervalDays":7}' "$TOKEN1")
BODY=$(echo "$RESP" | sed '$d')
PLANT4_ID=$(get_field "$BODY" "id")
run_test "User1 ajoute plante 4" "$RESP" "201"

RESP=$(call_api POST "plants" '{"nickname":"Basilic Gam","wateringIntervalDays":2}' "$TOKEN1")
BODY=$(echo "$RESP" | sed '$d')
PLANT5_ID=$(get_field "$BODY" "id")
run_test "User1 ajoute plante 5" "$RESP" "201"

# 5 * 20 = 100 XP -> level 2 (Pousse)
RESP=$(call_api GET "gamification/profile" "" "$TOKEN1")
BODY=$(echo "$RESP" | sed '$d')
run_test_value "XP apres 5 plantes = 100" "$RESP" "200" "xp" "100"
run_test_value "Niveau 2 (Pousse) atteint" "$RESP" "200" "level" "2"
run_test_value "Nom niveau = Pousse" "$RESP" "200" "levelName" "Pousse"
run_test_value "totalPlantsAdded = 5" "$RESP" "200" "totalPlantsAdded" "5"
assert_eq "Badge COLLECTOR debloque (5 plantes)" "$(has_badge "$BODY" "COLLECTOR")" "true"

# BOTANIST should NOT be unlocked (no species/customSpecies set)
assert_eq "BOTANIST verrouille (pas d'especes)" "$(has_badge "$BODY" "BOTANIST")" "false"

# ============================================================
# Step 4: Water a plant -> XP + FIRST_WATERING badge
# ============================================================

echo -e "\n${YELLOW}[4] Arrosage -> XP + FIRST_WATERING badge${NC}"

RESP=$(call_api POST "plants/$PLANT1_ID/water" '{}' "$TOKEN1")
run_test "User1 arrose plante 1" "$RESP" "200"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN1")
BODY=$(echo "$RESP" | sed '$d')
run_test_value "XP apres arrosage = 110 (100+10)" "$RESP" "200" "xp" "110"
run_test_value "totalWaterings = 1" "$RESP" "200" "totalWaterings" "1"
run_test_value "wateringStreak = 1" "$RESP" "200" "wateringStreak" "1"
assert_eq "Badge FIRST_WATERING debloque" "$(has_badge "$BODY" "FIRST_WATERING")" "true"

# ============================================================
# Step 5: Multiple waterings same day -> streak stays at 1
# ============================================================

echo -e "\n${YELLOW}[5] Arrosages multiples meme jour -> streak stable${NC}"

RESP=$(call_api POST "plants/$PLANT2_ID/water" '{}' "$TOKEN1")
run_test "User1 arrose plante 2 (meme jour)" "$RESP" "200"

RESP=$(call_api POST "plants/$PLANT3_ID/water" '{}' "$TOKEN1")
run_test "User1 arrose plante 3 (meme jour)" "$RESP" "200"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN1")
BODY=$(echo "$RESP" | sed '$d')
run_test_value "XP apres 3 arrosages = 130" "$RESP" "200" "xp" "130"
run_test_value "totalWaterings = 3" "$RESP" "200" "totalWaterings" "3"
run_test_value "Streak toujours 1 (meme jour)" "$RESP" "200" "wateringStreak" "1"

# ============================================================
# Step 6: Care actions -> XP, NO XP for NOTE
# ============================================================

echo -e "\n${YELLOW}[6] Actions de soin -> XP differencies${NC}"

RESP=$(call_api POST "plants/$PLANT1_ID/care-logs" '{"action":"FERTILIZING","notes":"Test"}' "$TOKEN1")
run_test "User1 fertilise plante 1" "$RESP" "201"
RESP=$(call_api GET "gamification/profile" "" "$TOKEN1")
run_test_value "XP apres fertilisation = 145 (130+15)" "$RESP" "200" "xp" "145"
run_test_value "totalCareActions = 1" "$RESP" "200" "totalCareActions" "1"

RESP=$(call_api POST "plants/$PLANT1_ID/care-logs" '{"action":"PRUNING","notes":"Test"}' "$TOKEN1")
run_test "User1 taille plante 1" "$RESP" "201"
RESP=$(call_api GET "gamification/profile" "" "$TOKEN1")
run_test_value "XP apres taille = 160 (145+15)" "$RESP" "200" "xp" "160"
run_test_value "totalCareActions = 2" "$RESP" "200" "totalCareActions" "2"

RESP=$(call_api POST "plants/$PLANT1_ID/care-logs" '{"action":"REPOTTING","notes":"Test"}' "$TOKEN1")
run_test "User1 rempote plante 1" "$RESP" "201"
RESP=$(call_api GET "gamification/profile" "" "$TOKEN1")
run_test_value "XP apres rempotage = 175 (160+15)" "$RESP" "200" "xp" "175"

RESP=$(call_api POST "plants/$PLANT1_ID/care-logs" '{"action":"TREATMENT","notes":"Test"}' "$TOKEN1")
run_test "User1 traite plante 1" "$RESP" "201"
RESP=$(call_api GET "gamification/profile" "" "$TOKEN1")
run_test_value "XP apres traitement = 190 (175+15)" "$RESP" "200" "xp" "190"

# NOTE -> 0 XP
RESP=$(call_api POST "plants/$PLANT1_ID/care-logs" '{"action":"NOTE","notes":"Juste une note"}' "$TOKEN1")
run_test "User1 ajoute une note" "$RESP" "201"
RESP=$(call_api GET "gamification/profile" "" "$TOKEN1")
run_test_value "XP apres NOTE = 190 (pas de XP)" "$RESP" "200" "xp" "190"
run_test_value "totalCareActions inchange apres NOTE = 4" "$RESP" "200" "totalCareActions" "4"

# ============================================================
# Step 7: Anti-spam - same care type same plant same day
# ============================================================

echo -e "\n${YELLOW}[7] Anti-spam - meme soin, meme plante, meme jour${NC}"

RESP=$(call_api POST "plants/$PLANT1_ID/care-logs" '{"action":"FERTILIZING","notes":"2eme"}' "$TOKEN1")
run_test "2eme fertilisation meme plante meme jour" "$RESP" "201"
RESP=$(call_api GET "gamification/profile" "" "$TOKEN1")
run_test_value "XP inchange = 190 (anti-spam)" "$RESP" "200" "xp" "190"

# Different plant with same action -> should give XP
RESP=$(call_api POST "plants/$PLANT2_ID/care-logs" '{"action":"FERTILIZING","notes":"P2"}' "$TOKEN1")
run_test "Fertilisation plante 2 (different plant)" "$RESP" "201"
RESP=$(call_api GET "gamification/profile" "" "$TOKEN1")
run_test_value "XP augmente = 205 (autre plante OK)" "$RESP" "200" "xp" "205"

# ============================================================
# Step 8: WATERING via care-log = no XP
# ============================================================

echo -e "\n${YELLOW}[8] WATERING via care-log -> pas de double XP${NC}"

RESP=$(call_api POST "plants/$PLANT4_ID/care-logs" '{"action":"WATERING","notes":"via care-log"}' "$TOKEN1")
run_test "Arrosage via care-log" "$RESP" "201"
RESP=$(call_api GET "gamification/profile" "" "$TOKEN1")
run_test_value "XP inchange = 205 (WATERING via care-log)" "$RESP" "200" "xp" "205"

# ============================================================
# Step 9: Independent profiles
# ============================================================

echo -e "\n${YELLOW}[9] Profils independants entre users${NC}"

RESP=$(call_api POST "plants" '{"nickname":"Plante User2","wateringIntervalDays":4}' "$TOKEN2")
BODY=$(echo "$RESP" | sed '$d')
PLANT_U2=$(get_field "$BODY" "id")
run_test "User2 ajoute une plante" "$RESP" "201"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN2")
run_test_value "User2 XP = 20 (1 plante)" "$RESP" "200" "xp" "20"
run_test_value "User2 totalPlantsAdded = 1" "$RESP" "200" "totalPlantsAdded" "1"
run_test_value "User2 totalWaterings = 0" "$RESP" "200" "totalWaterings" "0"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN1")
run_test_value "User1 XP toujours 205" "$RESP" "200" "xp" "205"

# ============================================================
# Step 10: Leaderboard
# ============================================================

echo -e "\n${YELLOW}[10] Classement (Leaderboard)${NC}"

RESP=$(call_api GET "gamification/leaderboard/$HOUSE_ID" "" "$TOKEN1")
BODY=$(echo "$RESP" | sed '$d')
run_test "Leaderboard accessible" "$RESP" "200"

FIRST_XP=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['xp'])" 2>/dev/null)
SECOND_XP=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[1]['xp'])" 2>/dev/null)
THIRD_XP=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[2]['xp'])" 2>/dev/null)
LB_COUNT=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d))" 2>/dev/null)

assert_eq "Leaderboard contient 3 membres" "$LB_COUNT" "3"
assert_eq "1er du classement = 205 XP (User1)" "$FIRST_XP" "205"
assert_eq "2eme du classement = 20 XP (User2)" "$SECOND_XP" "20"
assert_eq "3eme du classement = 0 XP (User3)" "$THIRD_XP" "0"

# ============================================================
# Step 11: Leaderboard access control
# ============================================================

echo -e "\n${YELLOW}[11] Leaderboard - controle d'acces${NC}"

RESP=$(call_api GET "gamification/leaderboard/$HOUSE_ID" "" "$TOKEN4")
run_test "User hors maison ne peut pas voir le classement" "$RESP" "403"

# ============================================================
# Step 12: Vacation delegation -> GUARDIAN_ANGEL badge
# ============================================================

echo -e "\n${YELLOW}[12] Delegation vacances -> GUARDIAN_ANGEL badge${NC}"

TODAY=$(date +%Y-%m-%d)
END_DATE=$(date -v+7d +%Y-%m-%d 2>/dev/null || date -d "+7 days" +%Y-%m-%d 2>/dev/null)

RESP=$(call_api POST "houses/$HOUSE_ID/vacation" \
    "{\"delegateId\":\"$USER2_ID\",\"startDate\":\"$TODAY\",\"endDate\":\"$END_DATE\",\"message\":\"Test gamification\"}" \
    "$TOKEN1")
run_test "User1 active vacances (delegue User2)" "$RESP" "201"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN2")
BODY=$(echo "$RESP" | sed '$d')
assert_eq "User2 a le badge GUARDIAN_ANGEL" "$(has_badge "$BODY" "GUARDIAN_ANGEL")" "true"

RESP=$(call_api DELETE "houses/$HOUSE_ID/vacation" "" "$TOKEN1")
run_test "User1 annule vacances" "$RESP" "204"

# ============================================================
# Step 13: Badge idempotency
# ============================================================

echo -e "\n${YELLOW}[13] Idempotence des badges${NC}"

RESP=$(call_api POST "houses/$HOUSE_ID/vacation" \
    "{\"delegateId\":\"$USER2_ID\",\"startDate\":\"$TODAY\",\"endDate\":\"$END_DATE\",\"message\":\"2eme\"}" \
    "$TOKEN1")
run_test "User1 re-active vacances" "$RESP" "201"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN2")
BODY=$(echo "$RESP" | sed '$d')
GA_COUNT=$(echo "$BODY" | python3 -c "
import sys,json
d=json.load(sys.stdin)
print(sum(1 for b in d['badges'] if b['code']=='GUARDIAN_ANGEL' and b['unlocked']))
" 2>/dev/null)
assert_eq "GUARDIAN_ANGEL pas duplique (toujours 1)" "$GA_COUNT" "1"

RESP=$(call_api DELETE "houses/$HOUSE_ID/vacation" "" "$TOKEN1")

# ============================================================
# Step 14: Security - unauthenticated access
# ============================================================

echo -e "\n${YELLOW}[14] Securite - acces sans authentification${NC}"

RESP=$(curl -s -w "\n%{http_code}" -H "Content-Type: application/json" "$BASE_URL/gamification/profile")
run_test "Profil sans token -> 401" "$RESP" "401"

RESP=$(curl -s -w "\n%{http_code}" -H "Content-Type: application/json" "$BASE_URL/gamification/leaderboard/$HOUSE_ID")
run_test "Leaderboard sans token -> 401" "$RESP" "401"

RESP=$(curl -s -w "\n%{http_code}" -H "Content-Type: application/json" -H "Authorization: Bearer INVALID_TOKEN" "$BASE_URL/gamification/profile")
run_test "Token invalide -> 401" "$RESP" "401"

RESP=$(curl -s -w "\n%{http_code}" -H "Content-Type: application/json" -H "Authorization: Bearer INVALID_TOKEN" "$BASE_URL/gamification/leaderboard/$HOUSE_ID")
run_test "Token invalide leaderboard -> 401" "$RESP" "401"

# ============================================================
# Step 15: XP progress
# ============================================================

echo -e "\n${YELLOW}[15] Progression XP (next level)${NC}"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN1")
BODY=$(echo "$RESP" | sed '$d')

# User1: level 2 (Pousse, 100). Next = Bourgeon at 300. xpForNextLevel=200, xpProgressInLevel=105
XP_FOR_NEXT=$(get_field "$BODY" "xpForNextLevel")
XP_PROGRESS=$(get_field "$BODY" "xpProgressInLevel")
assert_eq "xpForNextLevel = 200 (Pousse->Bourgeon)" "$XP_FOR_NEXT" "200"
assert_eq "xpProgressInLevel = 105" "$XP_PROGRESS" "105"

# ============================================================
# Step 16: Badge details
# ============================================================

echo -e "\n${YELLOW}[16] Details des badges${NC}"

FW_NAME=$(echo "$BODY" | python3 -c "
import sys,json; d=json.load(sys.stdin)
print([b for b in d['badges'] if b['code']=='FIRST_WATERING'][0]['name'])
" 2>/dev/null)
FW_CAT=$(echo "$BODY" | python3 -c "
import sys,json; d=json.load(sys.stdin)
print([b for b in d['badges'] if b['code']=='FIRST_WATERING'][0]['category'])
" 2>/dev/null)
FW_DATE=$(echo "$BODY" | python3 -c "
import sys,json; d=json.load(sys.stdin)
print('has_date' if [b for b in d['badges'] if b['code']=='FIRST_WATERING'][0].get('unlockedAt') else 'no_date')
" 2>/dev/null)
MARATHON_DATE=$(echo "$BODY" | python3 -c "
import sys,json; d=json.load(sys.stdin)
print('null' if [b for b in d['badges'] if b['code']=='MARATHON'][0].get('unlockedAt') is None else 'has_date')
" 2>/dev/null)

assert_eq "Badge FIRST_WATERING name = Premier Arrosage" "$FW_NAME" "Premier Arrosage"
assert_eq "Badge FIRST_WATERING category = watering" "$FW_CAT" "watering"
assert_eq "Badge debloque a une date unlockedAt" "$FW_DATE" "has_date"
assert_eq "Badge verrouille (MARATHON) pas de date" "$MARATHON_DATE" "null"

# ============================================================
# Step 17: CARETAKER badge (10 care actions)
# ============================================================

echo -e "\n${YELLOW}[17] Badge CARETAKER (10 soins)${NC}"

# User1 has 4+1=5 care actions. Need 5 more on different plants/types
RESP=$(call_api POST "plants/$PLANT2_ID/care-logs" '{"action":"PRUNING","notes":""}' "$TOKEN1")
run_test "Soin 6: taille plante 2" "$RESP" "201"
RESP=$(call_api POST "plants/$PLANT2_ID/care-logs" '{"action":"REPOTTING","notes":""}' "$TOKEN1")
run_test "Soin 7: rempotage plante 2" "$RESP" "201"
RESP=$(call_api POST "plants/$PLANT3_ID/care-logs" '{"action":"FERTILIZING","notes":""}' "$TOKEN1")
run_test "Soin 8: fertilisation plante 3" "$RESP" "201"
RESP=$(call_api POST "plants/$PLANT3_ID/care-logs" '{"action":"TREATMENT","notes":""}' "$TOKEN1")
run_test "Soin 9: traitement plante 3" "$RESP" "201"
RESP=$(call_api POST "plants/$PLANT4_ID/care-logs" '{"action":"FERTILIZING","notes":""}' "$TOKEN1")
run_test "Soin 10: fertilisation plante 4" "$RESP" "201"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN1")
BODY=$(echo "$RESP" | sed '$d')
assert_eq "Badge CARETAKER debloque (10 soins)" "$(has_badge "$BODY" "CARETAKER")" "true"
run_test_value "totalCareActions = 10" "$RESP" "200" "totalCareActions" "10"

# ============================================================
# Step 18: User3 (no plant actions) -> clean profile
# ============================================================

echo -e "\n${YELLOW}[18] User3 sans action de plante -> profil vierge (sauf badge social)${NC}"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN3")
BODY=$(echo "$RESP" | sed '$d')
run_test_value "User3 XP = 0" "$RESP" "200" "xp" "0"
run_test_value "User3 level = 1" "$RESP" "200" "level" "1"
run_test_value "User3 totalWaterings = 0" "$RESP" "200" "totalWaterings" "0"
run_test_value "User3 totalCareActions = 0" "$RESP" "200" "totalCareActions" "0"
assert_eq "User3 a TEAM_PLAYER (seul badge)" "$(has_badge "$BODY" "TEAM_PLAYER")" "true"
assert_eq "User3 n'a pas FIRST_WATERING" "$(has_badge "$BODY" "FIRST_WATERING")" "false"

# ============================================================
# Step 19: Leaderboard from User2 perspective
# ============================================================

echo -e "\n${YELLOW}[19] Leaderboard vu par User2${NC}"

RESP=$(call_api GET "gamification/leaderboard/$HOUSE_ID" "" "$TOKEN2")
BODY=$(echo "$RESP" | sed '$d')
run_test "User2 peut voir le leaderboard" "$RESP" "200"
LB_COUNT=$(echo "$BODY" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null)
assert_eq "Leaderboard = 3 membres" "$LB_COUNT" "3"

# ============================================================
# Step 20: Leaderboard fake house ID
# ============================================================

echo -e "\n${YELLOW}[20] Leaderboard maison inexistante${NC}"

RESP=$(call_api GET "gamification/leaderboard/00000000-0000-0000-0000-000000000000" "" "$TOKEN1")
run_test "Leaderboard maison inexistante -> 403" "$RESP" "403"

# ============================================================
# Step 21: User2 waters -> XP accumulation
# ============================================================

echo -e "\n${YELLOW}[21] User2 accumulation XP${NC}"

RESP=$(call_api POST "plants/$PLANT_U2/water" '{}' "$TOKEN2")
run_test "User2 arrose sa plante" "$RESP" "200"
RESP=$(call_api GET "gamification/profile" "" "$TOKEN2")
BODY=$(echo "$RESP" | sed '$d')
run_test_value "User2 XP = 30 (20+10)" "$RESP" "200" "xp" "30"
assert_eq "User2 a FIRST_WATERING" "$(has_badge "$BODY" "FIRST_WATERING")" "true"

# ============================================================
# Step 22: Badge categories
# ============================================================

echo -e "\n${YELLOW}[22] Verification categories de badges${NC}"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN1")
BODY=$(echo "$RESP" | sed '$d')

CATEGORIES=$(echo "$BODY" | python3 -c "
import sys,json; d=json.load(sys.stdin)
cats = {}
for b in d['badges']:
    cats[b['category']] = cats.get(b['category'],0)+1
for c in sorted(cats): print(f'{c}:{cats[c]}')
" 2>/dev/null)

TOTAL=$((TOTAL + 1))
if echo "$CATEGORIES" | grep -q "watering:2" && \
   echo "$CATEGORIES" | grep -q "collection:3" && \
   echo "$CATEGORIES" | grep -q "care:1" && \
   echo "$CATEGORIES" | grep -q "streak:2" && \
   echo "$CATEGORIES" | grep -q "social:2" && \
   echo "$CATEGORIES" | grep -q "specialist:2"; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} 6 categories correctes"
else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC} Categories: $CATEGORIES"
fi

# ============================================================
# Step 23: All badge codes present
# ============================================================

echo -e "\n${YELLOW}[23] Tous les codes de badges presents${NC}"

ALL_CODES=$(echo "$BODY" | python3 -c "
import sys,json; d=json.load(sys.stdin)
print(','.join(sorted(b['code'] for b in d['badges'])))
" 2>/dev/null)
EXPECTED="BOTANIST,CACTUS_KING,CARETAKER,COLLECTOR,FIRST_WATERING,GREEN_THUMB,GUARDIAN_ANGEL,MARATHON,PUNCTUAL,TEAM_PLAYER,TROPICAL_EXPERT,URBAN_JUNGLE"
assert_eq "12 codes de badges" "$ALL_CODES" "$EXPECTED"

# ============================================================
# Step 24: User1 badges recap
# ============================================================

echo -e "\n${YELLOW}[24] Recap badges User1${NC}"

UNLOCKED_LIST=$(echo "$BODY" | python3 -c "
import sys,json; d=json.load(sys.stdin)
print(','.join(sorted(b['code'] for b in d['badges'] if b['unlocked'])))
" 2>/dev/null)
echo -e "  Badges User1: $UNLOCKED_LIST"

assert_eq "User1 a FIRST_WATERING" "$(has_badge "$BODY" "FIRST_WATERING")" "true"
assert_eq "User1 a COLLECTOR" "$(has_badge "$BODY" "COLLECTOR")" "true"
assert_eq "User1 a CARETAKER" "$(has_badge "$BODY" "CARETAKER")" "true"
assert_eq "User1 n'a PAS GREEN_THUMB" "$(has_badge "$BODY" "GREEN_THUMB")" "false"
assert_eq "User1 n'a PAS URBAN_JUNGLE" "$(has_badge "$BODY" "URBAN_JUNGLE")" "false"
assert_eq "User1 n'a PAS MARATHON" "$(has_badge "$BODY" "MARATHON")" "false"
assert_eq "User1 n'a PAS BOTANIST (pas d'especes)" "$(has_badge "$BODY" "BOTANIST")" "false"

# ============================================================
# Step 25: bestWateringStreak tracking
# ============================================================

echo -e "\n${YELLOW}[25] Best streak tracking${NC}"

BEST=$(get_field "$BODY" "bestWateringStreak")
CURRENT=$(get_field "$BODY" "wateringStreak")
assert_ge "bestWateringStreak >= wateringStreak" "$BEST" "$CURRENT"

# ============================================================
# Step 26: BOTANIST badge via customSpecies
# ============================================================

echo -e "\n${YELLOW}[26] Badge BOTANIST via customSpecies${NC}"

for sp in Tulipa Rosa Lavandula Mentha Thymus; do
    RESP=$(call_api POST "plants" "{\"nickname\":\"$sp plant\",\"customSpecies\":\"$sp\",\"wateringIntervalDays\":3}" "$TOKEN2")
    run_test "User2 ajoute $sp" "$RESP" "201"
done

RESP=$(call_api GET "gamification/profile" "" "$TOKEN2")
BODY=$(echo "$RESP" | sed '$d')
assert_eq "User2 a BOTANIST (5 especes via customSpecies)" "$(has_badge "$BODY" "BOTANIST")" "true"

# ============================================================
# Step 27: Duplicate customSpecies NOT counted
# ============================================================

echo -e "\n${YELLOW}[27] Especes dupliquees ne comptent pas${NC}"

for i in 1 2 3 4 5; do
    RESP=$(call_api POST "plants" "{\"nickname\":\"Cactus$i\",\"customSpecies\":\"Cactaceae\",\"wateringIntervalDays\":14}" "$TOKEN3")
    run_test "User3 ajoute Cactus$i (meme espece)" "$RESP" "201"
done

RESP=$(call_api GET "gamification/profile" "" "$TOKEN3")
BODY=$(echo "$RESP" | sed '$d')
assert_eq "User3 n'a PAS BOTANIST (1 seule espece)" "$(has_badge "$BODY" "BOTANIST")" "false"
assert_eq "User3 a COLLECTOR (5 plantes)" "$(has_badge "$BODY" "COLLECTOR")" "true"

# ============================================================
# Step 28: Delete plant - XP stays
# ============================================================

echo -e "\n${YELLOW}[28] Suppression de plante - XP conserve${NC}"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN1")
BODY=$(echo "$RESP" | sed '$d')
XP_BEFORE=$(get_field "$BODY" "xp")

RESP=$(call_api DELETE "plants/$PLANT5_ID" "" "$TOKEN1")
run_test "User1 supprime plante 5" "$RESP" "204"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN1")
run_test_value "XP inchange apres suppression = $XP_BEFORE" "$RESP" "200" "xp" "$XP_BEFORE"

# ============================================================
# Step 29: Delegate waters plant -> XP for delegate
# ============================================================

echo -e "\n${YELLOW}[29] Delegue arrose plante du proprietaire -> XP delegue${NC}"

RESP=$(call_api POST "houses/$HOUSE_ID/vacation" \
    "{\"delegateId\":\"$USER2_ID\",\"startDate\":\"$TODAY\",\"endDate\":\"$END_DATE\",\"message\":\"Test XP\"}" \
    "$TOKEN1")
run_test "User1 active vacances" "$RESP" "201"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN2")
BODY=$(echo "$RESP" | sed '$d')
U2_XP_BEFORE=$(get_field "$BODY" "xp")

RESP=$(call_api POST "plants/$PLANT1_ID/water" '{}' "$TOKEN2")
run_test "User2 (delegue) arrose plante de User1" "$RESP" "200"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN2")
BODY=$(echo "$RESP" | sed '$d')
U2_XP_AFTER=$(get_field "$BODY" "xp")
EXPECTED_U2=$((U2_XP_BEFORE + 10))
assert_eq "Delegue gagne 10 XP" "$U2_XP_AFTER" "$EXPECTED_U2"

RESP=$(call_api DELETE "houses/$HOUSE_ID/vacation" "" "$TOKEN1")

# ============================================================
# Step 30: Note spam -> no XP
# ============================================================

echo -e "\n${YELLOW}[30] Spam de notes -> aucun XP${NC}"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN2")
BODY=$(echo "$RESP" | sed '$d')
XP_BEFORE_NOTES=$(get_field "$BODY" "xp")

for i in 1 2 3 4 5; do
    call_api POST "plants/$PLANT_U2/care-logs" "{\"action\":\"NOTE\",\"notes\":\"Spam $i\"}" "$TOKEN2" > /dev/null
done
echo -e "  5 notes ajoutees"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN2")
run_test_value "XP inchange apres 5 notes = $XP_BEFORE_NOTES" "$RESP" "200" "xp" "$XP_BEFORE_NOTES"

# ============================================================
# Step 31: 4 care types same plant = XP for each
# ============================================================

echo -e "\n${YELLOW}[31] 4 types soins meme plante = XP pour chaque${NC}"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN2")
BODY=$(echo "$RESP" | sed '$d')
XP_BEFORE=$(get_field "$BODY" "xp")

for action in FERTILIZING PRUNING REPOTTING TREATMENT; do
    RESP=$(call_api POST "plants/$PLANT_U2/care-logs" "{\"action\":\"$action\",\"notes\":\"\"}" "$TOKEN2")
    run_test "User2 $action" "$RESP" "201"
done

RESP=$(call_api GET "gamification/profile" "" "$TOKEN2")
BODY=$(echo "$RESP" | sed '$d')
XP_AFTER=$(get_field "$BODY" "xp")
EXPECTED_XP=$((XP_BEFORE + 60))
assert_eq "4 types x 15 XP = +60" "$XP_AFTER" "$EXPECTED_XP"

# ============================================================
# Step 32: Re-do same types = anti-spam
# ============================================================

echo -e "\n${YELLOW}[32] Re-faire memes soins = anti-spam${NC}"

for action in FERTILIZING PRUNING REPOTTING TREATMENT; do
    RESP=$(call_api POST "plants/$PLANT_U2/care-logs" "{\"action\":\"$action\",\"notes\":\"2nd\"}" "$TOKEN2")
    run_test "User2 re-$action" "$RESP" "201"
done

RESP=$(call_api GET "gamification/profile" "" "$TOKEN2")
run_test_value "XP inchange (anti-spam) = $EXPECTED_XP" "$RESP" "200" "xp" "$EXPECTED_XP"

# ============================================================
# Step 33: Leaderboard order updated
# ============================================================

echo -e "\n${YELLOW}[33] Leaderboard mis a jour${NC}"

RESP=$(call_api GET "gamification/leaderboard/$HOUSE_ID" "" "$TOKEN1")
BODY=$(echo "$RESP" | sed '$d')
FIRST_XP=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['xp'])" 2>/dev/null)
SECOND_XP=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[1]['xp'])" 2>/dev/null)
assert_ge "Leaderboard trie par XP desc" "$FIRST_XP" "$SECOND_XP"

# ============================================================
# Step 34: User4 (no house, no actions) -> clean profile
# ============================================================

echo -e "\n${YELLOW}[34] User4 (hors maison) - profil minimal${NC}"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN4")
BODY=$(echo "$RESP" | sed '$d')
run_test_value "User4 XP = 0" "$RESP" "200" "xp" "0"
run_test_value "User4 level = 1" "$RESP" "200" "level" "1"
assert_eq "User4 a 0 badges debloques" "$(count_unlocked "$BODY")" "0"

# ============================================================
# Step 35: Leaderboard entry structure
# ============================================================

echo -e "\n${YELLOW}[35] Leaderboard - structure des entrees${NC}"

RESP=$(call_api GET "gamification/leaderboard/$HOUSE_ID" "" "$TOKEN1")
BODY=$(echo "$RESP" | sed '$d')

LB_FIELDS=$(echo "$BODY" | python3 -c "
import sys,json; d=json.load(sys.stdin)
required = ['xp','level','levelName','xpForNextLevel','xpProgressInLevel','wateringStreak','bestWateringStreak','totalWaterings','totalCareActions','totalPlantsAdded','badges']
missing = [f for f in required if f not in d[0]]
print(','.join(missing) if missing else 'OK')
" 2>/dev/null)
assert_eq "Entrees leaderboard: tous les champs" "$LB_FIELDS" "OK"

LB_BADGES=$(echo "$BODY" | python3 -c "
import sys,json; d=json.load(sys.stdin)
print('OK' if all(len(e.get('badges',[]))==12 for e in d) else 'FAIL')
" 2>/dev/null)
assert_eq "Chaque entree a 12 badges" "$LB_BADGES" "OK"

# ============================================================
# Step 36: Profile JSON structure
# ============================================================

echo -e "\n${YELLOW}[36] Structure JSON profil complete${NC}"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN1")
BODY=$(echo "$RESP" | sed '$d')

PROFILE_OK=$(echo "$BODY" | python3 -c "
import sys,json; d=json.load(sys.stdin)
required = ['xp','level','levelName','xpForNextLevel','xpProgressInLevel','wateringStreak','bestWateringStreak','totalWaterings','totalCareActions','totalPlantsAdded','badges']
print('OK' if not [f for f in required if f not in d] else 'FAIL')
" 2>/dev/null)
assert_eq "Profil: 11 champs requis" "$PROFILE_OK" "OK"

BADGE_OK=$(echo "$BODY" | python3 -c "
import sys,json; d=json.load(sys.stdin)
required = ['code','name','description','category','unlocked','unlockedAt']
for b in d['badges']:
    if [f for f in required if f not in b]:
        print('FAIL'); break
else:
    print('OK')
" 2>/dev/null)
assert_eq "Badges: 6 champs requis chacun" "$BADGE_OK" "OK"

# ============================================================
# Step 37: Numeric field types
# ============================================================

echo -e "\n${YELLOW}[37] Types des champs numeriques${NC}"

TYPE_CHECK=$(echo "$BODY" | python3 -c "
import sys,json; d=json.load(sys.stdin)
int_fields = ['xp','level','xpForNextLevel','xpProgressInLevel','wateringStreak','bestWateringStreak','totalWaterings','totalCareActions','totalPlantsAdded']
bad = [f for f in int_fields if not isinstance(d.get(f), int)]
print(','.join(bad) if bad else 'OK')
" 2>/dev/null)
assert_eq "Tous les champs numeriques sont int" "$TYPE_CHECK" "OK"

# ============================================================
# Step 38: User2 final badges
# ============================================================

echo -e "\n${YELLOW}[38] Recap badges User2${NC}"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN2")
BODY=$(echo "$RESP" | sed '$d')
U2_BADGES=$(echo "$BODY" | python3 -c "
import sys,json; d=json.load(sys.stdin)
print(','.join(sorted(b['code'] for b in d['badges'] if b['unlocked'])))
" 2>/dev/null)
echo -e "  Badges User2: $U2_BADGES"
assert_eq "User2 a TEAM_PLAYER" "$(has_badge "$BODY" "TEAM_PLAYER")" "true"
assert_eq "User2 a GUARDIAN_ANGEL" "$(has_badge "$BODY" "GUARDIAN_ANGEL")" "true"
assert_eq "User2 a FIRST_WATERING" "$(has_badge "$BODY" "FIRST_WATERING")" "true"
assert_eq "User2 a BOTANIST" "$(has_badge "$BODY" "BOTANIST")" "true"
assert_eq "User2 a COLLECTOR (6 plantes)" "$(has_badge "$BODY" "COLLECTOR")" "true"

# ============================================================
# Step 39: User3 XP from plants only
# ============================================================

echo -e "\n${YELLOW}[39] User3 XP = plantes uniquement${NC}"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN3")
BODY=$(echo "$RESP" | sed '$d')
# 5 plants = 100 XP
run_test_value "User3 XP = 100 (5 plantes x 20)" "$RESP" "200" "xp" "100"
run_test_value "User3 totalPlantsAdded = 5" "$RESP" "200" "totalPlantsAdded" "5"
run_test_value "User3 level = 2 (Pousse)" "$RESP" "200" "level" "2"

# ============================================================
# Step 40: Non-owner user can't access another house's leaderboard
# ============================================================

echo -e "\n${YELLOW}[40] User3 accede au leaderboard (membre) vs User4 (non-membre)${NC}"

RESP=$(call_api GET "gamification/leaderboard/$HOUSE_ID" "" "$TOKEN3")
run_test "User3 (membre) voit le leaderboard" "$RESP" "200"

RESP=$(call_api GET "gamification/leaderboard/$HOUSE_ID" "" "$TOKEN4")
run_test "User4 (non-membre) -> 403" "$RESP" "403"

# ============================================================
# Step 41: iconUrl field in badges (new)
# ============================================================

echo -e "\n${YELLOW}[41] iconUrl present dans chaque badge${NC}"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN1")
BODY=$(echo "$RESP" | sed '$d')

ICON_CHECK=$(echo "$BODY" | python3 -c "
import sys,json; d=json.load(sys.stdin)
for b in d['badges']:
    url = b.get('iconUrl','')
    if not url.startswith('/api/v1/badges/') or not url.endswith('.png'):
        print(f'BAD:{b[\"code\"]}:{url}'); break
else:
    print('OK')
" 2>/dev/null)
assert_eq "Tous les badges ont iconUrl /api/v1/badges/*.png" "$ICON_CHECK" "OK"

# Verify specific icon URLs match badge codes
ICON_FW=$(echo "$BODY" | python3 -c "
import sys,json; d=json.load(sys.stdin)
print([b for b in d['badges'] if b['code']=='FIRST_WATERING'][0].get('iconUrl',''))
" 2>/dev/null)
assert_eq "FIRST_WATERING iconUrl = /api/v1/badges/first_watering.png" "$ICON_FW" "/api/v1/badges/first_watering.png"

ICON_CK=$(echo "$BODY" | python3 -c "
import sys,json; d=json.load(sys.stdin)
print([b for b in d['badges'] if b['code']=='CACTUS_KING'][0].get('iconUrl',''))
" 2>/dev/null)
assert_eq "CACTUS_KING iconUrl = /api/v1/badges/cactus_king.png" "$ICON_CK" "/api/v1/badges/cactus_king.png"

# ============================================================
# Step 42: Badge images accessible via HTTP
# ============================================================

echo -e "\n${YELLOW}[42] Images badges accessibles via HTTP${NC}"

for badge_file in first_watering green_thumb collector cactus_king; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/badges/${badge_file}.png")
    TOTAL=$((TOTAL + 1))
    if [ "$HTTP_CODE" = "200" ]; then
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC} /api/v1/badges/${badge_file}.png accessible (200)"
    else
        FAIL=$((FAIL + 1))
        echo -e "  ${RED}FAIL${NC} /api/v1/badges/${badge_file}.png -> HTTP $HTTP_CODE (expected 200)"
    fi
done

# ============================================================
# Step 43: Watering already-watered plant -> still gives XP
# ============================================================

echo -e "\n${YELLOW}[43] Re-arroser une plante deja arrosee aujourd'hui${NC}"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN1")
BODY=$(echo "$RESP" | sed '$d')
XP_BEFORE=$(get_field "$BODY" "xp")
WATERINGS_BEFORE=$(get_field "$BODY" "totalWaterings")

# Plant1 was already watered today in step 4
RESP=$(call_api POST "plants/$PLANT1_ID/water" '{}' "$TOKEN1")
HTTP=$(echo "$RESP" | tail -1)

RESP=$(call_api GET "gamification/profile" "" "$TOKEN1")
BODY=$(echo "$RESP" | sed '$d')
XP_AFTER=$(get_field "$BODY" "xp")
WATERINGS_AFTER=$(get_field "$BODY" "totalWaterings")

# Backend may or may not give XP for re-watering (depends on plant.needsWatering)
# But the count should remain consistent
echo -e "  XP before: $XP_BEFORE, after: $XP_AFTER (delta: $((XP_AFTER - XP_BEFORE)))"
TOTAL=$((TOTAL + 1))
if [ "$XP_AFTER" -ge "$XP_BEFORE" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} XP ne diminue pas apres re-arrosage"
else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC} XP a diminue: $XP_BEFORE -> $XP_AFTER"
fi

# ============================================================
# Step 44: Cross-user isolation - User2 care on User1's plant via delegation
# ============================================================

echo -e "\n${YELLOW}[44] User2 soin sur plante User1 via delegation${NC}"

RESP=$(call_api POST "houses/$HOUSE_ID/vacation" \
    "{\"delegateId\":\"$USER2_ID\",\"startDate\":\"$TODAY\",\"endDate\":\"$END_DATE\",\"message\":\"Test care\"}" \
    "$TOKEN1")

RESP=$(call_api GET "gamification/profile" "" "$TOKEN2")
BODY=$(echo "$RESP" | sed '$d')
U2_XP_BEFORE=$(get_field "$BODY" "xp")
U2_CARE_BEFORE=$(get_field "$BODY" "totalCareActions")

RESP=$(call_api POST "plants/$PLANT2_ID/care-logs" '{"action":"TREATMENT","notes":"delegue"}' "$TOKEN2")
run_test "User2 traite plante de User1 (delegue)" "$RESP" "201"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN2")
BODY=$(echo "$RESP" | sed '$d')
U2_XP_AFTER=$(get_field "$BODY" "xp")
U2_CARE_AFTER=$(get_field "$BODY" "totalCareActions")

assert_eq "User2 gagne 15 XP soin delegue" "$U2_XP_AFTER" "$((U2_XP_BEFORE + 15))"
assert_eq "User2 totalCareActions incremente" "$U2_CARE_AFTER" "$((U2_CARE_BEFORE + 1))"

# Verify User1 XP unchanged
RESP=$(call_api GET "gamification/profile" "" "$TOKEN1")
BODY=$(echo "$RESP" | sed '$d')
U1_XP=$(get_field "$BODY" "xp")
assert_eq "User1 XP inchange (pas son action)" "$U1_XP" "$XP_AFTER"

RESP=$(call_api DELETE "houses/$HOUSE_ID/vacation" "" "$TOKEN1")

# ============================================================
# Step 45: Care on non-existent plant -> error, no XP crash
# ============================================================

echo -e "\n${YELLOW}[45] Soin sur plante inexistante${NC}"

FAKE_PLANT="00000000-0000-0000-0000-000000000000"
RESP=$(call_api POST "plants/$FAKE_PLANT/care-logs" '{"action":"FERTILIZING","notes":""}' "$TOKEN1")
HTTP=$(echo "$RESP" | tail -1)
TOTAL=$((TOTAL + 1))
if [ "$HTTP" = "404" ] || [ "$HTTP" = "403" ] || [ "$HTTP" = "400" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} Soin plante inexistante -> erreur HTTP $HTTP"
else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC} Soin plante inexistante -> HTTP $HTTP (attendu 4xx)"
fi

# XP didn't crash
RESP=$(call_api GET "gamification/profile" "" "$TOKEN1")
run_test "Profil toujours accessible apres erreur" "$RESP" "200" "xp"

# ============================================================
# Step 46: URBAN_JUNGLE badge (15 plants)
# ============================================================

echo -e "\n${YELLOW}[46] Badge URBAN_JUNGLE (15 plantes)${NC}"

# User1 has 4 plants (deleted 1). Add 11 more to reach 15
RESP=$(call_api GET "gamification/profile" "" "$TOKEN1")
BODY=$(echo "$RESP" | sed '$d')
CURRENT_PLANTS=$(get_field "$BODY" "totalPlantsAdded")
echo -e "  User1 totalPlantsAdded: $CURRENT_PLANTS"

for i in $(seq 1 11); do
    RESP=$(call_api POST "plants" "{\"nickname\":\"Plante Extra $i\",\"wateringIntervalDays\":7}" "$TOKEN1")
done
echo -e "  11 plantes ajoutees"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN1")
BODY=$(echo "$RESP" | sed '$d')
assert_eq "Badge URBAN_JUNGLE debloque (15+ plantes)" "$(has_badge "$BODY" "URBAN_JUNGLE")" "true"
NEW_PLANTS=$(get_field "$BODY" "totalPlantsAdded")
assert_eq "totalPlantsAdded = $((CURRENT_PLANTS + 11))" "$NEW_PLANTS" "$((CURRENT_PLANTS + 11))"

# ============================================================
# Step 47: Level never goes down after delete
# ============================================================

echo -e "\n${YELLOW}[47] Niveau ne descend jamais${NC}"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN1")
BODY=$(echo "$RESP" | sed '$d')
LEVEL_BEFORE=$(get_field "$BODY" "level")
XP_BEFORE=$(get_field "$BODY" "xp")
echo -e "  Level: $LEVEL_BEFORE, XP: $XP_BEFORE"

# Even after deleting lots of plants, level stays
assert_ge "Niveau >= 2 (jamais redescend)" "$LEVEL_BEFORE" "2"

# ============================================================
# Step 48: Empty string notes in care-log
# ============================================================

echo -e "\n${YELLOW}[48] Notes vides dans care-log${NC}"

RESP=$(call_api POST "plants/$PLANT1_ID/care-logs" '{"action":"NOTE","notes":""}' "$TOKEN1")
run_test "Note avec notes vides = OK" "$RESP" "201"

RESP=$(call_api POST "plants/$PLANT1_ID/care-logs" '{"action":"NOTE"}' "$TOKEN1")
HTTP=$(echo "$RESP" | tail -1)
TOTAL=$((TOTAL + 1))
if [ "$HTTP" = "201" ] || [ "$HTTP" = "200" ] || [ "$HTTP" = "400" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} Note sans champ notes -> HTTP $HTTP (accepte ou refuse proprement)"
else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC} Note sans notes -> HTTP $HTTP (attendu 201 ou 400)"
fi

# ============================================================
# Step 49: Special characters in plant names (no XP impact)
# ============================================================

echo -e "\n${YELLOW}[49] Caracteres speciaux dans noms de plantes${NC}"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN1")
BODY=$(echo "$RESP" | sed '$d')
XP_BEFORE=$(get_field "$BODY" "xp")

RESP=$(call_api POST "plants" '{"nickname":"L'\''arbre d'\''été 🌴","wateringIntervalDays":5}' "$TOKEN1")
HTTP=$(echo "$RESP" | tail -1)
if [ "$HTTP" = "201" ]; then
    RESP=$(call_api GET "gamification/profile" "" "$TOKEN1")
    run_test_value "XP +20 apres plante avec accents/emojis" "$RESP" "200" "xp" "$((XP_BEFORE + 20))"
else
    echo -e "  (Plante avec caracteres speciaux rejetee HTTP $HTTP - OK)"
fi

# ============================================================
# Step 50: Leaderboard tie (same XP)
# ============================================================

echo -e "\n${YELLOW}[50] Leaderboard avec egalite de XP${NC}"

# Create new house with users at 0 XP
TOKEN5=$(do_login "gam${TS}u5@test.com" "TestGam1234" "GamUser5-$TS")
TOKEN6=$(do_login "gam${TS}u6@test.com" "TestGam1234" "GamUser6-$TS")

RESP=$(call_api POST "houses" "{\"name\":\"Tie House $TS\"}" "$TOKEN5")
BODY=$(echo "$RESP" | sed '$d')
TIE_HOUSE_ID=$(get_field "$BODY" "id")
TIE_INVITE=$(get_field "$BODY" "inviteCode")

RESP=$(call_api POST "houses/join" "{\"inviteCode\":\"$TIE_INVITE\"}" "$TOKEN6")

RESP=$(call_api GET "gamification/leaderboard/$TIE_HOUSE_ID" "" "$TOKEN5")
BODY=$(echo "$RESP" | sed '$d')
TIE_COUNT=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d))" 2>/dev/null)
TIE_XP1=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['xp'])" 2>/dev/null)
TIE_XP2=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[1]['xp'])" 2>/dev/null)
assert_eq "Leaderboard avec egalite: 2 membres" "$TIE_COUNT" "2"
assert_eq "Les 2 ont 0 XP" "$TIE_XP1" "$TIE_XP2"

# ============================================================
# Step 51: Profile idempotent reads (calling GET multiple times)
# ============================================================

echo -e "\n${YELLOW}[51] Lectures repetees du profil (idempotent)${NC}"

RESP1=$(call_api GET "gamification/profile" "" "$TOKEN1")
BODY1=$(echo "$RESP1" | sed '$d')
XP1=$(get_field "$BODY1" "xp")

RESP2=$(call_api GET "gamification/profile" "" "$TOKEN1")
BODY2=$(echo "$RESP2" | sed '$d')
XP2=$(get_field "$BODY2" "xp")

RESP3=$(call_api GET "gamification/profile" "" "$TOKEN1")
BODY3=$(echo "$RESP3" | sed '$d')
XP3=$(get_field "$BODY3" "xp")

assert_eq "3 lectures = meme XP (1)" "$XP1" "$XP2"
assert_eq "3 lectures = meme XP (2)" "$XP2" "$XP3"

UNLOCK1=$(count_unlocked "$BODY1")
UNLOCK3=$(count_unlocked "$BODY3")
assert_eq "3 lectures = meme nombre de badges" "$UNLOCK1" "$UNLOCK3"

# ============================================================
# Step 52: XP never negative
# ============================================================

echo -e "\n${YELLOW}[52] XP jamais negatif${NC}"

for token_var in "$TOKEN1" "$TOKEN2" "$TOKEN3" "$TOKEN4"; do
    RESP=$(call_api GET "gamification/profile" "" "$token_var")
    BODY=$(echo "$RESP" | sed '$d')
    XP=$(get_field "$BODY" "xp")
    TOTAL=$((TOTAL + 1))
    if [ "$XP" -ge 0 ] 2>/dev/null; then
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC} XP >= 0 ($XP)"
    else
        FAIL=$((FAIL + 1))
        echo -e "  ${RED}FAIL${NC} XP negatif: $XP"
    fi
done

# ============================================================
# Step 53: COLLECTOR not unlocked with < 5 plants
# ============================================================

echo -e "\n${YELLOW}[53] COLLECTOR pas debloque avec < 5 plantes${NC}"

TOKEN7=$(do_login "gam${TS}u7@test.com" "TestGam1234" "GamUser7-$TS")

for i in 1 2 3 4; do
    call_api POST "plants" "{\"nickname\":\"Mini$i\",\"wateringIntervalDays\":5}" "$TOKEN7" > /dev/null
done
echo -e "  4 plantes ajoutees"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN7")
BODY=$(echo "$RESP" | sed '$d')
assert_eq "COLLECTOR verrouille avec 4 plantes" "$(has_badge "$BODY" "COLLECTOR")" "false"
run_test_value "XP = 80 (4x20)" "$RESP" "200" "xp" "80"

# Add 5th plant -> should trigger COLLECTOR
RESP=$(call_api POST "plants" '{"nickname":"Mini5","wateringIntervalDays":5}' "$TOKEN7")
run_test "5eme plante ajoutee" "$RESP" "201"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN7")
BODY=$(echo "$RESP" | sed '$d')
assert_eq "COLLECTOR debloque avec 5 plantes" "$(has_badge "$BODY" "COLLECTOR")" "true"
run_test_value "XP = 100 (5x20)" "$RESP" "200" "xp" "100"

# ============================================================
# Step 54: Multiple notes same plant same day = 0 XP total
# ============================================================

echo -e "\n${YELLOW}[54] 20 notes meme plante meme jour = 0 XP total${NC}"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN7")
BODY=$(echo "$RESP" | sed '$d')
XP_BEFORE=$(get_field "$BODY" "xp")

FIRST_PLANT=$(call_api GET "plants" "" "$TOKEN7" | sed '$d' | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['id'])" 2>/dev/null)

for i in $(seq 1 20); do
    call_api POST "plants/$FIRST_PLANT/care-logs" "{\"action\":\"NOTE\",\"notes\":\"Spam note $i\"}" "$TOKEN7" > /dev/null
done
echo -e "  20 notes ajoutees"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN7")
run_test_value "XP inchange apres 20 notes = $XP_BEFORE" "$RESP" "200" "xp" "$XP_BEFORE"

# ============================================================
# Step 55: Care action on different plants same type same day = XP for each
# ============================================================

echo -e "\n${YELLOW}[55] Meme type de soin sur 5 plantes differentes = 5x15 XP${NC}"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN7")
BODY=$(echo "$RESP" | sed '$d')
XP_BEFORE=$(get_field "$BODY" "xp")

ALL_PLANTS=$(call_api GET "plants" "" "$TOKEN7" | sed '$d' | python3 -c "
import sys,json; d=json.load(sys.stdin)
for p in d[:5]: print(p['id'])
" 2>/dev/null)

for plant_id in $ALL_PLANTS; do
    call_api POST "plants/$plant_id/care-logs" '{"action":"FERTILIZING","notes":""}' "$TOKEN7" > /dev/null
done
echo -e "  5 fertilisations sur 5 plantes"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN7")
BODY=$(echo "$RESP" | sed '$d')
XP_AFTER=$(get_field "$BODY" "xp")
assert_eq "5 plantes x 15 XP = +75" "$XP_AFTER" "$((XP_BEFORE + 75))"

# ============================================================
# Step 56: BOTANIST not triggered by empty customSpecies
# ============================================================

echo -e "\n${YELLOW}[56] customSpecies vide ne compte pas pour BOTANIST${NC}"

TOKEN8=$(do_login "gam${TS}u8@test.com" "TestGam1234" "GamUser8-$TS")

for i in 1 2 3 4 5; do
    call_api POST "plants" "{\"nickname\":\"Blank$i\",\"customSpecies\":\"\",\"wateringIntervalDays\":5}" "$TOKEN8" > /dev/null
done
echo -e "  5 plantes avec customSpecies vide"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN8")
BODY=$(echo "$RESP" | sed '$d')
assert_eq "BOTANIST verrouille (customSpecies vide)" "$(has_badge "$BODY" "BOTANIST")" "false"
assert_eq "COLLECTOR debloque (5 plantes)" "$(has_badge "$BODY" "COLLECTOR")" "true"

# ============================================================
# Step 57: Mixed species sources (species + customSpecies)
# ============================================================

echo -e "\n${YELLOW}[57] BOTANIST via mix species DB + customSpecies${NC}"

# User7 has 5 plants with no species. Add plants with different customSpecies
for sp in Aloe Bamboo Cherry Daisy Elm; do
    call_api POST "plants" "{\"nickname\":\"$sp tree\",\"customSpecies\":\"$sp\",\"wateringIntervalDays\":7}" "$TOKEN7" > /dev/null
done
echo -e "  5 plantes avec customSpecies differentes"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN7")
BODY=$(echo "$RESP" | sed '$d')
assert_eq "User7 a BOTANIST (5 custom species)" "$(has_badge "$BODY" "BOTANIST")" "true"

# ============================================================
# Step 58: HTTP methods not allowed
# ============================================================

echo -e "\n${YELLOW}[58] Methodes HTTP non autorisees${NC}"

RESP=$(curl -s -w "\n%{http_code}" -X POST -H "Authorization: Bearer $TOKEN1" -H "Content-Type: application/json" "$BASE_URL/gamification/profile")
HTTP=$(echo "$RESP" | tail -1)
TOTAL=$((TOTAL + 1))
if [ "$HTTP" = "405" ] || [ "$HTTP" = "404" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} POST /gamification/profile -> $HTTP (interdit)"
else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC} POST /gamification/profile -> $HTTP (attendu 405)"
fi

RESP=$(curl -s -w "\n%{http_code}" -X DELETE -H "Authorization: Bearer $TOKEN1" "$BASE_URL/gamification/profile")
HTTP=$(echo "$RESP" | tail -1)
TOTAL=$((TOTAL + 1))
if [ "$HTTP" = "405" ] || [ "$HTTP" = "404" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} DELETE /gamification/profile -> $HTTP (interdit)"
else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC} DELETE /gamification/profile -> $HTTP (attendu 405)"
fi

# ============================================================
# Step 59: Rapid-fire XP consistency (10 plants in burst)
# ============================================================

echo -e "\n${YELLOW}[59] Burst de 10 plantes -> XP coherent${NC}"

TOKEN9=$(do_login "gam${TS}u9@test.com" "TestGam1234" "GamUser9-$TS")

for i in $(seq 1 10); do
    call_api POST "plants" "{\"nickname\":\"Burst$i\",\"wateringIntervalDays\":$((i+1))}" "$TOKEN9" > /dev/null
done
echo -e "  10 plantes ajoutees en burst"

RESP=$(call_api GET "gamification/profile" "" "$TOKEN9")
BODY=$(echo "$RESP" | sed '$d')
run_test_value "XP = 200 (10x20)" "$RESP" "200" "xp" "200"
run_test_value "Level 2 (Pousse >= 100)" "$RESP" "200" "level" "2"
run_test_value "totalPlantsAdded = 10" "$RESP" "200" "totalPlantsAdded" "10"
assert_eq "COLLECTOR debloque" "$(has_badge "$BODY" "COLLECTOR")" "true"

# ============================================================
# Step 60: Leaderboard invalid UUID format
# ============================================================

echo -e "\n${YELLOW}[60] Leaderboard UUID invalide${NC}"

RESP=$(call_api GET "gamification/leaderboard/not-a-uuid" "" "$TOKEN1")
HTTP=$(echo "$RESP" | tail -1)
TOTAL=$((TOTAL + 1))
if [ "$HTTP" = "400" ] || [ "$HTTP" = "404" ] || [ "$HTTP" = "500" ] || [ "$HTTP" = "403" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} Leaderboard UUID invalide -> HTTP $HTTP"
else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC} Leaderboard UUID invalide -> HTTP $HTTP"
fi

# ============================================================
# SUMMARY
# ============================================================

echo -e "\n${CYAN}============================================================${NC}"
echo -e "${CYAN}  RESULTATS${NC}"
echo -e "${CYAN}============================================================${NC}"

if [ "$FAIL" -eq 0 ]; then
    echo -e "\n  ${GREEN}TOUS LES TESTS PASSENT: $PASS/$TOTAL${NC}\n"
else
    echo -e "\n  ${GREEN}PASS: $PASS${NC} | ${RED}FAIL: $FAIL${NC} | TOTAL: $TOTAL\n"
fi

exit $FAIL
