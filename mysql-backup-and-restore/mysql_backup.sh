#!/bin/bash

# Script Description:
# This script performs backups for multiple MySQL databases, supporting daily, weekly, and monthly frequencies.
# Backups are stored locally and uploaded to an AWS S3 bucket. The script also manages retention of these backups.
#
# Usage:
# Example: bash mysql_backup_script.sh my_database1 my_database2
#
# Configurations (edit these variables as needed):
DB_USER="root"
DB_PASSWORD="password"
LOCAL_BACKUP_PATH="/path/to/backup"
S3_BUCKET_NAME="s3-bucket-name"
LOG_FILE="/path/to/backup.log"

# Retention policy in days
LOCAL_DAILY_RETENTION=7
LOCAL_WEEKLY_RETENTION=30
LOCAL_MONTHLY_RETENTION=90
S3_DAILY_RETENTION=30
S3_WEEKLY_RETENTION=90
S3_MONTHLY_RETENTION=365

# Create backup directories if not exists
mkdir -p "${LOCAL_BACKUP_PATH}"/{daily,weekly,monthly}

# Backup function
backup_and_upload() {
    DB_NAME=$1
    FREQUENCY=$2  # daily, weekly, monthly
    DATE_SUFFIX=$(date +"%Y-%m-%d")
    BACKUP_FILE_NAME="${DB_NAME}_${FREQUENCY}_${DATE_SUFFIX}.sql.gz"
    BACKUP_FILE_PATH="${LOCAL_BACKUP_PATH}/${FREQUENCY}/${BACKUP_FILE_NAME}"

    # Creating the backup
    echo "Creating ${FREQUENCY} backup for ${DB_NAME}"
        mysqldump -u${DB_USER} -p${DB_PASSWORD} ${DB_NAME} | gzip > "${BACKUP_FILE_PATH}"
    if [ $? -eq 0 ]; then
        echo "$(date +"%Y-%m-%d %H:%M:%S") : ${DB_NAME} ${FREQUENCY} backup created" >> "${LOG_FILE}"
        # Uploading to S3
        echo "Uploading ${BACKUP_FILE_NAME} to S3 bucket ${S3_BUCKET_NAME}"
        aws s3 cp "${BACKUP_FILE_PATH}" "s3://${S3_BUCKET_NAME}/${FREQUENCY}/${BACKUP_FILE_NAME}"
        if [ $? -eq 0 ]; then
             echo "$(date +"%Y-%m-%d %H:%M:%S") : ${DB_NAME} ${FREQUENCY} backup uploaded to S3" >> "${LOG_FILE}"
        else
             echo "$(date +"%Y-%m-%d %H:%M:%S") : ${DB_NAME} ${FREQUENCY} backup upload failed to s3" >> "${LOG_FILE}"
        fi
    else
        echo "$(date +"%Y-%m-%d %H:%M:%S") : ${DB_NAME} ${FREQUENCY} backup creation failed" >> "${LOG_FILE}"
    fi
}

# Cleanup function
cleanup() {
    DB_NAME=$1
    FREQUENCY=$2
    LOCAL_RETENTION=$3
    S3_RETENTION=$4

    # Local cleanup
    echo "Cleaning up local ${FREQUENCY} backups of ${DB_NAME} older than ${LOCAL_RETENTION} days"
    find "${LOCAL_BACKUP_PATH}/" -name "${DB_NAME}_${FREQUENCY}_*.sql.gz" -mtime +${LOCAL_RETENTION} -exec rm {} \;

    # S3 cleanup
    echo "Cleaning up S3 ${FREQUENCY} backups older than ${S3_RETENTION} days"
    aws s3 ls "s3://${S3_BUCKET_NAME}/${FREQUENCY}/" | while read -r line; do
        FILE_DATE=$(echo $line | grep -oP '\d{4}-\d{2}-\d{2}' | head -n 1)
        if [[ $(date -d "$FILE_DATE" +%s) -lt $(date -d "-${S3_RETENTION} days" +%s) ]]; then
            aws s3 rm "s3://${S3_BUCKET_NAME}/${FREQUENCY}/$(echo $line | awk '{print $4}')"
        fi
    done
}

# Main execution
for DB in "$@"; do

echo "
##################  Database: "$DB"   ####################################################
"

    # Daily backup
    backup_and_upload "$DB" "daily"
    cleanup "$DB" "daily" $LOCAL_DAILY_RETENTION $S3_DAILY_RETENTION
    # Weekly backup (assuming this runs on a specific day of the week, e.g., Sunday)
    if [ $(date +%u) -eq 7 ]; then
        backup_and_upload "$DB" "weekly"
        cleanup "$DB" "weekly" $LOCAL_WEEKLY_RETENTION $S3_WEEKLY_RETENTION
    fi

    # Monthly backup (assuming this runs on the first day of the month)
    if [ $(date +%d) -eq 01 ]; then
        backup_and_upload "$DB" "monthly"
        cleanup "$DB" "monthly" $LOCAL_MONTHLY_RETENTION $S3_MONTHLY_RETENTION
    fi
done

echo "Backup process for all databases completed."
