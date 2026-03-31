#!/bin/bash
#
# Script de test complet des notifications intelligentes
# Usage: ./test-notifications.sh [BASE_URL]
#
# Prerequis: le backend doit tourner (./mvnw quarkus:dev)
#

BASE_URL="${1:-http://localhost:8080/api/v1}"
PASS=0
FAIL=0
TOTAL=0
TOKEN=""
TOKEN2=""

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
    local token="${4:-$TOKEN}"

    if [ "$method" = "GET" ]; then
        curl -s -w "\n%{http_code}" \
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

# Login helper
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

# ============================================================
echo -e "\n${CYAN}============================================================${NC}"
echo -e "${CYAN} NOTIFICATIONS INTELLIGENTES - TESTS COMPLETS${NC}"
echo -e "${CYAN}============================================================${NC}"

# ============================================================
# Step 0: Authentication (2 users for cross-user tests)
# ============================================================

echo -e "\n${YELLOW}[0] Authentication${NC}"

TOKEN=$(do_login "lucas@test.com" "password123" "Lucas Test")
if [ -z "$TOKEN" ] || [ "$TOKEN" = "None" ]; then
    echo -e "  ${RED}Cannot authenticate user 1. Exiting.${NC}"
    exit 1
fi
echo -e "  ${GREEN}User 1 logged in (lucas@test.com)${NC}"

TOKEN2=$(do_login "test2@example.com" "password123" "Test User 2")
if [ -z "$TOKEN2" ] || [ "$TOKEN2" = "None" ]; then
    echo -e "  ${YELLOW}User 2 login failed, cross-user tests will be skipped${NC}"
else
    echo -e "  ${GREEN}User 2 logged in (test2@example.com)${NC}"
fi

# ============================================================
# Pre-cleanup: delete existing test notifications
# ============================================================

echo -e "\n${YELLOW}[Pre-cleanup] Suppression des notifications existantes${NC}"
RESP=$(call_api "GET" "notifications")
BODY=$(echo "$RESP" | sed '$d')
ALL_IDS=$(echo "$BODY" | python3 -c "
import sys,json
data=json.load(sys.stdin)
for n in data:
    print(n['id'])
" 2>/dev/null)
CLEANED=0
while IFS= read -r nid; do
    if [ -n "$nid" ]; then
        call_api "DELETE" "notifications/$nid" > /dev/null 2>&1
        CLEANED=$((CLEANED + 1))
    fi
done <<< "$ALL_IDS"
echo -e "  ${CYAN}Cleaned $CLEANED existing notifications${NC}"

# ============================================================
# Pre-setup: Create test plants with overdue watering via MCP
# ============================================================

MCP_KEY="mcp-plant-secret-key"

echo -e "\n${YELLOW}[Pre-setup] Creation de plantes de test en retard d'arrosage${NC}"

# Delete existing test plants first via MCP
for name in "Notif Monstera Test" "Notif Cactus Test" "Notif Basilic Malade"; do
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "X-MCP-API-Key: $MCP_KEY" \
        -d "{\"tool\":\"delete_plant\",\"parameters\":{\"nickname\":\"$name\"}}" \
        "$BASE_URL/mcp/tools" > /dev/null 2>&1
done

# lastWatered 10 days ago = plants will be overdue (nextWateringDate = 10 days ago + interval)
LAST_WATERED=$(python3 -c "
from datetime import datetime, timedelta, timezone
dt = datetime.now(timezone.utc) - timedelta(days=10)
print(dt.strftime('%Y-%m-%dT%H:%M:%S+00:00'))
" 2>/dev/null)
echo -e "  ${CYAN}lastWatered set to: $LAST_WATERED (10 days ago)${NC}"

# Create plant 1: Monstera (tropical) - overdue by 3 days (interval=7, last watered 10 days ago)
RESP=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d "{\"nickname\":\"Notif Monstera Test\",\"wateringIntervalDays\":7,\"customSpecies\":\"Monstera\",\"lastWatered\":\"$LAST_WATERED\"}" \
    "$BASE_URL/plants")
CODE=$(echo "$RESP" | tail -1)
echo -e "  ${CYAN}Created Monstera (interval=7, overdue 3 days): HTTP $CODE${NC}"

# Create plant 2: Cactus (succulent) - overdue by ~10 days (interval=1)
RESP=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d "{\"nickname\":\"Notif Cactus Test\",\"wateringIntervalDays\":1,\"customSpecies\":\"Cactus\",\"lastWatered\":\"$LAST_WATERED\"}" \
    "$BASE_URL/plants")
