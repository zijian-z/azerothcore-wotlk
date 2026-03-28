#!/usr/bin/env bash
set -euo pipefail

shopt -s nullglob

AC_ROOT="${AC_ROOT:-/azerothcore}"
CONF_DIR="${CONF_DIR:-/azerothcore/env/dist/etc}"
REF_CONF_DIR="${REF_CONF_DIR:-/azerothcore/env/ref/etc}"
LOGS_DIR="${LOGS_DIR:-/azerothcore/env/dist/logs}"
TEMP_DIR="${TEMP_DIR:-/azerothcore/env/dist/temp}"
DATA_DIR="${DATA_DIR:-/azerothcore/env/dist/data}"
EXTERNAL_INPUT_DIR="${EXTERNAL_INPUT_DIR:-/azerothcore/external}"
MODULE_CONF_DIR="$CONF_DIR/modules"

AC_DB_HOST="${AC_DB_HOST:-database}"
AC_DB_PORT="${AC_DB_PORT:-3306}"
AC_DB_USER="${AC_DB_USER:-acore}"
AC_DB_PASSWORD="${AC_DB_PASSWORD:-acore}"
AC_AUTH_DATABASE="${AC_AUTH_DATABASE:-acore_auth}"
AC_WORLD_DATABASE="${AC_WORLD_DATABASE:-acore_world}"
AC_CHARACTER_DATABASE="${AC_CHARACTER_DATABASE:-acore_characters}"
AC_PLAYERBOTS_DATABASE="${AC_PLAYERBOTS_DATABASE:-acore_playerbots}"
AC_REALM_ID="${AC_REALM_ID:-1}"
AC_REALM_NAME="${AC_REALM_NAME:-AzerothCore}"
AC_REALM_ADDRESS="${AC_REALM_ADDRESS:-127.0.0.1}"
AC_REALM_LOCAL_ADDRESS="${AC_REALM_LOCAL_ADDRESS:-127.0.0.1}"
AC_REALM_LOCAL_SUBNET_MASK="${AC_REALM_LOCAL_SUBNET_MASK:-255.255.255.0}"
AC_REALM_PORT="${AC_REALM_PORT:-8085}"
AC_FORCE_DATA_IMPORT="${AC_FORCE_DATA_IMPORT:-0}"

log() {
    printf '[ac-docker] %s\n' "$*"
}

die() {
    printf '[ac-docker] ERROR: %s\n' "$*" >&2
    exit 1
}

ensure_runtime_dirs() {
    mkdir -p "$CONF_DIR" "$MODULE_CONF_DIR" "$LOGS_DIR" "$TEMP_DIR" "$DATA_DIR"
}

has_playerbots_module() {
    [[ -d "$AC_ROOT/modules/mod-playerbots" ]] || [[ -f "$MODULE_CONF_DIR/playerbots.conf.dist" ]] || [[ -f "$MODULE_CONF_DIR/playerbots.conf" ]]
}

