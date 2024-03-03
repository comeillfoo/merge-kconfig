#!/usr/bin/env bash
set -eo pipefail

# @brief No such file or directory
ENOENT=2

# @brief Invalid argument error code
EINVAL=22

CONFIG='scripts/config'
VERBOSE=false
PARAMS=()

# TODO: document
exist_or_die() {
    local path="$1"
    if [ ! -f "${path}" ]; then
        echo "Fatal: \"${path}\" not found"
        exit $ENOENT
    fi
    return 0
}

# TODO: document
length() {
    local array=("$@")
    echo "${#array[@]}"
    return 0
}

# TODO: document
log_run() {
    local cmd="$*"
    if $VERBOSE; then
        echo "$*" >&2
    fi
    ${cmd}
    return $?
}

# TODO: document
usage() {
    cat << EOF
Usage: $0 diffconfig base-config

Applies diffconfig to base kernel configuration

Options:
    -h, --help                  Prints this help message and exits
    -c, --config scripts-config Path to scripts/config utility
    -v, --verbose               Verbose mode

EOF
    exit $EINVAL
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            PARAMS+=("$1")
            shift
            ;;
    esac
done
[ "$(length "${PARAMS[@]}")" -lt 2 ] && usage

DIFFCONFIG="${PARAMS[0]}"
BASECONFIG="${PARAMS[1]}"
CONFIG_CMD="${CONFIG} --file ${BASECONFIG}"

exist_or_die "${DIFFCONFIG}"
echo "Reading diff from ${DIFFCONFIG}"
exist_or_die "${BASECONFIG}"
echo "Reading config from ${BASECONFIG}"

while read -r entry; do
    read -ra entry_parts <<<"$entry"
    config_option=${entry_parts[0]:1}
    config_value=''
    config_cmd_args=()
    should_parse_value=true
    case ${entry_parts[0]} in
        -*)
            config_cmd_args+=(--undefine "${config_option}")
            should_parse_value=false
            ;;
        +*)
            config_value=${entry_parts[1]}
            ;;
        *)
            config_value="${entry_parts[3]}"
            ;;
    esac
    # parse option value
    if $should_parse_value; then
        case $config_value in
            y)
                config_cmd_args+=(--enable "${config_option}")
                ;;
            m)
                config_cmd_args+=(--module "${config_option}")
                ;;
            n)
                config_cmd_args+=(--disable "${config_option}")
                ;;
            0x*)
                config_cmd_args+=(--set-val "${config_option}" "${config_value}")
                ;;
            \"*)
                config_cmd_args+=(--set-str "${config_option}" "${config_value}")
                ;;
            1*|2*|3*|4*|5*|6*|7*|8*|9*)
                config_cmd_args+=(--set-val "${config_option}" "${config_value}")
                ;;
            *)
                echo "Unknown value [${config_value}] for ${config_option}" >&2
                exit $EINVAL
                ;;
        esac
    fi
    log_run "${CONFIG_CMD}" "${config_cmd_args[@]}"
done < "${DIFFCONFIG}"
