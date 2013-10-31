#!/bin/bash
#
# fix_virtualenv_location.sh
#
# Author: Gary M. Josack <gary@byoteki.com>
# Repository: https://github.com/gmjosack/scripts
# License: MIT
#
# This is a simple script to clean up links and references in a
# python virtualenv that has been relocated.

function wrap_color(){
    local red="\e[31m"
    local blue="\e[34m"
    local reset="\e[0m"

    local color="$1"; shift
    local data="$*"
    local output=""

    case "$color" in
        red)  output="${red}${data}${reset}" ;;
        blue) output="${blue}${data}${reset}" ;;
        *)    output="${data}" ;;
    esac

    echo "$output"
}


function log(){
    local name="$1"
    local line="$2"
    local stream="${3:-stdout}"
    local color="$4"

    local msg="[$name] $line"
    [[ -n "$color" ]] && msg=$(wrap_color "$color" "$msg")

    if [[ "$stream" == "stderr" ]]; then
        echo -e $msg 1>&2
    else
        echo -e $msg
    fi
}


function info(){
    log "info" "$*" "stdout" "blue"
}


function err(){
    log "error" "$*" "stderr" "red"
}


function die(){
    err "$*"
    exit 1
}


function abspath(){
    echo $(cd "$1"; pwd)
}


function add_trailing_slash(){
    [[ "${1:(-1)}" == "/" ]] && echo "$1" || echo "$1/"
}


function rm_trailing_slash(){
    [[ "${1:(-1)}" == "/" ]] && echo "${1:0:-1}" || echo "$1"
}


function usage(){
    local preamble="$1"
    local prog=$(basename $0)

    [[ -n "$preamble" ]] && err "${preamble}\n"
    echo "Usage: ${PROG} <old_name> <new_venv>"
    echo "  <old_name> - The name of the old path where the virtualenv existed. This"
    echo "               location does not need to exist."
    echo "  <new_venv> - The path of the virtualenv where links should be repaired."

    exit 1
}


function fix_bad_symlinks(){
    local search_path="$1"
    local old_name="$2"

    info "Fixing symlinks..."
    for symlink in $(find "$search_path" -type l); do
        local value=$(readlink "${symlink}")
        if [[ "$value" == *"$old_name"* ]]; then
            info "Found $symlink pointing $value. Correcting..."
            ln -sTf "${value/$old_name/$search_path}" "$symlink"
        fi

    done
}


function purge_pycs(){
    local search_path="$1"

    info "Purging the following *.pyc files..."
    find "$search_path" -type f -name "*.pyc" -printf "\t%p\n" -exec rm -f {} \;
}


function rename_refs(){
    local old_name=$(rm_trailing_slash "$1")
    local search_path=$(rm_trailing_slash "$2")

    local old_pattern="${old_name}(/|\"|$|')"
    local new_pattern="${search_path}(/|\"|$|')"

    info "Replacing references of ${old_name} with ${search_path}..."

    for file in $(find -P "${search_path}" \! -type l -type f | xargs grep -El "$old_pattern" | xargs grep -lv "$new_pattern"); do
        [[ -L "$file" ]] && continue  # Ignore symlinks.
        info "Updating ${file}"
        sed -i -e "s:${old_name}:${search_path}:g" "$file"
    done
}


function main(){
    [[ "$#" -eq 2 ]] || usage "Invalid number of parameters."

    local old_name="$1"
    local new_venv="$2"

    new_venv=$(abspath "$new_venv")

    old_name=$(add_trailing_slash "$old_name")
    new_venv=$(add_trailing_slash "$new_venv")

    # Simple sanity checks that the path exists and
    # appears to be a virtual env.
    [[ -d "$new_venv" ]] || usage "No such directory: ${new_venv}"
    [[ -f "$new_venv/bin/activate" ]] || usage "Doesn't appear to be a virtualenv: ${new_venv}"

    fix_bad_symlinks "$new_venv" "$old_name"
    purge_pycs "$new_venv"
    rename_refs "$old_name" "$new_venv"

}
main "$@"