copy_default_configs() {
    local file

    for file in "$REF_CONF_DIR"/*.conf.dist; do
        cp -f "$file" "$CONF_DIR/"
    done

    if [[ -d "$REF_CONF_DIR/modules" ]]; then
        mkdir -p "$MODULE_CONF_DIR"
        for file in "$REF_CONF_DIR/modules"/*.conf.dist; do
            cp -f "$file" "$MODULE_CONF_DIR/"
        done
    fi
}

copy_external_configs() {
    local source_dir
    local file

    for source_dir in "$EXTERNAL_INPUT_DIR" "$EXTERNAL_INPUT_DIR/config" "$EXTERNAL_INPUT_DIR/etc"; do
        if [[ -d "$source_dir" ]]; then
            for file in "$source_dir"/*.conf "$source_dir"/*.conf.dist; do
                cp -f "$file" "$CONF_DIR/"
            done
        fi

        if [[ -d "$source_dir/modules" ]]; then
            mkdir -p "$MODULE_CONF_DIR"
            for file in "$source_dir/modules"/*.conf "$source_dir/modules"/*.conf.dist; do
                cp -f "$file" "$MODULE_CONF_DIR/"
            done
        fi
    done
}

ensure_runtime_module_confs() {
    local dist_file
    local conf_file

    for dist_file in "$MODULE_CONF_DIR"/*.conf.dist; do
        conf_file="${dist_file%.dist}"

        if [[ ! -f "$conf_file" ]]; then
            cp -f "$dist_file" "$conf_file"
        fi
    done
}

ensure_runtime_conf() {
    local base_name="$1"
    local conf_file="$CONF_DIR/${base_name}.conf"
    local dist_file="$CONF_DIR/${base_name}.conf.dist"

    if [[ ! -f "$conf_file" ]]; then
        if [[ -f "$dist_file" ]]; then
            cp -f "$dist_file" "$conf_file"
        else
            : > "$conf_file"
        fi
    fi
}

escape_sed_replacement() {
    printf '%s' "$1" | sed -e 's/[&|]/\\&/g'
}

set_config_value() {
    local file="$1"
    local key="$2"
    local value="$3"
    local pattern="${key//./\\.}"
    local escaped_value

    escaped_value="$(escape_sed_replacement "$value")"

    if grep -Eq "^[[:space:]]*${pattern}[[:space:]]*=" "$file"; then
        sed -i -E "s|^[[:space:]]*${pattern}[[:space:]]*=.*$|${key} = ${escaped_value}|" "$file"
    else
        printf '\n%s = %s\n' "$key" "$value" >> "$file"
    fi
}

prepare_configs() {
    ensure_runtime_dirs
    copy_default_configs
    copy_external_configs
    ensure_runtime_module_confs

    ensure_runtime_conf "authserver"
    ensure_runtime_conf "worldserver"
    set_config_value "$CONF_DIR/authserver.conf" "LoginDatabaseInfo" "\"${AC_DB_HOST};${AC_DB_PORT};${AC_DB_USER};${AC_DB_PASSWORD};${AC_AUTH_DATABASE}\""
    set_config_value "$CONF_DIR/authserver.conf" "LogsDir" "\"${LOGS_DIR}\""
    set_config_value "$CONF_DIR/authserver.conf" "TempDir" "\"${TEMP_DIR}\""
    set_config_value "$CONF_DIR/authserver.conf" "SourceDirectory" "\"${AC_ROOT}\""
    set_config_value "$CONF_DIR/authserver.conf" "MySQLExecutable" "\"/usr/bin/mysql\""
    set_config_value "$CONF_DIR/authserver.conf" "Updates.EnableDatabases" "0"

    set_config_value "$CONF_DIR/worldserver.conf" "LoginDatabaseInfo" "\"${AC_DB_HOST};${AC_DB_PORT};${AC_DB_USER};${AC_DB_PASSWORD};${AC_AUTH_DATABASE}\""
    set_config_value "$CONF_DIR/worldserver.conf" "WorldDatabaseInfo" "\"${AC_DB_HOST};${AC_DB_PORT};${AC_DB_USER};${AC_DB_PASSWORD};${AC_WORLD_DATABASE}\""
    set_config_value "$CONF_DIR/worldserver.conf" "CharacterDatabaseInfo" "\"${AC_DB_HOST};${AC_DB_PORT};${AC_DB_USER};${AC_DB_PASSWORD};${AC_CHARACTER_DATABASE}\""
    set_config_value "$CONF_DIR/worldserver.conf" "LogsDir" "\"${LOGS_DIR}\""
    set_config_value "$CONF_DIR/worldserver.conf" "TempDir" "\"${TEMP_DIR}\""
    set_config_value "$CONF_DIR/worldserver.conf" "DataDir" "\"${DATA_DIR}\""
    set_config_value "$CONF_DIR/worldserver.conf" "SourceDirectory" "\"${AC_ROOT}\""
    set_config_value "$CONF_DIR/worldserver.conf" "MySQLExecutable" "\"/usr/bin/mysql\""
    set_config_value "$CONF_DIR/worldserver.conf" "Updates.EnableDatabases" "7"
    set_config_value "$CONF_DIR/worldserver.conf" "Updates.AutoSetup" "1"

    if has_playerbots_module; then
        set_config_value "$MODULE_CONF_DIR/playerbots.conf" "PlayerbotsDatabaseInfo" "\"${AC_DB_HOST};${AC_DB_PORT};${AC_DB_USER};${AC_DB_PASSWORD};${AC_PLAYERBOTS_DATABASE}\""
        set_config_value "$MODULE_CONF_DIR/playerbots.conf" "Playerbots.Updates.EnableDatabases" "1"
        set_config_value "$CONF_DIR/worldserver.conf" "Updates.EnableDatabases" "15"
    fi
}

data_is_ready() {
    [[ -d "$DATA_DIR/dbc" && -d "$DATA_DIR/maps" && -d "$DATA_DIR/vmaps" && -d "$DATA_DIR/mmaps" ]]
}

find_data_archive() {
    local candidate

    for candidate in \
        "$EXTERNAL_INPUT_DIR/Data.zip" \
        "$EXTERNAL_INPUT_DIR/data/Data.zip" \
        "$EXTERNAL_INPUT_DIR/client/Data.zip"
    do
        if [[ -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

prepare_data() {
    local archive
    local staging_dir
    local payload_dir

    ensure_runtime_dirs

    if data_is_ready && [[ "$AC_FORCE_DATA_IMPORT" != "1" ]]; then
        log "Client data already exists in $DATA_DIR, skipping Data.zip import."
        return
    fi

    archive="$(find_data_archive || true)"
    if [[ -z "$archive" ]]; then
        if data_is_ready; then
            log "Using pre-extracted client data from $DATA_DIR."
            return
        fi

        die "No external Data.zip was found and $DATA_DIR does not already contain dbc/maps/vmaps/mmaps."
    fi

    staging_dir="${DATA_DIR}/.extract-tmp"
    rm -rf "$staging_dir"
    mkdir -p "$staging_dir"

    if [[ "$AC_FORCE_DATA_IMPORT" == "1" ]]; then
        rm -rf \
            "$DATA_DIR/dbc" \
            "$DATA_DIR/maps" \
            "$DATA_DIR/vmaps" \
            "$DATA_DIR/mmaps" \
            "$DATA_DIR/Cameras"
    fi

    unzip -oq "$archive" -d "$staging_dir"

    payload_dir="$staging_dir"
    if [[ -d "$staging_dir/Data" ]]; then
        payload_dir="$staging_dir/Data"
    fi

    mkdir -p "$DATA_DIR"
    cp -a "$payload_dir"/. "$DATA_DIR/"
    rm -rf "$staging_dir"

    if ! data_is_ready; then
        die "Data.zip was extracted, but dbc/maps/vmaps/mmaps were not found in the archive payload."
    fi

    log "Client data import completed from $(basename "$archive")."
}

mysql_command() {
    local user="$1"
    local password="${2-}"
    local sql="${3-}"
    local args=(
        --protocol=TCP
        --host="$AC_DB_HOST"
        --port="$AC_DB_PORT"
        --user="$user"
        --batch
        --skip-column-names
        --raw
    )

    if [[ -n "$password" ]]; then
        args+=(--password="$password")
    fi

    if [[ -n "$sql" ]]; then
        mysql "${args[@]}" -e "$sql"
    else
        mysql "${args[@]}"
    fi
}

wait_for_mysql() {
    local user="$1"
    local password="${2-}"
    local attempt

    for attempt in $(seq 1 60); do
        if mysql_command "$user" "$password" "SELECT 1;" >/dev/null 2>&1; then
            return 0
        fi

        sleep 2
    done

    die "MySQL at ${AC_DB_HOST}:${AC_DB_PORT} did not become ready in time."
}

sql_escape() {
    printf '%s' "$1" | sed "s/'/''/g"
}

bootstrap_mysql() {
    local db_user
    local db_password
    local playerbots_sql=""

    wait_for_mysql "root"

    db_user="$(sql_escape "$AC_DB_USER")"
    db_password="$(sql_escape "$AC_DB_PASSWORD")"

    if has_playerbots_module; then
        playerbots_sql="
        CREATE DATABASE IF NOT EXISTS \`${AC_PLAYERBOTS_DATABASE}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
        GRANT ALL PRIVILEGES ON \`${AC_PLAYERBOTS_DATABASE}\`.* TO '${db_user}'@'%' WITH GRANT OPTION;
        "
    fi

    mysql_command "root" "" "
        CREATE DATABASE IF NOT EXISTS \`${AC_AUTH_DATABASE}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
        CREATE DATABASE IF NOT EXISTS \`${AC_WORLD_DATABASE}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
        CREATE DATABASE IF NOT EXISTS \`${AC_CHARACTER_DATABASE}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
        CREATE USER IF NOT EXISTS '${db_user}'@'%' IDENTIFIED BY '${db_password}';
        ALTER USER '${db_user}'@'%' IDENTIFIED BY '${db_password}';
        GRANT ALL PRIVILEGES ON \`${AC_AUTH_DATABASE}\`.* TO '${db_user}'@'%' WITH GRANT OPTION;
        GRANT ALL PRIVILEGES ON \`${AC_WORLD_DATABASE}\`.* TO '${db_user}'@'%' WITH GRANT OPTION;
        GRANT ALL PRIVILEGES ON \`${AC_CHARACTER_DATABASE}\`.* TO '${db_user}'@'%' WITH GRANT OPTION;
        ${playerbots_sql}
        FLUSH PRIVILEGES;
    "
}

table_exists() {
    local database_name="$1"
    local table_name="$2"
    local result

    result="$(mysql_command "$AC_DB_USER" "$AC_DB_PASSWORD" "
        SELECT COUNT(*)
        FROM information_schema.tables
        WHERE table_schema='${database_name}'
          AND table_name='${table_name}';
    ")"

    [[ "$result" -ge 1 ]]
}

wait_for_table() {
    local database_name="$1"
    local table_name="$2"
    local attempt

    for attempt in $(seq 1 600); do
        if table_exists "$database_name" "$table_name"; then
            return 0
        fi

        sleep 2
    done

    die "Timed out waiting for ${database_name}.${table_name} to be created by AzerothCore."
}

configure_realm() {
    local realm_id
    local realm_name
    local realm_address
    local local_address
    local local_subnet_mask

    realm_id="$(printf '%s' "$AC_REALM_ID")"
    realm_name="$(sql_escape "$AC_REALM_NAME")"
    realm_address="$(sql_escape "$AC_REALM_ADDRESS")"
    local_address="$(sql_escape "$AC_REALM_LOCAL_ADDRESS")"
    local_subnet_mask="$(sql_escape "$AC_REALM_LOCAL_SUBNET_MASK")"

    mysql_command "$AC_DB_USER" "$AC_DB_PASSWORD" "
        INSERT INTO \`${AC_AUTH_DATABASE}\`.realmlist
            (id, name, address, localAddress, localSubnetMask, port, icon, flag, timezone, allowedSecurityLevel, population, gamebuild)
        VALUES
            (${realm_id}, '${realm_name}', '${realm_address}', '${local_address}', '${local_subnet_mask}', ${AC_REALM_PORT}, 0, 0, 1, 0, 0, 12340)
        ON DUPLICATE KEY UPDATE
            name = VALUES(name),
            address = VALUES(address),
            localAddress = VALUES(localAddress),
            localSubnetMask = VALUES(localSubnetMask),
            port = VALUES(port);
    "
}

run_db_prepare() {
    prepare_configs
    bootstrap_mysql
}

run_server() {
    local server_name="$1"
    shift || true

    prepare_configs

    if [[ "$server_name" == "worldserver" ]]; then
        prepare_data
    fi

    export AC_DISABLE_INTERACTIVE=1

    wait_for_mysql "$AC_DB_USER" "$AC_DB_PASSWORD"

    if [[ "$server_name" == "authserver" ]]; then
        wait_for_table "$AC_AUTH_DATABASE" "realmlist"
        configure_realm
    fi

    log "Starting ${server_name}."
    exec "$server_name" "$@"
}

main() {
    local command="${1:-${ACORE_COMPONENT:-shell}}"

    case "$command" in
        authserver)
            shift || true
            run_server "authserver" "$@"
            ;;
        worldserver)
            shift || true
            run_server "worldserver" "$@"
            ;;
        db-prepare)
            run_db_prepare
            ;;
        data-init)
            prepare_data
            ;;
        bash|shell)
            exec /bin/bash
            ;;
        *)
            prepare_configs
            exec "$@"
            ;;
    esac
}

main "$@"
