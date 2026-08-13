#!/bin/bash

set -euo pipefail
umask 077

die() {
    printf 'backup-supabase: error: %s\n' "$*" >&2
    exit 1
}

info() {
    printf 'backup-supabase: %s\n' "$*"
}

help_has() {
    case "$1" in
        *"$2"*) return 0 ;;
        *) return 1 ;;
    esac
}

db_url=${DRIPWATCH_DB_URL:-}
backup_root=${DRIPWATCH_BACKUP_DIR:-}

[ -n "$db_url" ] || die 'DRIPWATCH_DB_URL is required'
[ -n "$backup_root" ] || die 'DRIPWATCH_BACKUP_DIR is required'

case "$backup_root" in
    /*) ;;
    *) die 'DRIPWATCH_BACKUP_DIR must be an existing absolute path, not a relative path' ;;
esac

[ -d "$backup_root" ] || die 'DRIPWATCH_BACKUP_DIR must already exist as a directory'
canonical_backup_root=$(cd -P -- "$backup_root" && pwd -P) \
    || die 'could not resolve DRIPWATCH_BACKUP_DIR'
[ "$canonical_backup_root" != '/' ] \
    || die 'refusing to use the filesystem root as DRIPWATCH_BACKUP_DIR'
[ -w "$canonical_backup_root" ] \
    || die 'DRIPWATCH_BACKUP_DIR is not writable'

command -v supabase >/dev/null 2>&1 \
    || die 'supabase CLI is not installed or is not on PATH'

# The CLI changes its command tree and flags periodically. Check help output
# before constructing any command so a changed CLI fails closed rather than
# silently producing an incomplete backup.
top_help=$(supabase --help 2>&1) \
    || die 'supabase --help failed'
help_has "$top_help" 'db' \
    || die 'current Supabase CLI does not advertise the db command'

db_help=$(supabase db --help 2>&1) \
    || die 'supabase db --help failed'
help_has "$db_help" 'dump' \
    || die 'current Supabase CLI does not advertise supabase db dump'

dump_help=$(supabase db dump --help 2>&1) \
    || die 'supabase db dump --help failed'
help_has "$dump_help" '--db-url' \
    || die 'supabase db dump has no --db-url flag; refusing to guess a connection method'
help_has "$dump_help" '--data-only' \
    || die 'supabase db dump has no --data-only flag; refusing to create a schema-only backup'

db_file_flag=''
if help_has "$dump_help" '--file'; then
    db_file_flag='--file'
elif help_has "$dump_help" '-f'; then
    db_file_flag='-f'
else
    die 'supabase db dump has no recognized file-output flag'
fi

storage_help=$(supabase storage --help 2>&1) \
    || die 'supabase storage --help failed'
help_has "$storage_help" 'cp' \
    || die 'current Supabase CLI does not advertise supabase storage cp'

storage_cp_help=$(supabase storage cp --help 2>&1) \
    || die 'supabase storage cp --help failed'
help_has "$storage_cp_help" '--linked' \
    || die 'supabase storage cp has no --linked flag; refusing to guess a project target'

storage_recursive_flag=''
if help_has "$storage_cp_help" '--recursive'; then
    storage_recursive_flag='--recursive'
elif help_has "$storage_cp_help" '-r'; then
    storage_recursive_flag='-r'
else
    die 'supabase storage cp has no recognized recursive-copy flag'
fi

storage_experimental_flag=''
if help_has "$storage_cp_help" '--experimental'; then
    storage_experimental_flag='--experimental'
fi

timestamp=$(date -u '+%Y%m%dT%H%M%SZ') \
    || die 'could not create a UTC timestamp'
run_dir="$canonical_backup_root/$timestamp"
[ ! -e "$run_dir" ] \
    || die "backup path already exists: $run_dir"
mkdir "$run_dir" \
    || die "could not create backup directory: $run_dir"
chmod 700 "$run_dir"

manifest_path="$run_dir/manifest.txt"
schema_dump="$run_dir/database-schema.sql"
data_dump="$run_dir/database-data.sql"
storage_root="$run_dir/storage"
mkdir -p "$storage_root/bean-photos" "$storage_root/brew-photos"

cli_version=$(supabase --version 2>&1 | head -n 1 || true)
cli_version=${cli_version:-unknown}
storage_mode='linked'
[ -n "$storage_experimental_flag" ] && storage_mode='linked + experimental'

cat > "$manifest_path" <<EOF
DripWatch Supabase backup
timestamp_utc=$timestamp
supabase_cli_version=$cli_version
database_url=omitted
database_schema=$schema_dump
database_data=$data_dump
bean_photos=$storage_root/bean-photos
brew_photos=$storage_root/brew-photos
storage_cli_mode=$storage_mode
retention=keep-all
status=started
EOF

backup_exit_status=0
on_exit() {
    backup_exit_status=$?
    if [ "$backup_exit_status" -eq 0 ]; then
        printf 'status=complete\n' >> "$manifest_path" || true
        info "complete: $run_dir"
    else
        printf 'status=incomplete\n' >> "$manifest_path" || true
        printf 'backup-supabase: incomplete backup retained for inspection: %s\n' \
            "$run_dir" >&2
    fi
    return "$backup_exit_status"
}
trap on_exit EXIT

db_url_args=(--db-url "$db_url")

info 'dumping database schema'
supabase db dump "${db_url_args[@]}" "$db_file_flag" "$schema_dump"

data_args=("${db_url_args[@]}" --data-only)
if help_has "$dump_help" '--use-copy'; then
    data_args+=(--use-copy)
fi
info 'dumping database data'
supabase db dump "${data_args[@]}" "$db_file_flag" "$data_dump"

copy_bucket() {
    local bucket=$1
    local destination=$2
    local storage_args=("$storage_recursive_flag" --linked)
    [ -z "$storage_experimental_flag" ] || storage_args+=("$storage_experimental_flag")

    info "copying storage bucket: $bucket"
    supabase storage cp "${storage_args[@]}" "ss:///$bucket" "$destination"
}

copy_bucket 'bean-photos' "$storage_root/bean-photos"
copy_bucket 'brew-photos' "$storage_root/brew-photos"
