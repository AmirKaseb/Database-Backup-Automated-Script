# test.bats
#!/usr/bin/env bats

# Configuration for testing
BACKUP_DIR="backups"
DB_NAME="mydatabase"

# Test 1: Check if backup directory exists
@test "Backup directory exists" {
  run bash -c "[ -d \"$BACKUP_DIR\" ]"
  [ "$status" -eq 0 ]
}