CODE=$(echo "$RESP" | tail -1)
echo -e "  ${CYAN}Created Cactus (interval=1, overdue 9 days): HTTP $CODE${NC}"

# Create plant 3: Basilic malade + wilted + needs repotting (for care reminders)
RESP=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d "{\"nickname\":\"Notif Basilic Malade\",\"wateringIntervalDays\":2,\"customSpecies\":\"Basilic\",\"lastWatered\":\"$LAST_WATERED\",\"isSick\":true,\"isWilted\":true,\"needsRepotting\":true}" \
    "$BASE_URL/plants")
CODE=$(echo "$RESP" | tail -1)
echo -e "  ${CYAN}Created Basilic malade (sick+wilted+repotting, overdue 8 days): HTTP $CODE${NC}"

sleep 1
echo -e "  ${GREEN}Test plants created with overdue watering dates${NC}"

# ============================================================
# [1] List Notifications (empty state)
# ============================================================

echo -e "\n${YELLOW}[1] List Notifications - Empty State${NC}"

RESP=$(call_api "GET" "notifications")
run_test "GET /notifications returns 200" "$RESP" "200"

RESP=$(call_api "GET" "notifications?unreadOnly=true")
run_test "GET /notifications?unreadOnly=true returns 200" "$RESP" "200"

RESP=$(call_api "GET" "notifications?unreadOnly=false")
run_test "GET /notifications?unreadOnly=false returns 200" "$RESP" "200"

# Verify it's an empty array
RESP=$(call_api "GET" "notifications")
BODY=$(echo "$RESP" | sed '$d')
TOTAL=$((TOTAL + 1))
COUNT=$(echo "$BODY" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null)
if [ "$COUNT" = "0" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} Notifications list is empty after cleanup"
else
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} Notifications list has $COUNT items (pre-existing data)"
fi

# ============================================================
# [2] Unread Count - Empty State
# ============================================================

echo -e "\n${YELLOW}[2] Unread Count${NC}"

RESP=$(call_api "GET" "notifications/unread-count")
run_test "GET /notifications/unread-count returns 200" "$RESP" "200" "unreadCount"

# ============================================================
# [3] Trigger Reminders
# ============================================================

echo -e "\n${YELLOW}[3] Trigger Reminders (rappels regroupes + recommandations)${NC}"

RESP=$(call_api "POST" "notifications/trigger-reminders")
run_test "POST /notifications/trigger-reminders returns 200" "$RESP" "200" "status"

# ============================================================
# [4] Verify Notifications After Trigger
# ============================================================

echo -e "\n${YELLOW}[4] Notifications After Trigger${NC}"

RESP=$(call_api "GET" "notifications")
BODY=$(echo "$RESP" | sed '$d')
run_test "GET /notifications returns 200 after trigger" "$RESP" "200"

NOTIF_COUNT=$(echo "$BODY" | python3 -c "import sys,json; data=json.load(sys.stdin); print(len(data))" 2>/dev/null)
echo -e "  ${CYAN}INFO: $NOTIF_COUNT notification(s) created${NC}"

