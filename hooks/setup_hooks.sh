#!/usr/bin/env bash

# Script responsible for setting up hooks in a given respository
SCRIPTPATH=""
if [[ "$0" == *"/usr/bin"* ]]; then
    # Script is being sourced
    SCRIPTPATH="$( cd -- "$(dirname "${BASH_SOURCE}")" >/dev/null 2>&1 ; pwd -P )"
else
    # Script is being executed
    SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
fi
DEVOPS_TOP_DIR="$(cd ${SCRIPTPATH} && git rev-parse --show-toplevel 2> /dev/null)"

function copy_pre_commit_config() {
    local cwd=""
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: copy_pre_commit_config <work_dir>: copies the rust pre commit config to your current directory."
        echo "If it already exists, the rust specific part is just added to the file and then git-ignored."
        echo "Otherwise, the entire config is added and added to local exclude file"
        return
    elif [[ "$1" != "" ]]; then
        cwd="$1"
    else
        cwd="$PWD"
    fi

    local -r default_config_name=".pre-commit-config.yaml"
    local -r gists_config_dir="${gists_location}/git/hooks/pre_commit"
    local -r repo_top_dir="$(git rev-parse --show-toplevel)"
    local -r repo_git_dir="${repo_top_dir}/.git"
    local -r repo_exlude_file="${repo_git_dir}/info/exclude"

    local -r abs_path_new_config_file=${repo_top_dir}/${default_config_name}

    if [ -f ${abs_path_new_config_file} ]; then
        echo -n ""
    else
        new_config_full_path=${repo_top_dir}/${default_config_name}
        echo "abs_path_new_config_file = ${new_config_full_path}"
        cp ${gists_config_dir}/${default_config_name} ${new_config_full_path}

        # Add this new file to the excludes for the repo
        echo -e "\n${abs_path_new_config_file}" >> ${repo_exlude_file}
    fi
}

# $1 = top level dir of repo
function setup_pre_commit() {
    local -r repo_top_dir="$1"
    copy_pre_commit_config ${repo_top_dir}
    pre-commit install
}

# $1 = top level dir of repo
function setup_pre_push(){
    local -r repo_top_dir="$1"

    (cd ${repo_top_dir} && pre-commit install --hook-type pre-push)

}

function setup_cloned_repo() {
    local -r usage="Usage: setup_cloned_repo: Sets up a newly cloned repo for pre-commit. \nMUST BE RUN WITHIN THE REPO"
    local -r repo_top_dir="$(git rev-parse --show-toplevel 2> /dev/null)"
    if [ "${repo_top_dir}" == "" ]; then
        echo -e ${usage}
        return 1
    fi


    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo -e ${usage}
        return
    fi

    setup_pre_commit "${repo_top_dir}"

    setup_pre_push "${repo_top_dir}"
}

function run_bootstrap() {
    (cd "${DEVOPS_TOP_DIR}" && ./bootstrap.sh)
}

function main() {
    run_bootstrap
    setup_cloned_repo
}

main
