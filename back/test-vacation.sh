#!/bin/bash
#
# Script de test complet du mode vacances / delegation temporaire
# Usage: ./test-vacation.sh [BASE_URL]
#
# Prerequis: le backend doit tourner (./mvnw quarkus:dev)
#

BASE_URL="${1:-http://localhost:8080/api/v1}"
PASS=0
FAIL=0
TOTAL=0
TOKEN1=""
TOKEN2=""
TOKEN3=""
USER1_ID=""
USER2_ID=""
USER3_ID=""
HOUSE_ID=""
INVITE_CODE=""

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

# ============================================================
echo -e "\n${CYAN}============================================================${NC}"
echo -e "${CYAN} MODE VACANCES / DELEGATION TEMPORAIRE - TESTS COMPLETS${NC}"
echo -e "${CYAN}============================================================${NC}"

# ============================================================
# Step 0: Authentication (3 users)
# ============================================================

echo -e "\n${YELLOW}[0] Authentication - 3 utilisateurs${NC}"

TOKEN1=$(do_login "vactest1@example.com" "Test1234!" "VacUser1")
if [ -z "$TOKEN1" ]; then
    echo -e "${RED}FATAL: Cannot login user 1${NC}"
    exit 1
fi
USER1_ID=$(get_user_id "$TOKEN1")
echo -e "  User 1: $USER1_ID"

TOKEN2=$(do_login "vactest2@example.com" "Test1234!" "VacUser2")
if [ -z "$TOKEN2" ]; then
    echo -e "${RED}FATAL: Cannot login user 2${NC}"
    exit 1
fi
USER2_ID=$(get_user_id "$TOKEN2")
echo -e "  User 2: $USER2_ID"

TOKEN3=$(do_login "vactest3@example.com" "Test1234!" "VacUser3")
if [ -z "$TOKEN3" ]; then
    echo -e "${RED}FATAL: Cannot login user 3${NC}"
    exit 1
fi
USER3_ID=$(get_user_id "$TOKEN3")
echo -e "  User 3: $USER3_ID"

# ============================================================
# Step 1: Create a house and have all users join
# ============================================================

echo -e "\n${YELLOW}[1] Setup - Maison commune${NC}"

# User1 creates the house
RESP=$(call_api POST "houses" '{"name":"Maison Vacances Test"}' "$TOKEN1")
HTTP=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')
HOUSE_ID=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
INVITE_CODE=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('inviteCode',''))" 2>/dev/null)
run_test "User1 cree la maison" "$RESP" "201" "inviteCode"
echo -e "  House: $HOUSE_ID | Invite: $INVITE_CODE"

# User2 joins
RESP=$(call_api POST "houses/join" "{\"inviteCode\":\"$INVITE_CODE\"}" "$TOKEN2")
run_test "User2 rejoint la maison" "$RESP" "200" "Maison Vacances"

# User3 joins
RESP=$(call_api POST "houses/join" "{\"inviteCode\":\"$INVITE_CODE\"}" "$TOKEN3")
run_test "User3 rejoint la maison" "$RESP" "200" "Maison Vacances"

# Verify members
RESP=$(call_api GET "houses/$HOUSE_ID/members" "" "$TOKEN1")
run_test "3 membres dans la maison" "$RESP" "200" "VacUser3"

# ============================================================
# Step 2: Vacation - validation errors (check HTTP code only)
# ============================================================

echo -e "\n${YELLOW}[2] Validations - Cas d'erreur${NC}"

# Self-delegation
RESP=$(call_api POST "houses/$HOUSE_ID/vacation" \
    "{\"delegateId\":\"$USER1_ID\",\"startDate\":\"2026-03-12\",\"endDate\":\"2026-03-20\"}" "$TOKEN1")
run_test "Auto-delegation interdite (400)" "$RESP" "400"

# End before start
RESP=$(call_api POST "houses/$HOUSE_ID/vacation" \
    "{\"delegateId\":\"$USER2_ID\",\"startDate\":\"2026-03-20\",\"endDate\":\"2026-03-12\"}" "$TOKEN1")
run_test "Fin avant debut interdite (400)" "$RESP" "400"

