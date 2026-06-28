#!/usr/bin/env bash
set -euo pipefail

MODULES_DIR="${1:-modules}"

mkdir -p "$MODULES_DIR"

declare -a MODULE_SPECS=(
    "mod-playerbots|https://github.com/mod-playerbots/mod-playerbots.git|master|conf/playerbots.conf.dist|data/sql/playerbots data/sql/world data/sql/characters"
    "mod-transmog|https://github.com/azerothcore/mod-transmog.git|master|conf/transmog.conf.dist|data/sql/db-auth data/sql/db-characters data/sql/db-world"
    "mod-autobalance|https://github.com/azerothcore/mod-autobalance.git|master|conf/AutoBalance.conf.dist|"
    "mod-ah-bot-plus|https://github.com/NathanHandley/mod-ah-bot-plus.git|master|conf/mod_ahbot.conf.dist|data/sql/db-auth data/sql/db-characters data/sql/db-world"
    "mod-learn-spells|https://github.com/azerothcore/mod-learn-spells.git|master|conf/mod_learnspells.conf.dist|"
    "mod-random-enchants|https://github.com/azerothcore/mod-random-enchants.git|master|conf/random_enchants.conf.dist|data/sql/db-world"
    "mod-dungeon-master|https://github.com/InstanceForge/mod-dungeon-master.git|main|conf/mod_dungeon_master.conf.dist|data/sql/db-world data/sql/db-characters"
)

declare -a REMOVED_MODULES=(
    "mod-ah-bot"
    "mod-aoe-loot"
    "mod-individual-progression"
)

log() {
    printf '[module-bundle] %s\n' "$*"
}

cleanup_legacy_module_sql_links() {
    local module_root="$1"
    local sql_root="${module_root}/data/sql"

    [[ -d "$sql_root" ]] || return 0

    local link_name target_name link_path link_target
    for link_name in auth world characters; do
        case "$link_name" in
            auth) target_name="db-auth" ;;
            world) target_name="db-world" ;;
            characters) target_name="db-characters" ;;
            *) continue ;;
        esac

        link_path="${sql_root}/${link_name}"
        if [[ -L "$link_path" ]]; then
            link_target="$(readlink "$link_path")"

            if [[ "$link_target" == "$target_name" || "$link_target" == "./${target_name}" ]]; then
                rm -f "$link_path"
                log "Removed legacy SQL compatibility link ${module_root}/data/sql/${link_name} -> ${target_name}"
            fi
        fi
    done
}

for module_name in "${REMOVED_MODULES[@]}"; do
    module_target_dir="${MODULES_DIR}/${module_name}"

    if [[ -e "$module_target_dir" ]]; then
        rm -rf "$module_target_dir"
        log "Removed obsolete ${module_name}"
    fi
done

for spec in "${MODULE_SPECS[@]}"; do
    IFS='|' read -r module_name module_repo module_branch module_conf_path module_sql_paths <<< "$spec"

    module_target_dir="${MODULES_DIR}/${module_name}"

    rm -rf "$module_target_dir"

    log "Cloning ${module_name} (${module_branch})"
    git clone --depth 1 --branch "$module_branch" --single-branch "$module_repo" "$module_target_dir" >/dev/null

    cleanup_legacy_module_sql_links "$module_target_dir"

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
