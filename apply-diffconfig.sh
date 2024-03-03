#!/usr/bin/env bash
set -eo pipefail

# @brief Invalid argument error code
EINVAL=22

# TODO: document
usage() {
    cat << EOF
Usage: $0 DIFF ORIG_CONFIG

Applies diffconfig to kernel configuration

Options:
    -h, --help                  Prints this help message and exits
    -c, --config scripts-config Path to scripts/config utility
    -i, --in-place              Edit file in place

EOF
    exit $EINVAL
}

# TODO: document
length() {
    local array=("$@")
    echo "${#array[@]}"
    return 0
}

INPLACE=false
CONFIG='scripts/config'
PARAMS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG="$2"
            shift 2
            ;;
        -i|--in-place)
            INPLACE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            PARAMS+=("$1")
            shift
            ;;
    esac
done
[ "$(length "${PARAMS[@]}")" -lt 2 ] && usage

DIFF_CONFIG="${PARAMS[0]}"
ORIG_CONFIG="${PARAMS[1]}"

echo "Reading diff from ${DIFF_CONFIG}"
echo "Reading config from ${ORIG_CONFIG}"

while read -r entry; do
    read -ra entry_parts <<<"$entry"
    config_option=${entry_parts[0]:1}
    config_value=''
    case ${entry_parts[0]} in
        +*)
            config_value=${entry_parts[1]}
            ;;
        -*)
            ${CONFIG} --file "${ORIG_CONFIG}" --undefine "${config_option}"
            continue
            ;;
        *)
            config_value="${entry_parts[3]}"
            ;;
    esac
    # parse option value
    case $config_value in
        y)
            ${CONFIG} --file "${ORIG_CONFIG}" --enable "${config_option}"
            ;;
        m)
            ${CONFIG} --file "${ORIG_CONFIG}" --module "${config_option}"
            ;;
        n)
            ${CONFIG} --file "${ORIG_CONFIG}" --disable "${config_option}"
            ;;
        0x*)
            ${CONFIG} --file "${ORIG_CONFIG}" --set-val "${config_option}" "${config_value}"
            ;;
        *)
            ${CONFIG} --file "${ORIG_CONFIG}" --set-str "${config_option}" "${config_value}"
            ;;
    esac
done < "${DIFF_CONFIG}"