# End date in the past
RESP=$(call_api POST "houses/$HOUSE_ID/vacation" \
    "{\"delegateId\":\"$USER2_ID\",\"startDate\":\"2025-01-01\",\"endDate\":\"2025-01-10\"}" "$TOKEN1")
run_test "Date passee interdite (400)" "$RESP" "400"

# Non-member delegate (random UUID)
RESP=$(call_api POST "houses/$HOUSE_ID/vacation" \
    "{\"delegateId\":\"00000000-0000-0000-0000-000000000001\",\"startDate\":\"2026-03-12\",\"endDate\":\"2026-03-20\"}" "$TOKEN1")
run_test "Delegue non-membre interdit (400)" "$RESP" "400"

# Non-member house
FAKE_HOUSE="00000000-0000-0000-0000-000000000099"
RESP=$(call_api POST "houses/$FAKE_HOUSE/vacation" \
    "{\"delegateId\":\"$USER2_ID\",\"startDate\":\"2026-03-12\",\"endDate\":\"2026-03-20\"}" "$TOKEN1")
run_test "Maison non-membre interdite (403)" "$RESP" "403"

# ============================================================
# Step 3: Activate vacation
# ============================================================

echo -e "\n${YELLOW}[3] Activer le mode vacances${NC}"

RESP=$(call_api POST "houses/$HOUSE_ID/vacation" \
    "{\"delegateId\":\"$USER2_ID\",\"startDate\":\"2026-03-11\",\"endDate\":\"2026-03-25\",\"message\":\"Merci de bien arroser mes plantes!\"}" "$TOKEN1")
run_test "User1 active le mode vacances" "$RESP" "201" "delegatorName"
BODY=$(echo "$RESP" | sed '$d')
DELEGATION_ID=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
echo -e "  Delegation ID: $DELEGATION_ID"

# ============================================================
# Step 4: Double-vacation forbidden
# ============================================================

echo -e "\n${YELLOW}[4] Double vacation interdite${NC}"

RESP=$(call_api POST "houses/$HOUSE_ID/vacation" \
    "{\"delegateId\":\"$USER3_ID\",\"startDate\":\"2026-03-12\",\"endDate\":\"2026-03-20\"}" "$TOKEN1")
run_test "Double vacation interdite (400)" "$RESP" "400"

# ============================================================
# Step 5: Cannot delegate to someone who is on vacation
# ============================================================

echo -e "\n${YELLOW}[5] Deleguer a un vacancier interdit${NC}"

# User2 goes on vacation first (delegates to User3)
RESP=$(call_api POST "houses/$HOUSE_ID/vacation" \
    "{\"delegateId\":\"$USER3_ID\",\"startDate\":\"2026-03-12\",\"endDate\":\"2026-03-20\"}" "$TOKEN2")
run_test "User2 active ses vacances (delegue a User3)" "$RESP" "201"

# Now User3 tries to delegate to User2, but User2 has an active delegation
RESP=$(call_api POST "houses/$HOUSE_ID/vacation" \
    "{\"delegateId\":\"$USER2_ID\",\"startDate\":\"2026-03-12\",\"endDate\":\"2026-03-20\"}" "$TOKEN3")
run_test "Deleguer a un vacancier interdit (400)" "$RESP" "400"

# Cancel User2's vacation for clean state
call_api DELETE "houses/$HOUSE_ID/vacation" "" "$TOKEN2" > /dev/null

# ============================================================
# Step 6: Get vacation status
# ============================================================

echo -e "\n${YELLOW}[6] Statut vacances${NC}"

# User1 should be on vacation
RESP=$(call_api GET "houses/$HOUSE_ID/vacation" "" "$TOKEN1")
run_test "User1 est en vacances" "$RESP" "200" "delegateName"

# User2 not on vacation (cancelled)
RESP=$(call_api GET "houses/$HOUSE_ID/vacation" "" "$TOKEN2")
run_test "User2 pas en vacances (204)" "$RESP" "204"

# User3 not on vacation
RESP=$(call_api GET "houses/$HOUSE_ID/vacation" "" "$TOKEN3")
run_test "User3 pas en vacances (204)" "$RESP" "204"

# ============================================================
# Step 7: House delegations
# ============================================================

