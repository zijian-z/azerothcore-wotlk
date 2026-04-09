#!/usr/bin/env bash
set -euo pipefail

MODULES_DIR="${1:-modules}"

mkdir -p "$MODULES_DIR"

declare -a MODULE_SPECS=(
    "mod-playerbots|https://github.com/mod-playerbots/mod-playerbots.git|master|conf/playerbots.conf.dist|data/sql/playerbots data/sql/world data/sql/characters"
    "mod-transmog|https://github.com/azerothcore/mod-transmog.git|master|conf/transmog.conf.dist|data/sql/db-auth data/sql/db-characters data/sql/db-world"
    "mod-autobalance|https://github.com/azerothcore/mod-autobalance.git|master|conf/AutoBalance.conf.dist|"
    "mod-ah-bot-plus|https://github.com/NathanHandley/mod-ah-bot-plus.git|master|conf/mod_ahbot.conf.dist|data/sql/db-auth data/sql/db-characters data/sql/db-world"
    "mod-aoe-loot|https://github.com/azerothcore/mod-aoe-loot.git|master|conf/mod_aoe_loot.conf.dist|data/sql/db-auth data/sql/db-characters data/sql/db-world"
)

log() {
    printf '[module-bundle] %s\n' "$*"
}

normalize_module_sql_layout() {
    local module_root="$1"
    local sql_root="${module_root}/data/sql"

    [[ -d "$sql_root" ]] || return 0

    local source_dir target_name
    for source_dir in db-auth db-world db-characters; do
        case "$source_dir" in
            db-auth) target_name="auth" ;;
            db-world) target_name="world" ;;
            db-characters) target_name="characters" ;;
            *) continue ;;
        esac

        if [[ -d "${sql_root}/${source_dir}" && ! -e "${sql_root}/${target_name}" ]]; then
            ln -s "$source_dir" "${sql_root}/${target_name}"
            log "Linked ${module_root}/data/sql/${target_name} -> ${source_dir}"
        fi
    done
}

for spec in "${MODULE_SPECS[@]}"; do
    IFS='|' read -r module_name module_repo module_branch module_conf_path module_sql_paths <<< "$spec"

    module_target_dir="${MODULES_DIR}/${module_name}"

    rm -rf "$module_target_dir"

    log "Cloning ${module_name} (${module_branch})"
    git clone --depth 1 --branch "$module_branch" --single-branch "$module_repo" "$module_target_dir" >/dev/null

    normalize_module_sql_layout "$module_target_dir"

    if [[ -n "$module_conf_path" && ! -f "${module_target_dir}/${module_conf_path}" ]]; then
        printf '[module-bundle] ERROR: missing config file: %s\n' "${module_target_dir}/${module_conf_path}" >&2
        exit 1
    fi

    for sql_path in $module_sql_paths; do
        if [[ ! -e "${module_target_dir}/${sql_path}" ]]; then
            printf '[module-bundle] ERROR: missing SQL path: %s\n' "${module_target_dir}/${sql_path}" >&2
            exit 1
        fi
    done

    module_commit="$(git -C "$module_target_dir" rev-parse --short HEAD)"
    log "Ready ${module_name} @ ${module_commit}"
done

log "Bundled modules prepared in ${MODULES_DIR}"
