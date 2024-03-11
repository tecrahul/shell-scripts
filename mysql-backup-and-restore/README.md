
# MySQL Backup and Restore Scripts

This repository contains two scripts for managing MySQL database backups and restorations: one for backing up databases to a local directory and AWS S3, and another for restoring those backups either from the local system or S3.

## Backup Script

The backup script (`mysql_backup_script.sh`) automates the process of creating MySQL database backups, supporting daily, weekly, and monthly backup frequencies. It uploads these backups to an AWS S3 bucket and manages local and S3 backup retention.

### Features
- Supports multiple databases
- Daily, weekly, and monthly backup frequencies
- Local and S3 backup storage
- Configurable retention periods for both local and S3 stored backups
- Uploads backups to AWS S3
- Customizable through environment variables

### Usage

1. **Configuration**: Edit the script to set your database details, backup paths, S3 bucket name, and retention policies.
2. **Execution**: Run the script manually or set it up as a cron job for automation.

   ```bash
   ./mysql_backup_script.sh
   ```

## Restore Script

The restore script (`mysql_restore_script.sh`) allows for the restoration of databases from backups stored locally or in an AWS S3 bucket. It supports automatic restoration of the latest backup or manual selection of a specific backup.

### Features
- Restores databases from local or S3 backups
- Automatic and manual restore modes
- Manual mode allows for the selection of backup frequency and date
- Checks for local backups before attempting to restore from S3

### Usage

1. **Automatic Restoration**: Restores the latest available backup for the specified database.

   ```bash
   ./mysql_restore_script.sh my_database
   ```

2. **Manual Restoration**: Allows selection of the backup frequency and date for restoration.

   ```bash
   ./mysql_restore_script.sh --manual my_database
   ```

## Configuration

Both scripts require configuration of database details, AWS S3 settings, and other preferences. Edit the scripts to set the following variables according to your environment:

- `DB_USER`: Database user
- `DB_PASSWORD`: Database password (consider secure handling)
- `BACKUP_PATH`: Path for storing local backups
- `S3_BUCKET_NAME`: AWS S3 bucket name for backup storage
- `LOG_FILE`: Path to the log file

## Prerequisites

- MySQL or MariaDB client installed
- AWS CLI installed and configured

## Security Notes

It's crucial to handle the `DB_PASSWORD` variable securely. Avoid hardcoding sensitive information directly in the script. Consider using environment variables or secure vaults.

## Contributing

Contributions to improve the scripts or add new features are welcome. Please submit a pull request or open an issue to discuss your ideas.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