echo -e "\n${YELLOW}[7] Delegations dans la maison${NC}"

RESP=$(call_api GET "houses/$HOUSE_ID/delegations" "" "$TOKEN1")
run_test "Liste delegations actives" "$RESP" "200" "VacUser1"

RESP=$(call_api GET "houses/$HOUSE_ID/delegations" "" "$TOKEN2")
run_test "Tous les membres voient les delegations" "$RESP" "200" "VacUser1"

# ============================================================
# Step 8: My delegations (delegate perspective)
# ============================================================

echo -e "\n${YELLOW}[8] Mes delegations recues${NC}"

RESP=$(call_api GET "houses/$HOUSE_ID/my-delegations" "" "$TOKEN2")
run_test "User2 voit ses delegations recues" "$RESP" "200" "VacUser1"

RESP=$(call_api GET "houses/$HOUSE_ID/my-delegations" "" "$TOKEN3")
run_test "User3 n'a pas de delegations" "$RESP" "200"

# ============================================================
# Step 9: Delegate can access delegator's plants
# ============================================================

echo -e "\n${YELLOW}[9] Acces aux plantes du vacancier${NC}"

# Ensure User1's active house is set
call_api PUT "houses/$HOUSE_ID/activate" "" "$TOKEN1" > /dev/null
# Ensure User2's active house is set
call_api PUT "houses/$HOUSE_ID/activate" "" "$TOKEN2" > /dev/null
# Ensure User3's active house is set
call_api PUT "houses/$HOUSE_ID/activate" "" "$TOKEN3" > /dev/null

# User1 creates a plant (with OffsetDateTime for lastWatered)
RESP=$(call_api POST "plants" \
    "{\"nickname\":\"Monstera Vacances\",\"wateringIntervalDays\":3,\"lastWatered\":\"2026-03-01T00:00:00Z\"}" "$TOKEN1")
HTTP=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')
PLANT_ID=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)

if [ "$HTTP" = "201" ] && [ -n "$PLANT_ID" ] && [ "$PLANT_ID" != "" ]; then
    echo -e "  Plante creee: $PLANT_ID"

    # User2 (delegate) can see the plant
    RESP=$(call_api GET "plants/$PLANT_ID" "" "$TOKEN2")
    run_test "Delegue peut voir la plante du vacancier" "$RESP" "200" "Monstera Vacances"

    # User2 can water the plant
    RESP=$(call_api POST "plants/$PLANT_ID/water" "{}" "$TOKEN2")
    run_test "Delegue peut arroser la plante du vacancier" "$RESP" "200"

    # User3 should NOT have access (not a delegate for User1)
    RESP=$(call_api GET "plants/$PLANT_ID" "" "$TOKEN3")
    run_test "Non-delegue ne peut pas voir la plante (403)" "$RESP" "403"
else
    echo -e "  ${RED}Plant creation failed (HTTP $HTTP)${NC}"
    echo -e "  Body: $BODY"
    TOTAL=$((TOTAL + 3))
    FAIL=$((FAIL + 3))
fi

# ============================================================
# Step 10: Cancel vacation (early return)
# ============================================================

echo -e "\n${YELLOW}[10] Annulation des vacances (retour anticipe)${NC}"

RESP=$(call_api DELETE "houses/$HOUSE_ID/vacation" "" "$TOKEN1")
run_test "User1 annule ses vacances" "$RESP" "204"

# Verify status is now empty
RESP=$(call_api GET "houses/$HOUSE_ID/vacation" "" "$TOKEN1")
run_test "User1 n'est plus en vacances (204)" "$RESP" "204"

# Delegations should be empty now
RESP=$(call_api GET "houses/$HOUSE_ID/delegations" "" "$TOKEN1")
BODY=$(echo "$RESP" | sed '$d')
COUNT=$(echo "$BODY" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null)
TOTAL=$((TOTAL + 1))
if [ "$COUNT" = "0" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} Plus de delegations actives (count=0)"
else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC} Devrait avoir 0 delegations actives (got $COUNT)"
fi

# User2 no longer has delegations
RESP=$(call_api GET "houses/$HOUSE_ID/my-delegations" "" "$TOKEN2")
run_test "User2 n'a plus de delegations" "$RESP" "200"