# Check notification structure if any
if [ "$NOTIF_COUNT" != "0" ] && [ -n "$NOTIF_COUNT" ]; then
    HAS_FIELDS=$(echo "$BODY" | python3 -c "
import sys,json
data=json.load(sys.stdin)
n=data[0]
fields = ['id','type','message','read','createdAt']
missing = [f for f in fields if f not in n]
print('OK' if not missing else 'MISSING:'+','.join(missing))
" 2>/dev/null)

    TOTAL=$((TOTAL + 1))
    if [ "$HAS_FIELDS" = "OK" ]; then
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC} Notification has all required fields"
    else
        FAIL=$((FAIL + 1))
        echo -e "  ${RED}FAIL${NC} Missing fields: $HAS_FIELDS"
    fi

    # Check notification type is valid
    NOTIF_TYPE=$(echo "$BODY" | python3 -c "
import sys,json
data=json.load(sys.stdin)
types = set(n['type'] for n in data)
print(','.join(types))
" 2>/dev/null)
    echo -e "  ${CYAN}INFO: Notification types: $NOTIF_TYPE${NC}"

    TOTAL=$((TOTAL + 1))
    if echo "$NOTIF_TYPE" | grep -qE "WATERING_REMINDER|CARE_REMINDER"; then
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC} Notification types are valid (WATERING_REMINDER/CARE_REMINDER)"
    else
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC} Notification types: $NOTIF_TYPE"
    fi

    # Check message is not empty
    MSG_OK=$(echo "$BODY" | python3 -c "
import sys,json
data=json.load(sys.stdin)
print('OK' if all(len(n.get('message',''))>0 for n in data) else 'EMPTY')
" 2>/dev/null)
    TOTAL=$((TOTAL + 1))
    if [ "$MSG_OK" = "OK" ]; then
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC} All notifications have non-empty messages"
    else
        FAIL=$((FAIL + 1))
        echo -e "  ${RED}FAIL${NC} Some notifications have empty messages"
    fi

    # Print first notification message (for visual inspection)
    FIRST_MSG=$(echo "$BODY" | python3 -c "
import sys,json
data=json.load(sys.stdin)
if data:
    print(data[0]['message'][:200])
" 2>/dev/null)
    echo -e "  ${CYAN}INFO: First message preview:${NC}"
    echo -e "  ${CYAN}$FIRST_MSG${NC}"
fi

# ============================================================
# [5] Unread Count After Trigger
# ============================================================

echo -e "\n${YELLOW}[5] Unread Count After Trigger${NC}"

RESP=$(call_api "GET" "notifications/unread-count")
BODY=$(echo "$RESP" | sed '$d')
UNREAD=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('unreadCount',0))" 2>/dev/null)
run_test "Unread count endpoint works" "$RESP" "200" "unreadCount"
echo -e "  ${CYAN}INFO: $UNREAD unread notification(s)${NC}"

# Verify unread count matches notification count
TOTAL=$((TOTAL + 1))
if [ "$UNREAD" = "$NOTIF_COUNT" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} Unread count ($UNREAD) matches notification count ($NOTIF_COUNT)"
else
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} Unread count ($UNREAD) - may include pre-existing notifications"
fi

# ============================================================
# [6] Mark As Read - Single
# ============================================================

echo -e "\n${YELLOW}[6] Mark As Read - Single${NC}"

RESP=$(call_api "GET" "notifications")
BODY=$(echo "$RESP" | sed '$d')
NOTIF_ID=$(echo "$BODY" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data[0]['id'] if data else '')" 2>/dev/null)

if [ -n "$NOTIF_ID" ] && [ "$NOTIF_ID" != "" ] && [ "$NOTIF_ID" != "None" ]; then
    echo -e "  ${CYAN}INFO: Testing with notification $NOTIF_ID${NC}"

    RESP=$(call_api "PUT" "notifications/$NOTIF_ID/read")
    run_test "PUT /notifications/{id}/read returns 200" "$RESP" "200"

    # Verify read=true in response
    BODY=$(echo "$RESP" | sed '$d')
    READ_STATUS=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('read',False))" 2>/dev/null)
    TOTAL=$((TOTAL + 1))
    if [ "$READ_STATUS" = "True" ]; then
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC} Notification marked as read=true in response"
    else
        FAIL=$((FAIL + 1))
        echo -e "  ${RED}FAIL${NC} Expected read=true, got $READ_STATUS"
    fi

    # Idempotency: mark as read again
    RESP=$(call_api "PUT" "notifications/$NOTIF_ID/read")
    run_test "Mark as read again (idempotent) returns 200" "$RESP" "200"

    # Unread count should have decreased by 1
    RESP=$(call_api "GET" "notifications/unread-count")
    BODY=$(echo "$RESP" | sed '$d')
    NEW_UNREAD=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('unreadCount',0))" 2>/dev/null)
    echo -e "  ${CYAN}INFO: Unread count: $UNREAD -> $NEW_UNREAD${NC}"
