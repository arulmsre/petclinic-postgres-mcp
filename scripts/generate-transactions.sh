#!/bin/bash
# Generates realistic end-to-end transactions against the PetClinic API Gateway.
# Flow: create owner → add pet → book visit → read back data

BASE_URL="${BASE_URL:-http://localhost:8080}"
ITERATIONS="${ITERATIONS:-5}"
DELAY="${DELAY:-1}"  # seconds between iterations

FIRST_NAMES=("Alice" "Bob" "Carol" "David" "Emma" "Frank" "Grace" "Henry" "Iris" "Jack")
LAST_NAMES=("Smith" "Johnson" "Williams" "Brown" "Jones" "Garcia" "Miller" "Davis" "Wilson" "Moore")
CITIES=("New York" "Los Angeles" "Chicago" "Houston" "Phoenix" "Philadelphia" "San Antonio" "San Diego")
PET_NAMES=("Buddy" "Max" "Bella" "Charlie" "Luna" "Cooper" "Lucy" "Milo" "Daisy" "Rocky")
VISIT_DESCS=("Annual checkup" "Vaccination" "Dental cleaning" "Skin rash" "Limping" "Eye infection" "Routine exam" "Weight check")

# Pet type IDs (1=cat 2=dog 3=lizard 4=snake 5=bird 6=hamster — standard PetClinic seed data)
PET_TYPE_IDS=(1 2 5 6)

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓ $1${NC}"; }
fail() { echo -e "${RED}✗ $1${NC}"; }
info() { echo -e "${YELLOW}→ $1${NC}"; }

check_gateway() {
  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/customer/owners")
  if [ "$status" != "200" ]; then
    echo -e "${RED}API Gateway not reachable at $BASE_URL (HTTP $status). Is the stack running?${NC}"
    exit 1
  fi
}

random_element() {
  local arr=("$@")
  echo "${arr[$((RANDOM % ${#arr[@]}))]}"
}

random_date() {
  # Random visit date within the next 30 days
  local offset=$((RANDOM % 30 + 1))
  date -v "+${offset}d" "+%Y-%m-%d" 2>/dev/null || date -d "+${offset} days" "+%Y-%m-%d"
}

run_transaction() {
  local i=$1
  local first last city phone address pet_name pet_type_id visit_desc

  first=$(random_element "${FIRST_NAMES[@]}")
  last=$(random_element "${LAST_NAMES[@]}")
  city=$(random_element "${CITIES[@]}")
  phone="$(( RANDOM % 9000000000 + 1000000000 ))"
  address="$((RANDOM % 999 + 1)) Main St"
  pet_name=$(random_element "${PET_NAMES[@]}")
  pet_type_id=$(random_element "${PET_TYPE_IDS[@]}")
  visit_desc=$(random_element "${VISIT_DESCS[@]}")

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  info "Transaction $i: $first $last"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # 1. Create owner
  local owner_response owner_id
  owner_response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/customer/owners" \
    -H "Content-Type: application/json" \
    -d "{
      \"firstName\": \"$first\",
      \"lastName\": \"$last\",
      \"address\": \"$address\",
      \"city\": \"$city\",
      \"telephone\": \"$phone\"
    }")
  local owner_status owner_body
  owner_status=$(echo "$owner_response" | tail -1)
  owner_body=$(echo "$owner_response" | head -1)

  if [ "$owner_status" != "201" ] && [ "$owner_status" != "200" ]; then
    fail "Create owner failed (HTTP $owner_status): $owner_body"
    return 1
  fi
  owner_id=$(echo "$owner_body" | grep -o '"id":[0-9]*' | head -1 | grep -o '[0-9]*')
  pass "Created owner '$first $last' → id=$owner_id"

  # 2. Add pet
  local pet_response pet_id birth_date
  birth_date="$(( RANDOM % 10 + 2014 ))-$(printf '%02d' $(( RANDOM % 12 + 1 )))-$(printf '%02d' $(( RANDOM % 27 + 1 )))"

  pet_response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/customer/owners/$owner_id/pets" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"$pet_name\",
      \"birthDate\": \"$birth_date\",
      \"typeId\": $pet_type_id
    }")
  local pet_status pet_body
  pet_status=$(echo "$pet_response" | tail -1)
  pet_body=$(echo "$pet_response" | head -1)

  if [ "$pet_status" != "201" ] && [ "$pet_status" != "200" ]; then
    fail "Add pet failed (HTTP $pet_status): $pet_body"
    return 1
  fi
  pet_id=$(echo "$pet_body" | grep -o '"id":[0-9]*' | head -1 | grep -o '[0-9]*')
  pass "Added pet '$pet_name' (typeId=$pet_type_id) → id=$pet_id"

  # 3. Book a visit
  local visit_response visit_status visit_body visit_date
  visit_date=$(random_date)

  visit_response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/visit/owners/$owner_id/pets/$pet_id/visits" \
    -H "Content-Type: application/json" \
    -d "{
      \"date\": \"$visit_date\",
      \"description\": \"$visit_desc\"
    }")
  visit_status=$(echo "$visit_response" | tail -1)
  visit_body=$(echo "$visit_response" | head -1)

  if [ "$visit_status" != "201" ] && [ "$visit_status" != "200" ]; then
    fail "Book visit failed (HTTP $visit_status): $visit_body"
    return 1
  fi
  pass "Booked visit on $visit_date: '$visit_desc'"

  # 4. Read back owner to verify
  local verify_status
  verify_status=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/customer/owners/$owner_id")
  if [ "$verify_status" = "200" ]; then
    pass "Verified owner record readable (HTTP 200)"
  else
    fail "Owner read-back failed (HTTP $verify_status)"
  fi

  # 5. List vets (read-only load)
  local vets_status
  vets_status=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/vet/vets")
  [ "$vets_status" = "200" ] && pass "Vets list OK" || fail "Vets list failed (HTTP $vets_status)"

  # 6. Delete owner (cleanup)
  local delete_status
  delete_status=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$BASE_URL/api/customer/owners/$owner_id")
  if [ "$delete_status" = "204" ]; then
    pass "Deleted owner id=$owner_id (cleanup)"
  else
    fail "Delete owner failed (HTTP $delete_status)"
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
echo ""
echo "PetClinic Transaction Generator"
echo "Target : $BASE_URL"
echo "Iterations: $ITERATIONS  |  Delay: ${DELAY}s"
echo ""

check_gateway

SUCCESS=0
FAIL=0
TOTAL=0

trap 'echo ""; echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; echo -e "Stopped — ${GREEN}$SUCCESS passed${NC}, ${RED}$FAIL failed${NC} (${TOTAL} total)"; echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; exit 0' INT TERM

if [ "${LOOP:-false}" = "true" ]; then
  i=1
  while true; do
    if run_transaction "$i"; then (( SUCCESS++ )); else (( FAIL++ )); fi
    (( TOTAL++ ))
    (( i++ ))
    sleep "$DELAY"
  done
else
  for i in $(seq 1 "$ITERATIONS"); do
    if run_transaction "$i"; then (( SUCCESS++ )); else (( FAIL++ )); fi
    (( TOTAL++ ))
    [ "$i" -lt "$ITERATIONS" ] && sleep "$DELAY"
  done
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "Done — ${GREEN}$SUCCESS passed${NC}, ${RED}$FAIL failed${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi
