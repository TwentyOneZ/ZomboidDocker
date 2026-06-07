#!/usr/bin/env bash
set -euo pipefail

SERVER_NAME="${SERVER_NAME:-servertest}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
STEAM_BRANCH="${STEAM_BRANCH:-unstable}"
UPDATE_ON_START="${UPDATE_ON_START:-true}"
TZ="${TZ:-America/Sao_Paulo}"
BACKUP_ENABLED="${BACKUP_ENABLED:-true}"
BACKUP_TIME="${BACKUP_TIME:-04:30}"
BACKUP_LOCAL_DIR="${BACKUP_LOCAL_DIR:-/backups}"
BACKUP_TARGET_DIR="${BACKUP_TARGET_DIR:-/backup-target}"
SHUTDOWN_GRACE_SECONDS="${SHUTDOWN_GRACE_SECONDS:-180}"

STEAMCMD_DIR="/opt/steamcmd"
SERVER_DIR="/opt/pzserver"
DATA_DIR="/data"
STEAM_HOME="/home/steam"
HOME_ZOMBOID="${STEAM_HOME}/Zomboid"
PERSISTENT_ZOMBOID="${DATA_DIR}/Zomboid"
SERVER_PID=""

export TZ

echo "Starting Project Zomboid Dedicated Server"
echo "Server name: ${SERVER_NAME}"
if [[ -n "${ADMIN_PASSWORD}" ]]; then
    echo "Admin password: configured"
else
    echo "Admin password: not configured"
fi
echo "Steam branch: ${STEAM_BRANCH}"
echo "Update on start: ${UPDATE_ON_START}"
echo "Timezone: ${TZ}"
echo "Daily backup: ${BACKUP_ENABLED} at ${BACKUP_TIME}"

is_true() {
    case "${1,,}" in
        true|1|yes|y|on) return 0 ;;
        *) return 1 ;;
    esac
}

validate_backup_time() {
    if [[ ! "${BACKUP_TIME}" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
        echo "Invalid BACKUP_TIME '${BACKUP_TIME}'. Use HH:MM, for example 04:30."
        exit 1
    fi
}

next_backup_epoch() {
    local now target

    now="$(date +%s)"
    target="$(date -d "today ${BACKUP_TIME}" +%s)"

    if (( target <= now )); then
        target="$(date -d "tomorrow ${BACKUP_TIME}" +%s)"
    fi

    echo "${target}"
}

format_epoch() {
    date -d "@${1}" "+%Y-%m-%d %H:%M:%S %Z"
}

mkdir -p "${PERSISTENT_ZOMBOID}" "${SERVER_DIR}" "${BACKUP_LOCAL_DIR}" "${BACKUP_TARGET_DIR}"
chown -R steam:steam "${DATA_DIR}" "${SERVER_DIR}" "${STEAM_HOME}"

link_zomboid_dir() {
    if [[ -L "${HOME_ZOMBOID}" ]]; then
        ln -sfnT "${PERSISTENT_ZOMBOID}" "${HOME_ZOMBOID}"
    elif [[ -d "${HOME_ZOMBOID}" ]]; then
        shopt -s dotglob nullglob
        local existing_items=("${HOME_ZOMBOID}"/*)

        if (( ${#existing_items[@]} > 0 )); then
            echo "Moving existing Zomboid files into ${PERSISTENT_ZOMBOID}"
            mv "${existing_items[@]}" "${PERSISTENT_ZOMBOID}/"
        fi

        rmdir "${HOME_ZOMBOID}"
        ln -s "${PERSISTENT_ZOMBOID}" "${HOME_ZOMBOID}"
    elif [[ -e "${HOME_ZOMBOID}" ]]; then
        rm -f "${HOME_ZOMBOID}"
        ln -s "${PERSISTENT_ZOMBOID}" "${HOME_ZOMBOID}"
    else
        ln -s "${PERSISTENT_ZOMBOID}" "${HOME_ZOMBOID}"
    fi

    chown -h steam:steam "${HOME_ZOMBOID}"
}

fix_steamclient_links() {
    local steam_root="${STEAM_HOME}/.steam"
    local sdk64="${steam_root}/sdk64"
    local sdk32="${steam_root}/sdk32"
    local steamcmd64="${steam_root}/steamcmd/linux64/steamclient.so"
    local steamcmd32="${steam_root}/steamcmd/linux32/steamclient.so"
    local opt64="${STEAMCMD_DIR}/linux64/steamclient.so"
    local opt32="${STEAMCMD_DIR}/linux32/steamclient.so"

    mkdir -p "${sdk64}" "${sdk32}"

    if [[ -f "${steamcmd64}" ]]; then
        ln -sf "${steamcmd64}" "${sdk64}/steamclient.so"
    elif [[ -f "${opt64}" ]]; then
        ln -sf "${opt64}" "${sdk64}/steamclient.so"
    fi

    if [[ -f "${steamcmd32}" ]]; then
        ln -sf "${steamcmd32}" "${sdk32}/steamclient.so"
    elif [[ -f "${opt32}" ]]; then
        ln -sf "${opt32}" "${sdk32}/steamclient.so"
    fi

    chown -hR steam:steam "${steam_root}"
}

server_is_alive() {
    local state

    if [[ -z "${SERVER_PID}" || ! -d "/proc/${SERVER_PID}" ]]; then
        return 1
    fi

    state="$(awk '{print $3}' "/proc/${SERVER_PID}/stat" 2>/dev/null || true)"
    [[ -n "${state}" && "${state}" != "Z" ]]
}

start_server() {
    local server_args=(-servername "${SERVER_NAME}")

    if [[ -n "${ADMIN_PASSWORD}" ]]; then
        server_args+=(-adminpassword "${ADMIN_PASSWORD}")
    fi

    cd "${SERVER_DIR}"
    chmod +x ./start-server.sh

    echo "Starting Project Zomboid process"
    setsid runuser -u steam -- ./start-server.sh "${server_args[@]}" &
    SERVER_PID="$!"
    echo "Project Zomboid process group started with pid ${SERVER_PID}"
}

stop_server() {
    local waited=0

    if ! server_is_alive; then
        wait "${SERVER_PID}" 2>/dev/null || true
        SERVER_PID=""
        return 0
    fi

    echo "Stopping Project Zomboid for backup"
    kill -TERM -- "-${SERVER_PID}" 2>/dev/null || kill -TERM "${SERVER_PID}" 2>/dev/null || true

    while server_is_alive; do
        if (( waited >= SHUTDOWN_GRACE_SECONDS )); then
            echo "Grace period expired after ${SHUTDOWN_GRACE_SECONDS}s; forcing shutdown"
            kill -KILL -- "-${SERVER_PID}" 2>/dev/null || kill -KILL "${SERVER_PID}" 2>/dev/null || true
            break
        fi

        sleep 5
        waited=$((waited + 5))
    done

    wait "${SERVER_PID}" 2>/dev/null || true
    SERVER_PID=""
    echo "Project Zomboid stopped"
}

create_and_move_backup() {
    local timestamp archive_name temp_archive local_archive target_archive

    mkdir -p "${BACKUP_LOCAL_DIR}" "${BACKUP_TARGET_DIR}"

    timestamp="$(date "+%Y%m%d-%H%M%S")"
    archive_name="zomboid-${SERVER_NAME}-${timestamp}.tar.gz"
    temp_archive="${BACKUP_LOCAL_DIR}/${archive_name}.tmp"
    local_archive="${BACKUP_LOCAL_DIR}/${archive_name}"
    target_archive="${BACKUP_TARGET_DIR}/${archive_name}"

    echo "Creating backup at ${local_archive}"
    tar -czf "${temp_archive}" -C "${DATA_DIR}" Zomboid || return 1
    mv "${temp_archive}" "${local_archive}" || return 1

    echo "Moving backup to ${target_archive}"
    mv "${local_archive}" "${target_archive}" || return 1

    echo "Backup complete: ${target_archive}"
}

run_daily_backup_cycle() {
    echo "Daily backup cycle started"
    stop_server

    if create_and_move_backup; then
        echo "Daily backup cycle finished"
    else
        echo "Daily backup failed. Restarting the server anyway; check ${BACKUP_LOCAL_DIR} and ${BACKUP_TARGET_DIR}."
    fi

    start_server
}

handle_shutdown_signal() {
    echo "Shutdown signal received"
    stop_server
    exit 0
}

link_zomboid_dir

if is_true "${UPDATE_ON_START}"; then
    echo "Installing/updating Project Zomboid Dedicated Server through SteamCMD"
    runuser -u steam -- "${STEAMCMD_DIR}/steamcmd.sh" \
        +force_install_dir "${SERVER_DIR}" \
        +login anonymous \
        +app_update 380870 -beta "${STEAM_BRANCH}" validate \
        +quit
else
    echo "Skipping SteamCMD update because UPDATE_ON_START is not true"
fi

fix_steamclient_links

trap handle_shutdown_signal SIGTERM SIGINT

if is_true "${BACKUP_ENABLED}"; then
    validate_backup_time
fi

start_server

next_backup_at=0
if is_true "${BACKUP_ENABLED}"; then
    next_backup_at="$(next_backup_epoch)"
    echo "Next daily backup: $(format_epoch "${next_backup_at}")"
fi

while true; do
    if ! server_is_alive; then
        set +e
        wait "${SERVER_PID}" 2>/dev/null
        exit_code="$?"
        set -e

        echo "Project Zomboid process exited with code ${exit_code}"
        exit "${exit_code}"
    fi

    if is_true "${BACKUP_ENABLED}"; then
        now="$(date +%s)"

        if (( now >= next_backup_at )); then
            run_daily_backup_cycle
            next_backup_at="$(next_backup_epoch)"
            echo "Next daily backup: $(format_epoch "${next_backup_at}")"
        fi
    fi

    sleep 30
done
