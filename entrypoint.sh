#!/usr/bin/env bash
set -euo pipefail

SERVER_NAME="${SERVER_NAME:-servertest}"
STEAM_BRANCH="${STEAM_BRANCH:-unstable}"
UPDATE_ON_START="${UPDATE_ON_START:-true}"

STEAMCMD_DIR="/opt/steamcmd"
SERVER_DIR="/opt/pzserver"
DATA_DIR="/data"
STEAM_HOME="/home/steam"
HOME_ZOMBOID="${STEAM_HOME}/Zomboid"
PERSISTENT_ZOMBOID="${DATA_DIR}/Zomboid"

echo "Starting Project Zomboid Dedicated Server"
echo "Server name: ${SERVER_NAME}"
echo "Steam branch: ${STEAM_BRANCH}"
echo "Update on start: ${UPDATE_ON_START}"

mkdir -p "${PERSISTENT_ZOMBOID}" "${SERVER_DIR}"
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

link_zomboid_dir

if [[ "${UPDATE_ON_START,,}" == "true" ]]; then
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

cd "${SERVER_DIR}"
chmod +x ./start-server.sh

exec runuser -u steam -- ./start-server.sh -servername "${SERVER_NAME}"