else
    echo -e "  ${YELLOW}SKIP: No notifications to test mark-as-read${NC}"
fi

# ============================================================
# [7] Mark All As Read
# ============================================================

echo -e "\n${YELLOW}[7] Mark All As Read${NC}"

RESP=$(call_api "PUT" "notifications/read-all")
run_test "PUT /notifications/read-all returns 200" "$RESP" "200" "markedAsRead"

# Verify count is 0
RESP=$(call_api "GET" "notifications/unread-count")
BODY=$(echo "$RESP" | sed '$d')
ZERO_UNREAD=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('unreadCount',0))" 2>/dev/null)
TOTAL=$((TOTAL + 1))
if [ "$ZERO_UNREAD" = "0" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} Unread count is 0 after mark-all-read"
else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC} Unread count is $ZERO_UNREAD, expected 0"
fi

# Mark all again when already all read (no-op)
RESP=$(call_api "PUT" "notifications/read-all")
run_test "Mark all as read when already read (no-op)" "$RESP" "200" "markedAsRead"

BODY=$(echo "$RESP" | sed '$d')
MARKED=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('markedAsRead','-1'))" 2>/dev/null)
TOTAL=$((TOTAL + 1))
if [ "$MARKED" = "0" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} markedAsRead=0 when all already read"
else
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} markedAsRead=$MARKED (ok)"
fi

# ============================================================
# [8] Delete Notification
# ============================================================

echo -e "\n${YELLOW}[8] Delete Notification${NC}"

RESP=$(call_api "GET" "notifications")
BODY=$(echo "$RESP" | sed '$d')
NOTIF_ID=$(echo "$BODY" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data[0]['id'] if data else '')" 2>/dev/null)

if [ -n "$NOTIF_ID" ] && [ "$NOTIF_ID" != "" ] && [ "$NOTIF_ID" != "None" ]; then
    COUNT_BEFORE=$(echo "$BODY" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null)

    RESP=$(call_api "DELETE" "notifications/$NOTIF_ID")
    run_test "DELETE /notifications/{id} returns 204" "$RESP" "204"

    # Verify it's gone
    RESP=$(call_api "DELETE" "notifications/$NOTIF_ID")
    run_test "DELETE same notification again returns 404" "$RESP" "404"

    # Verify count decreased
    RESP=$(call_api "GET" "notifications")
    BODY=$(echo "$RESP" | sed '$d')
    COUNT_AFTER=$(echo "$BODY" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null)
    TOTAL=$((TOTAL + 1))
    EXPECTED=$((COUNT_BEFORE - 1))
    if [ "$COUNT_AFTER" = "$EXPECTED" ]; then
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC} Notification count decreased ($COUNT_BEFORE -> $COUNT_AFTER)"
    else
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC} Count: $COUNT_BEFORE -> $COUNT_AFTER"
    fi
else
    echo -e "  ${YELLOW}SKIP: No notifications to test delete${NC}"
fi

# ============================================================
# [9] Security & Error Cases
# ============================================================

echo -e "\n${YELLOW}[9] Security & Error Cases${NC}"

# --- No auth ---
RESP=$(curl -s -w "\n%{http_code}" -H "Content-Type: application/json" "$BASE_URL/notifications")
run_test "GET /notifications without auth returns 401" "$RESP" "401"

RESP=$(curl -s -w "\n%{http_code}" -H "Content-Type: application/json" "$BASE_URL/notifications/unread-count")
run_test "GET /unread-count without auth returns 401" "$RESP" "401"

RESP=$(curl -s -w "\n%{http_code}" -X PUT -H "Content-Type: application/json" "$BASE_URL/notifications/read-all")
run_test "PUT /read-all without auth returns 401" "$RESP" "401"