# After cancellation, User2 should NOT be able to access User1's plant
if [ -n "$PLANT_ID" ] && [ "$PLANT_ID" != "" ]; then
    RESP=$(call_api GET "plants/$PLANT_ID" "" "$TOKEN2")
    run_test "Delegue perd l'acces apres annulation (403)" "$RESP" "403"
fi

# ============================================================
# Step 11: Cancel when not on vacation
# ============================================================

echo -e "\n${YELLOW}[11] Annulation sans vacances${NC}"

RESP=$(call_api DELETE "houses/$HOUSE_ID/vacation" "" "$TOKEN1")
run_test "Annulation sans vacances = 404" "$RESP" "404"

# ============================================================
# Step 12: Watering reminders redirect test
# ============================================================

echo -e "\n${YELLOW}[12] Rappels d'arrosage + mode vacances${NC}"

# Re-activate vacation for User1
RESP=$(call_api POST "houses/$HOUSE_ID/vacation" \
    "{\"delegateId\":\"$USER2_ID\",\"startDate\":\"2026-03-11\",\"endDate\":\"2026-03-25\"}" "$TOKEN1")
run_test "Re-activation vacances User1" "$RESP" "201"

# Trigger reminders (should redirect User1's reminders to User2)
RESP=$(call_api POST "notifications/trigger-reminders" "{}" "$TOKEN1")
run_test "Declenchement rappels avec vacances actives" "$RESP" "200" "triggered"

# Check User2 got notifications (as delegate)
RESP=$(call_api GET "notifications?unreadOnly=true" "" "$TOKEN2")
run_test "User2 recoit les rappels du vacancier" "$RESP" "200"

# ============================================================
# Step 13: Multiple delegations to same delegate
# ============================================================

echo -e "\n${YELLOW}[13] Delegations multiples vers meme delegue${NC}"

# User3 also delegates to User2
RESP=$(call_api POST "houses/$HOUSE_ID/vacation" \
    "{\"delegateId\":\"$USER2_ID\",\"startDate\":\"2026-03-11\",\"endDate\":\"2026-03-20\"}" "$TOKEN3")
run_test "User3 delegue aussi a User2" "$RESP" "201"

# User2 should see 2 delegations
RESP=$(call_api GET "houses/$HOUSE_ID/my-delegations" "" "$TOKEN2")
BODY=$(echo "$RESP" | sed '$d')
COUNT=$(echo "$BODY" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null)
TOTAL=$((TOTAL + 1))
if [ "$COUNT" = "2" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} User2 a 2 delegations (count=$COUNT)"
else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC} User2 devrait avoir 2 delegations (got $COUNT)"
fi

# House should show 2 delegations
RESP=$(call_api GET "houses/$HOUSE_ID/delegations" "" "$TOKEN1")
BODY=$(echo "$RESP" | sed '$d')
COUNT=$(echo "$BODY" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null)
TOTAL=$((TOTAL + 1))
if [ "$COUNT" = "2" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} Maison a 2 delegations actives (count=$COUNT)"
else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC} Maison devrait avoir 2 delegations (got $COUNT)"
fi

# ============================================================
# Cleanup
# ============================================================

echo -e "\n${YELLOW}[Cleanup] Annulation des vacances restantes${NC}"
call_api DELETE "houses/$HOUSE_ID/vacation" "" "$TOKEN1" > /dev/null
call_api DELETE "houses/$HOUSE_ID/vacation" "" "$TOKEN3" > /dev/null
echo -e "  Done."

# ============================================================
# Summary
# ============================================================

echo -e "\n${CYAN}============================================================${NC}"
echo -e "${CYAN} RESULTATS${NC}"
echo -e "${CYAN}============================================================${NC}"
echo -e "  Total:  $TOTAL"
echo -e "  ${GREEN}PASS:   $PASS${NC}"
echo -e "  ${RED}FAIL:   $FAIL${NC}"

if [ "$FAIL" -eq 0 ]; then
    echo -e "\n  ${GREEN}TOUS LES TESTS PASSENT !${NC}"
else
    echo -e "\n  ${RED}$FAIL TEST(S) EN ECHEC${NC}"
fi

echo ""
exit $FAIL
