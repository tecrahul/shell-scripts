#!/bin/bash

# Description:
# This script is designed to restore MySQL databases from backups stored either locally or on an AWS S3 bucket.
# It supports manual selection of the backup frequency (daily, weekly, monthly) and the specific backup date.
# If a local backup is not found, the script will attempt to restore from the corresponding S3 backup.

# Usage:
# To run the script in automatic mode (restoring the latest available backup):
# ./mysql_restore_script.sh <database_name>
#
# To run the script in manual mode, allowing for selection of the backup frequency and date:
# ./mysql_restore_script.sh --manual <database_name>
#
# Prerequisites:
# - AWS CLI must be installed and configured with access to the S3 bucket containing the backups.
# - The user must have MySQL or MariaDB client installed for database restoration.
# - Proper permissions are required to access the backup files and restore databases.


# Configuration
DB_USER="root"
DB_PASSWORD="password"
BACKUP_PATH="/path/to/backup"
S3_BUCKET_NAME="s3-bucket-name"
LOG_FILE="/path/to/restore.log"

# Initialize variables
MANUAL_MODE=0
DB_NAMES=()

# Parse command-line arguments
for arg in "$@"; do
    if [ "$arg" = "--manual" ]; then
        MANUAL_MODE=1
    else
        DB_NAMES+=("$arg")
    fi
done


# Helper function for confirmation
confirm_restoration() {
    read -p "Are you sure you want to restore from this backup? [y/N]: " confirmation
    if [[ ! $confirmation =~ ^[Yy]$ ]]; then
        echo "Restoration aborted by user."
        exit 1
    fi
}

# Function to restore database from file
restore_from_file() {
    DB_NAME=$1
    BACKUP_FILE=$2

    echo "Preparing to restore database $DB_NAME from local backup: $BACKUP_FILE"
    confirm_restoration

    echo "Restoring database $DB_NAME from $BACKUP_FILE"
    gunzip < "$BACKUP_FILE" | mysql -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME"

    if [ $? -eq 0 ]; then
        echo "Restoration of $DB_NAME was successful." >> $LOG_FILE
    else
        echo "Restoration of $DB_NAME failed." >> $LOG_FILE
    fi
}

# Function to download and restore from S3 if local backup is not available
restore_from_s3() {
    DB_NAME=$1
    BACKUP_DATE=$2
    FREQUENCY=$3

    BACKUP_FILE_S3="s3://${S3_BUCKET_NAME}/${FREQUENCY}/${DB_NAME}_${FREQUENCY}_${BACKUP_DATE}.sql.gz"
    BACKUP_FILE_LOCAL="${BACKUP_PATH}/${DB_NAME}_${FREQUENCY}_${BACKUP_DATE}.sql.gz"

    echo "Downloading backup file for $DB_NAME from S3 to local: $BACKUP_FILE_S3"
    aws s3 cp "$BACKUP_FILE_S3" "$BACKUP_FILE_LOCAL" && restore_from_file "$DB_NAME" "$BACKUP_FILE_LOCAL"
}

# Function for manual mode
manual_restore() {
    DB_NAME=$1
    echo "Checking available backups for $DB_NAME..."

    # Define the backup frequencies
    declare -a FREQUENCIES=("daily" "weekly" "monthly")
    declare -a AVAILABLE_FREQUENCIES=()

    # Check for actual backup files in each frequency
    for FREQUENCY in "${FREQUENCIES[@]}"; do
        if aws s3 ls "s3://${S3_BUCKET_NAME}/${FREQUENCY}/" | grep -q "${DB_NAME}"; then
            AVAILABLE_FREQUENCIES+=("${FREQUENCY}")
        fi
    done

    if [ ${#AVAILABLE_FREQUENCIES[@]} -eq 0 ]; then
        echo "No backups available for $DB_NAME."
        return
    fi

    echo "Available backups for $DB_NAME:"
    printf '%s\n' "${AVAILABLE_FREQUENCIES[@]}"

    read -p "Enter the frequency (daily, weekly, monthly) you wish to restore from: " FREQUENCY

    # Check if selected frequency is valid and available
    if [[ " ${AVAILABLE_FREQUENCIES[*]} " =~ " ${FREQUENCY} " ]]; then
        echo "Available dates for $FREQUENCY backups of $DB_NAME:"
        aws s3 ls "s3://${S3_BUCKET_NAME}/${FREQUENCY}/" | grep "${DB_NAME}" | awk '{print $4}' | sed 's/.*_\(.*\)\.sql\.gz/\1/' | sort | uniq
        read -p "Enter the date of the backup you wish to restore (format YYYY-MM-DD): " BACKUP_DATE

        # Proceed with restoration...
        BACKUP_FILE="${BACKUP_PATH}/${DB_NAME}_${FREQUENCY}_${BACKUP_DATE}.sql.gz"
        if [ -f "$BACKUP_FILE" ]; then
            echo "File found locally: ${BACKUP_FILE}"
            restore_from_file "$DB_NAME" "$BACKUP_FILE"
        else
            echo "File not found locally. Attempting to restore from S3: ${BACKUP_FILE}"
            restore_from_s3 "$DB_NAME" "$BACKUP_DATE" "$FREQUENCY"
        fi
    else
        echo "Invalid frequency selected or no backups available for the selected frequency. Please try again."
    fi
}

# Main execution logic
if [ $MANUAL_MODE -eq 1 ]; then
    for DB in "${DB_NAMES[@]}"; do
        manual_restore "$DB"
    done
else
    for DB in "${DB_NAMES[@]}"; do
        # Assuming daily backups by default, modify as necessary
        BACKUP_DATE=$(date +"%Y-%m-%d")
        FREQUENCY="daily" # Default to daily, modify based on your needs
        BACKUP_FILE="${BACKUP_PATH}/${DB}_${FREQUENCY}_${BACKUP_DATE}.sql.gz"
        if [ -f "$BACKUP_FILE" ]; then
            restore_from_file "$DB" "$BACKUP_FILE"
        else
            restore_from_s3 "$DB" "$BACKUP_DATE" "$FREQUENCY"
        fi
    done
fi

echo "Restoration process completed. Check $LOG_FILE for details."