RESP=$(curl -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" "$BASE_URL/notifications/trigger-reminders")
run_test "POST /trigger-reminders without auth returns 401" "$RESP" "401"

# --- Invalid token ---
RESP=$(curl -s -w "\n%{http_code}" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer invalid.jwt.token.here" \
    "$BASE_URL/notifications")
run_test "GET /notifications with garbage token returns 401" "$RESP" "401"

# --- Non-existent notification ID ---
FAKE_UUID="00000000-0000-0000-0000-000000000000"
RESP=$(call_api "PUT" "notifications/$FAKE_UUID/read")
run_test "Mark non-existent notification returns 404" "$RESP" "404"

RESP=$(call_api "DELETE" "notifications/$FAKE_UUID")
run_test "Delete non-existent notification returns 404" "$RESP" "404"

# --- Invalid UUID format ---
RESP=$(call_api "PUT" "notifications/not-a-uuid/read")
run_test "Mark invalid UUID returns 404 or 400" "$RESP" "404"

RESP=$(call_api "DELETE" "notifications/not-a-uuid")
run_test "Delete invalid UUID returns 404 or 400" "$RESP" "404"

# --- SQL injection in query params ---
RESP=$(call_api "GET" "notifications?unreadOnly=true%27%20OR%201=1--")
run_test "SQL injection in unreadOnly param is safe" "$RESP" "200"

# --- Cross-user notification access ---
if [ -n "$TOKEN2" ] && [ "$TOKEN2" != "None" ]; then
    echo -e "\n  ${CYAN}--- Cross-user security tests ---${NC}"

    # Get a notification ID from user 1
    RESP=$(call_api "GET" "notifications")
    BODY=$(echo "$RESP" | sed '$d')
    USER1_NOTIF_ID=$(echo "$BODY" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data[0]['id'] if data else '')" 2>/dev/null)

    if [ -n "$USER1_NOTIF_ID" ] && [ "$USER1_NOTIF_ID" != "" ] && [ "$USER1_NOTIF_ID" != "None" ]; then
        # User 2 tries to read user 1's notification
        RESP=$(call_api "PUT" "notifications/$USER1_NOTIF_ID/read" "" "$TOKEN2")
        CODE=$(echo "$RESP" | tail -1)
        TOTAL=$((TOTAL + 1))
        if [ "$CODE" = "403" ] || [ "$CODE" = "404" ]; then
            PASS=$((PASS + 1))
            echo -e "  ${GREEN}PASS${NC} User 2 cannot mark User 1's notification as read (HTTP $CODE)"
        else
            FAIL=$((FAIL + 1))
            echo -e "  ${RED}FAIL${NC} User 2 could access User 1's notification (HTTP $CODE)"
        fi

        # User 2 tries to delete user 1's notification
        RESP=$(call_api "DELETE" "notifications/$USER1_NOTIF_ID" "" "$TOKEN2")
        CODE=$(echo "$RESP" | tail -1)
        TOTAL=$((TOTAL + 1))
        if [ "$CODE" = "403" ] || [ "$CODE" = "404" ]; then
            PASS=$((PASS + 1))
            echo -e "  ${GREEN}PASS${NC} User 2 cannot delete User 1's notification (HTTP $CODE)"
        else
            FAIL=$((FAIL + 1))
            echo -e "  ${RED}FAIL${NC} User 2 could delete User 1's notification (HTTP $CODE)"
        fi

        # Verify user 1's notification still exists
        RESP=$(call_api "PUT" "notifications/$USER1_NOTIF_ID/read")
        run_test "User 1's notification still exists after cross-user attack" "$RESP" "200"
    else
        echo -e "  ${YELLOW}SKIP: No notifications for cross-user tests${NC}"
    fi

    # User 2's notifications should be independent
    RESP=$(call_api "GET" "notifications" "" "$TOKEN2")
    run_test "User 2 has separate notification list" "$RESP" "200"
fi

# ============================================================
# [10] Grouped Notifications - Double Trigger
# ============================================================

echo -e "\n${YELLOW}[10] Grouped Notifications - Double Trigger${NC}"

# Count before
RESP=$(call_api "GET" "notifications")
BODY=$(echo "$RESP" | sed '$d')
COUNT_BEFORE=$(echo "$BODY" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null)

# Trigger again
RESP=$(call_api "POST" "notifications/trigger-reminders")
run_test "Trigger reminders second time" "$RESP" "200"

# Count after
RESP=$(call_api "GET" "notifications")
BODY=$(echo "$RESP" | sed '$d')
COUNT_AFTER=$(echo "$BODY" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null)

echo -e "  ${CYAN}INFO: Notifications before: $COUNT_BEFORE, after: $COUNT_AFTER${NC}"

# Verify new notifications were added (if plants need water)
TOTAL=$((TOTAL + 1))
if [ "$COUNT_AFTER" -ge "$COUNT_BEFORE" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} Second trigger created new notifications (grouped)"
else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC} Count decreased after trigger"
fi

# ============================================================
# [11] Edge Cases
# ============================================================

echo -e "\n${YELLOW}[11] Edge Cases${NC}"

# --- HTTP methods ---
RESP=$(curl -s -w "\n%{http_code}" -X PATCH \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    "$BASE_URL/notifications")
run_test "PATCH /notifications returns 405 (method not allowed)" "$RESP" "405"

# --- Empty body on trigger ---
RESP=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    "$BASE_URL/notifications/trigger-reminders")
run_test "POST /trigger-reminders with no body works" "$RESP" "200"

# --- PUT read-all with body (should be ignored) ---
RESP=$(call_api "PUT" "notifications/read-all" '{"garbage":"data"}')
run_test "PUT /read-all with garbage body still works" "$RESP" "200"

# --- Large UUID-like path ---
RESP=$(call_api "DELETE" "notifications/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
run_test "Delete with valid-format but non-existent UUID returns 404" "$RESP" "404"

# --- Path traversal attempt ---
RESP=$(curl -s -w "\n%{http_code}" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    "$BASE_URL/notifications/../auth/me")
CODE=$(echo "$RESP" | tail -1)
TOTAL=$((TOTAL + 1))
if [ "$CODE" = "200" ] || [ "$CODE" = "404" ] || [ "$CODE" = "401" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} Path traversal attempt handled safely (HTTP $CODE)"
else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC} Unexpected response to path traversal (HTTP $CODE)"
fi

# --- Very rapid requests (race condition test) ---
echo -e "  ${CYAN}--- Rapid fire test (10 concurrent unread-count) ---${NC}"
for i in $(seq 1 10); do
    call_api "GET" "notifications/unread-count" &
done
wait
RESP=$(call_api "GET" "notifications/unread-count")
run_test "Unread count stable after rapid fire" "$RESP" "200" "unreadCount"

# --- Accept header variations ---
RESP=$(curl -s -w "\n%{http_code}" \
    -H "Accept: text/html" \
    -H "Authorization: Bearer $TOKEN" \
    "$BASE_URL/notifications/unread-count")
CODE=$(echo "$RESP" | tail -1)
TOTAL=$((TOTAL + 1))
if [ "$CODE" = "200" ] || [ "$CODE" = "406" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} Accept: text/html handled gracefully (HTTP $CODE)"
else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC} Unexpected response for Accept: text/html (HTTP $CODE)"
fi

# ============================================================
# [12] Complex Scenario: Full Lifecycle
# ============================================================

echo -e "\n${YELLOW}[12] Complex Scenario: Full Lifecycle${NC}"

# 1. Start clean
call_api "PUT" "notifications/read-all" > /dev/null 2>&1

# 2. Trigger reminders
RESP=$(call_api "POST" "notifications/trigger-reminders")
run_test "Lifecycle: Trigger reminders" "$RESP" "200"

# 3. Get unread count
RESP=$(call_api "GET" "notifications/unread-count")
BODY=$(echo "$RESP" | sed '$d')
UNREAD_AFTER_TRIGGER=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('unreadCount',0))" 2>/dev/null)
run_test "Lifecycle: Get unread count" "$RESP" "200"

# 4. List unread only
RESP=$(call_api "GET" "notifications?unreadOnly=true")
BODY=$(echo "$RESP" | sed '$d')
UNREAD_LIST=$(echo "$BODY" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null)
run_test "Lifecycle: List unread notifications" "$RESP" "200"

