#!/bin/bash
# lib/functions.sh – all functions for Café Loyalty Points
DATA="data/customers.csv"

LOG="logs/activity.log"

# write one line to the activity log
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" >> "$LOG"
}

# check the data file / folder exists before using it
check_data() {
    if [ ! -e "$DATA" ]; then
        echo "Data not found: $DATA"
        return 1
    fi
}

show_help() {
    echo "Usage: ./main.sh            -> open the menu"
    echo "       ./main.sh --help     -> show this help"
    echo "       ./main.sh --backup   -> backup data/ now"
    echo "       ./main.sh --cron     -> run the scheduled (crontab) task"
}

view_data() {
    check_data || return
    if [ -d "$DATA" ]; then ls -l "$DATA"; else cat -n "$DATA" | more; fi
}

do_backup() {
    f="backups/data_$(date +%Y%m%d_%H%M%S).tar.gz"
    tar -czf "$f" data/
    echo "Backup saved: $f ($(du -h "$f" | cut -f1))"
    log "backup created $f"
}

view_log() {
    if [ -f "$LOG" ]; then tail -n 15 "$LOG"; else echo "No activity yet."; fi
}

# ------------------------------------------------------------
# FEATURE 1: Add points for a purchase (1 point per ₹10)
# Commands you can use: awk, bc, sed -i, sort -t, -nr, date -d
# ------------------------------------------------------------
feature_1() {
    echo "== Add points for a purchase (1 point per ₹10) =="
    check_data | return
    read -p "Enter customer phone: " phone
    if [[ ! "$phone" =~ ^[0-9]{10}$ ]]; then
        echo "Invalid phone number!"
        return
    fi

    if ! grep -q "^$phone," "$DATA"; then
        echo "Customer not found! Register first."
        return
    fi

    read -p "Enter purchase amount (Rs): " amount
    if [[ ! "$amount" =~ ^[0-9]+$ ]] || [ "$amount" -lt 10 ]; then
        echo "Enter a valid amount of at least Rs 10."
        return
    fi

    earned=$((amount / 10))
    tmp="${DATA}.tmp"

    awk -F',' -v OFS=',' -v p="$phone" \
        -v e="$earned" -v d="$(date +%F)" '
        NR==1 { print; next }
        $1==p { $3=$3+e; $4=d; found=1 }
        { print }
        END { if (!found) exit 2 }
    ' "$DATA" > "$tmp"

    if [ $? -ne 0 ]; then
        rm -f "$tmp"
        echo "Customer update failed!"
        return
    fi

    mv "$tmp" "$DATA"
    echo "Purchase recorded successfully!"
    echo "Points earned: $earned"
    log "Added $earned points for customer $phone"
    # ---- example to start from (remove the # and change it) ----
    # read -p "Enter phone: " v1
    # read -p "Enter name: " v2
    # # ...ask for every column: phone, name, points, last_visit
    # if [ -z "$v1" ]; then echo "Value cannot be empty"; return; fi    # echo "$v1,$v2" >> "$DATA"        # add all 4 values in the same order as the header
    # echo "Saved!"
    log "feature_1 used"
}

# ------------------------------------------------------------
# FEATURE 2: Redeem points for a reward
# Commands you can use: awk, bc, sed -i, sort -t, -nr, date -d
# ------------------------------------------------------------
feature_2() {
    echo "== Redeem points for a reward =="
  
    check_data || return

    read -p "Enter customer phone: " phone

    if [[ ! "$phone" =~ ^[0-9]{10}$ ]]; then
        echo "Invalid phone number!"
        return
    fi

    if ! grep -q "^$phone," "$DATA"; then
        echo "Customer not found!"
        return
    fi

    read -p "Enter reward name: " reward

    if [ -z "$reward" ] || [[ "$reward" == *","* ]]; then
        echo "Invalid reward name!"
        return
    fi

    read -p "Enter points to redeem: " cost

    if [[ ! "$cost" =~ ^[0-9]+$ ]] || [ "$cost" -le 0 ]; then
        echo "Invalid points!"
        return
    fi

    current=$(awk -F',' -v p="$phone" '$1==p {print $3}' "$DATA")

    if [ "$current" -lt "$cost" ]; then
        echo "Insufficient points!"
        echo "Available points: $current"
        return
    fi

    tmp="${DATA}.tmp"

    awk -F',' -v OFS=',' -v p="$phone" -v c="$cost" '
        NR==1 {print; next}
        $1==p {$3=$3-c}
        {print}
    ' "$DATA" > "$tmp"

    mv "$tmp" "$DATA"

    echo "Reward redeemed successfully!"
    echo "Reward: $reward"
    echo "Points deducted: $cost"
    echo "Remaining points: $((current-cost))"

    log "Redeemed $reward for $phone"
    # ---- example to start from (remove the # and change it) ----
    # read -p "Enter phone to change: " key
    # if ! grep -q "^$key," "$DATA"; then echo "Not found"; return; fi
    # # change the last column of that row (example)
    # sed -i "/^$key,/s/[^,]*$/NEW_VALUE/" "$DATA"
    # echo "Updated:"; grep "^$key," "$DATA"
    log "feature_2 used"
}

# ------------------------------------------------------------
# FEATURE 3: Show the top 5 customers
# Commands you can use: awk, bc, sed -i, sort -t, -nr, date -d
# ------------------------------------------------------------
feature_3() {
    echo "== Show the top 5 customers =="
    check_data || return

    echo "===== TOP 5 CUSTOMERS ====="

    printf "%-15s %-15s %-10s %-12s\n" \
        "Phone" "Name" "Points" "Last Visit"

    tail -n +2 "$DATA" |
        sort -t',' -k3,3nr |
        head -5 |
        awk -F',' '{
            printf "%-15s %-15s %-10s %-12s\n",
            $1, $2, $3, $4
        }'

    log "Displayed top 5 customers"
    # ---- example to start from (remove the # and change it) ----
    # # example: count rows per value of column 2
    # tail -n +2 "$DATA" | cut -d',' -f2 | sort | uniq -c | sort -nr | head -5
    # # example: top 5 rows by column 3 (points)
    # tail -n +2 "$DATA" | sort -t',' -k3 -nr | head -5
    log "feature_3 used"
}

# ------------------------------------------------------------
# FEATURE 4: List customers not visited for 30 days (date -d)
# Commands you can use: awk, bc, sed -i, sort -t, -nr, date -d
# ------------------------------------------------------------
feature_4() {
    echo "== List customers not visited for 30 days (date -d) =="
        check_data || return

    echo "===== CUSTOMERS NOT VISITED FOR 30 DAYS ====="

    today=$(date +%s)
    found=0

    printf "%-15s %-15s %-10s %-12s\n" \
        "Phone" "Name" "Points" "Last Visit"

    while IFS=',' read -r phone name points last_visit
    do
        [ "$phone" = "phone" ] && continue

        visit_date=$(date -d "$last_visit" +%s 2>/dev/null)

        if [ -n "$visit_date" ]; then
            days=$(( (today - visit_date) / 86400 ))

            if [ "$days" -ge 30 ]; then
                printf "%-15s %-15s %-10s %-12s\n" \
                    "$phone" "$name" "$points" "$last_visit"
                found=1
            fi
        fi
    done < "$DATA"

    if [ "$found" -eq 0 ]; then
        echo "No inactive customers found."
    fi
    # ---- example to start from (remove the # and change it) ----
    # read -p "Search for: " word
    # grep -i "$word" "$DATA" || echo "Nothing found"
    # # or show selected columns: awk -F',' '{ print $1, $2 }' "$DATA"
    log "feature_4 used"
}

# ------------------------------------------------------------
# FEATURE 5: Register a new customer with a phone check
# Commands you can use: awk, bc, sed -i, sort -t, -nr, date -d
# ------------------------------------------------------------
feature_5() {
    echo "== Register a new customer with a phone check =="
        check_data || return

    echo "===== REGISTER NEW CUSTOMER ====="

    read -p "Enter 10-digit phone number: " phone

    if [[ ! "$phone" =~ ^[0-9]{10}$ ]]; then
        echo "Invalid phone number!"
        return
    fi

    if grep -q "^$phone," "$DATA"; then
        echo "Customer already registered!"
        return
    fi

    read -p "Enter customer name: " name

    if [ -z "$name" ] || [[ "$name" == *","* ]]; then
        echo "Invalid customer name!"
        return
    fi

    name=$(echo "$name" | tr '[:lower:]' '[:upper:]')

    today=$(date +%F)

    echo "$phone,$name,0,$today" >> "$DATA"

    echo "Customer registered successfully!"
    echo "Phone: $phone"
    echo "Name: $name"
    echo "Points: 0"
    # ---- example to start from (remove the # and change it) ----
    # read -p "Enter phone: " v1
    # read -p "Enter name: " v2
    # # ...ask for every column: phone, name, points, last_visit
    # if [ -z "$v1" ]; then echo "Value cannot be empty"; return; fi
    # echo "$v1,$v2" >> "$DATA"        # add all 4 values in the same order as the header
    # echo "Saved!"
    log "feature_5 used"
}

# ------------------------------------------------------------
# cron task 
cron_task() {
    check_data || return

    mkdir -p reports

    today=$(date +%s)

    {
        echo "===== CUSTOMERS INACTIVE FOR 30 DAYS ====="
        echo "Generated on: $(date '+%Y-%m-%d %H:%M:%S')"
        echo
        printf "%-15s %-15s %-10s %-12s\n" \
            "Phone" "Name" "Points" "Last Visit"

        while IFS=',' read -r phone name points last_visit
        do
            [ "$phone" = "phone" ] && continue

            visit_date=$(date -d "$last_visit" +%s 2>/dev/null)

            if [ -n "$visit_date" ]; then
                days=$(( (today - visit_date) / 86400 ))

                if [ "$days" -ge 30 ]; then
                    printf "%-15s %-15s %-10s %-12s\n" \
                        "$phone" "$name" "$points" "$last_visit"
                fi
            fi
        done < "$DATA"
    } > reports/winback.txt

    echo "Win-back report generated: reports/winback.txt"
    log "cron task ran"
}
