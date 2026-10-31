# L115 – Café Loyalty Points

**Student:** KHYAT MANDAPWALA | **Roll:** E19 | **Division:** H | **Enrollment:** 24004501210178

## Problem
Build a loyalty-points system for a café with points, rewards and inactive customers.

## Who will use it
Small café owners.

## Folder structure
- main.sh – menu (run with ./main.sh)
- lib/functions.sh – all functions
- data/ – data files
- reports/ – reports created by the script
- backups/ – tar.gz backups
- logs/ – activity.log and cron.log

## Features
1. Add points for a purchase (1 point per ₹10)
2. Redeem points for a reward
3. Show the top 5 customers
4. List customers not visited for 30 days (date -d)
5. Register a new customer with a phone check

## How to run
    cd ~/linux_project/cafepoints
    ./main.sh
    ./main.sh --help

## Crontab task
Every Monday at 9 AM, write inactive customers to reports/winback.txt

    0 9 * * 1 /bin/bash $HOME/linux_project/cafepoints/main.sh --cron >> $HOME/linux_project/cafepoints/logs/cron.log 2>&1

## Commands used
awk, bc, sed -i, sort -t, -nr, date -d

## What I learned
(write 3-5 lines here)
1. I learned how to create menu-driven shell scripts using functions, loops and case statements.
2. I learned to manage CSV data using grep, awk, sort and other Linux commands.
3. I learned how to validate customer details and update loyalty points.
4. I learned to create backups using tar.gz and maintain activity logs.
5. I learned to schedule automated tasks using crontab.