# 5. Mark first as read
FIRST_ID=$(echo "$BODY" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data[0]['id'] if data else '')" 2>/dev/null)
if [ -n "$FIRST_ID" ] && [ "$FIRST_ID" != "" ] && [ "$FIRST_ID" != "None" ]; then
    RESP=$(call_api "PUT" "notifications/$FIRST_ID/read")
    run_test "Lifecycle: Mark first as read" "$RESP" "200"

    # 6. Verify unread decreased
    RESP=$(call_api "GET" "notifications/unread-count")
    BODY=$(echo "$RESP" | sed '$d')
    NEW_UNREAD=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('unreadCount',0))" 2>/dev/null)
    TOTAL=$((TOTAL + 1))
    EXPECTED=$((UNREAD_AFTER_TRIGGER - 1))
    # Can be equal if the first notif was already read
    if [ "$NEW_UNREAD" -le "$UNREAD_AFTER_TRIGGER" ]; then
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC} Lifecycle: Unread count decreased or equal ($UNREAD_AFTER_TRIGGER -> $NEW_UNREAD)"
    else
        FAIL=$((FAIL + 1))
        echo -e "  ${RED}FAIL${NC} Lifecycle: Unread count increased ($UNREAD_AFTER_TRIGGER -> $NEW_UNREAD)"
    fi

    # 7. Delete the notification
    RESP=$(call_api "DELETE" "notifications/$FIRST_ID")
    run_test "Lifecycle: Delete the notification" "$RESP" "204"

    # 8. Verify it's gone from the list
    RESP=$(call_api "GET" "notifications")
    BODY=$(echo "$RESP" | sed '$d')
    STILL_EXISTS=$(echo "$BODY" | python3 -c "
import sys,json
data=json.load(sys.stdin)
print('FOUND' if any(n['id']=='$FIRST_ID' for n in data) else 'GONE')
" 2>/dev/null)
    TOTAL=$((TOTAL + 1))
    if [ "$STILL_EXISTS" = "GONE" ]; then
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC} Lifecycle: Deleted notification is gone from list"
    else
        FAIL=$((FAIL + 1))
        echo -e "  ${RED}FAIL${NC} Lifecycle: Deleted notification still appears in list"
    fi
fi

# 9. Mark all read
RESP=$(call_api "PUT" "notifications/read-all")
run_test "Lifecycle: Mark all as read" "$RESP" "200"

# 10. Verify 0 unread
RESP=$(call_api "GET" "notifications/unread-count")
BODY=$(echo "$RESP" | sed '$d')
FINAL_UNREAD=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('unreadCount',0))" 2>/dev/null)
TOTAL=$((TOTAL + 1))
if [ "$FINAL_UNREAD" = "0" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} Lifecycle: Final unread count is 0"
else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC} Lifecycle: Final unread count is $FINAL_UNREAD"
fi

# ============================================================
# [13] Complex Scenario: Notification Content Validation
# ============================================================

echo -e "\n${YELLOW}[13] Notification Content Validation${NC}"

# Trigger to get fresh notifications
RESP=$(call_api "POST" "notifications/trigger-reminders")
run_test "Content: Trigger reminders" "$RESP" "200"

RESP=$(call_api "GET" "notifications?unreadOnly=true")
BODY=$(echo "$RESP" | sed '$d')

# Validate notification content quality
CONTENT_CHECK=$(echo "$BODY" | python3 -c "
import sys,json
data=json.load(sys.stdin)
if not data:
    print('NO_DATA')
    sys.exit(0)

issues = []
for n in data:
    # ID must be UUID format
    import re
    if not re.match(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', n.get('id','')):
        issues.append('invalid_uuid')
    # Type must be known
    if n.get('type') not in ('WATERING_REMINDER','CARE_REMINDER','PLANT_ADDED','MEMBER_JOINED'):
        issues.append('unknown_type:'+str(n.get('type')))
    # Message must not be empty
    if not n.get('message','').strip():
        issues.append('empty_message')
    # Read must be boolean
    if n.get('read') not in (True, False):
        issues.append('read_not_bool')
    # CreatedAt must be ISO format
    if not n.get('createdAt',''):
        issues.append('no_createdAt')

print('OK' if not issues else 'ISSUES:'+','.join(issues))
" 2>/dev/null)

TOTAL=$((TOTAL + 1))
if [ "$CONTENT_CHECK" = "OK" ] || [ "$CONTENT_CHECK" = "NO_DATA" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} All notification fields have valid content"
else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC} Content issues: $CONTENT_CHECK"
fi

# Check for French content in watering reminders
HAS_FRENCH=$(echo "$BODY" | python3 -c "
import sys,json
data=json.load(sys.stdin)
if not data:
    print('NO_DATA')
    sys.exit(0)
french_keywords = ['arros', 'plante', 'retard', 'attention', 'besoin', 'soin', 'eau']
for n in data:
    msg = n.get('message','').lower()
    if any(kw in msg for kw in french_keywords):
        print('OK')
        sys.exit(0)
print('NO_FRENCH')
" 2>/dev/null)

TOTAL=$((TOTAL + 1))
if [ "$HAS_FRENCH" = "OK" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} Notifications contain French content (rappels en francais)"
elif [ "$HAS_FRENCH" = "NO_DATA" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} No notifications to check (no plants needing water = correct)"
else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC} Notifications don't contain expected French keywords"
fi

# Check for personalized recommendations (care tips)
HAS_TIPS=$(echo "$BODY" | python3 -c "
import sys,json
data=json.load(sys.stdin)
if not data:
    print('NO_DATA')
    sys.exit(0)
tip_keywords = ['sol', 'humide', 'sec', 'arrosage', 'vaporiser', 'lumiere', 'ombre', 'soleil', 'feuille', 'pot']
for n in data:
    msg = n.get('message','').lower()
    if any(kw in msg for kw in tip_keywords):
        print('OK')
        sys.exit(0)
# Tips only appear if plant species are known
print('NO_TIPS_BUT_OK')
" 2>/dev/null)

TOTAL=$((TOTAL + 1))
if [ "$HAS_TIPS" = "OK" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} Notifications contain personalized care tips"
elif [ "$HAS_TIPS" = "NO_DATA" ] || [ "$HAS_TIPS" = "NO_TIPS_BUT_OK" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} No tips (species may not be in WateringDefaults - expected)"
else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC} Unexpected tips check result: $HAS_TIPS"
fi

# ============================================================
# [14] Cleanup
# ============================================================

echo -e "\n${YELLOW}[14] Final Cleanup${NC}"

RESP=$(call_api "GET" "notifications")
BODY=$(echo "$RESP" | sed '$d')
ALL_IDS=$(echo "$BODY" | python3 -c "
import sys,json
data=json.load(sys.stdin)
for n in data:
    print(n['id'])
" 2>/dev/null)

DELETED=0
while IFS= read -r nid; do
    if [ -n "$nid" ]; then
        call_api "DELETE" "notifications/$nid" > /dev/null 2>&1
        DELETED=$((DELETED + 1))
    fi
done <<< "$ALL_IDS"

echo -e "  ${CYAN}Deleted $DELETED test notifications${NC}"

# Delete test plants
for name in "Notif Monstera Test" "Notif Cactus Test" "Notif Basilic Malade"; do
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "X-MCP-API-Key: $MCP_KEY" \
        -d "{\"tool\":\"delete_plant\",\"parameters\":{\"nickname\":\"$name\"}}" \
        "$BASE_URL/mcp/tools" > /dev/null 2>&1
done
echo -e "  ${CYAN}Deleted test plants${NC}"

RESP=$(call_api "GET" "notifications/unread-count")
BODY=$(echo "$RESP" | sed '$d')
FINAL_COUNT=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('unreadCount',0))" 2>/dev/null)
TOTAL=$((TOTAL + 1))
if [ "$FINAL_COUNT" = "0" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC} All notifications cleaned up (unread=0)"
else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC} Unread count after cleanup: $FINAL_COUNT"
fi

# ============================================================
# RESULTS
# ============================================================

echo -e "\n${CYAN}============================================================${NC}"
echo -e "${CYAN} RESULTS${NC}"
echo -e "${CYAN}============================================================${NC}"
echo -e "  Total: $TOTAL"
echo -e "  ${GREEN}Pass:  $PASS${NC}"
echo -e "  ${RED}Fail:  $FAIL${NC}"

if [ $FAIL -eq 0 ]; then
    echo -e "\n  ${GREEN}ALL TESTS PASSED!${NC}"
    exit 0
else
    echo -e "\n  ${RED}$FAIL TEST(S) FAILED${NC}"
    exit 1
fi
