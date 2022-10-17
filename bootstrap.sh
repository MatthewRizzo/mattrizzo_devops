#!/usr/bin/env bash

# Boostraps the git hook process by installing needed dependencies
readonly SCRIPT_DIR_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
readonly SCRIPTPATH="${SCRIPT_DIR_PATH}/bootstrap.sh"
readonly REPO_TOP_DIR="$(realpath ${SCRIPT_DIR_PATH})"

# Sudo related constants
readonly ORIGINAL_USER=${SUDO_USER}
readonly RUN_PREFIX="sudo runuser ${ORIGINAL_USER} --command"

# $1 = The package to install (if it isn't already)
function check_if_sudo(){
    local -r pkg_to_install=$1
    if [ "$EUID" -ne 0 ]; then
        if [[ "${pkg_to_install}" != "" ]]; then
            echo "Missing dependency: ${pkg_to_install}."
            echo -e "\nThe bootstrap script MUST be run as root to install it."
        else
            echo -e "\nThe bootstrap script MUST be run as root."
        fi
        echo -e "Please run sudo ${SCRIPTPATH}\n"
        exit
    fi
}

# There are packages / modules which MUST be installed at the user level
# As this script MUST also be a sudoer for system level installs, this causes
#   and issue.
# Using the runuser command, it is possible to run commands at the user
#   level again.
# $1 = command_to_run
function run_cmd_as_user(){
    local -r command_to_run="$1"

    local -r expected_poetry_loc="/home/${ORIGINAL_USER}/.local/bin/poetry"

    echo "${command_to_run}"
    ${RUN_PREFIX}="${command_to_run}"
}


# Packages versions according to the manager != --version
# $1 = pkg_name
# Return - via echo. Make sure to capture it.
function get_installed_version() {
    local -r pkg_name=$1
    local -r version=$(dpkg -s ${pkg_name} | grep Version | cut -d ' ' -f2 )
    echo ${version}

}

# $1 = The package to install (if it isn't already)
# $2 = The version to install (as defined by system package manager)
#      If "default", don't check/specify a version when installing
# $3 = The system package manager
function install_pkg(){
    local -r pkg_to_install=$1
    local -r version=$2
    local -r pkg_manager=$3

    local -r is_installed=$(command -v ${pkg_to_install} &> /dev/null)

    if ! command -v ${pkg_to_install} &> /dev/null; then
        check_if_sudo ${pkg_to_install}
        if [[ "${version}" == "default" ]]; then
            sudo ${pkg_manager} install -y ${pkg_to_install}
        else
            sudo ${pkg_manager} install -y ${pkg_to_install}=${version}
        fi
    # Make sure version is right
    else
        local -r current_version=$(get_installed_version ${pkg_to_install})
        if [[ "${version}" != "default" && "${current_version}" != ${version} ]]; then
            sudo ${pkg_manager} remove -y ${pkg_to_install}
            sudo ${pkg_manager} install -y ${pkg_to_install}=${version}
        fi
    fi

}


# mdl must be installed using gem
# https://github.com/markdownlint/markdownlint
function install_mdl(){
    if ! command -v mdl &> /dev/null
    then
        echo "gem install mdl"
        sudo gem install mdl
    fi

}

function install_poetry()
{
    # TODO: move this to a file
    local -r expected_poetry_version="1.2.2"

    # Release sudo for this to work -> become user again
    local -r original_user=${SUDO_USER}
    local -r expected_poetry_loc="/home/${original_user}/.local/bin/poetry"

    local actual_poetry_version=""
    if [[ -f ${expected_poetry_loc} ]]; then
        local -r get_poetry_version="python -m poetry --version --no-ansi"
        actual_poetry_version=$(run_cmd_as_user "${get_poetry_version}")
        actual_poetry_version="$(echo ${actual_poetry_version} | sed -e  's/.*(version\(.*\)*./\1/' )"
        actual_poetry_version="$(echo ${actual_poetry_version} | tr -d ' \t\n\r ' )"
    fi

    local -r uninstall_poetry_cmd="python -m pip uninstall -y poetry"
    local -r install_poetry_cmd="python -m pip install poetry==${expected_poetry_version}"
    local -r setup_poetry_config="python -m poetry config --ansi virtualenvs.in-project true"


    if [[ "${actual_poetry_version}" != "${expected_poetry_version}" ]];
    then
        echo "Poetry version mismatch!"
        echo "Expected: ${expected_poetry_version}. Actual: ${actual_poetry_version}"
        echo "Installing the correct version."
        run_cmd_as_user "${uninstall_poetry_cmd}"
        run_cmd_as_user "${install_poetry_cmd}"
    else
        echo "Poetry is installed correctly"
    fi
manual
    run_cmd_as_user "${setup_poetry_config}"

}

# Some python packages must be installed via pip
function install_python_dep() {
    install_poetry
}

function install_rust_deps() {
    if [[ -f "$HOME/.cargo/env" ]]; then
        source "$HOME/.cargo/env"
    fi

    if ! command -v cargo rustup > /dev/null ; then
        # https://doc.rust-lang.org/cargo/getting-started/installation.html
        local -r rustup_url="https://sh.rustup.rs"
        echo "Installing Rust ${rustup_url}"
        # curl ${rustup_url} -sSf | sh
        source "$HOME/.cargo/env"
    fi
}

# $1 = pkg_manager - the pkg manager of the system
function check_dependencies() {
    local -r pkg_manager=$1
    local -r dependencies_file="${REPO_TOP_DIR}/dependencies.txt"

    cat ${dependencies_file} | while read pkg version
    do
        install_pkg ${pkg} ${version} ${pkg_manager}

        if [[ "${pkg}" == "gh" ]]; then
            echo "Please run: gh auth login"
        fi
    done

    install_rust_deps
    install_python_dep

    # Need Ruby package manager to get mdl - markdown linter
    install_mdl
}

function create_venv() {
#    python -m poetry install
    # local -r poetry_path="$HOME/.local/bin/poetry"

    run_cmd_as_user "python -m poetry install"
}

function main() {
    check_if_sudo
    
    local pkg_manager=""
    if [ -x "$(command -v apt)" ]; then pkg_manager="apt"
    elif [ -x "$(command -v dnf)" ];     then pkg_manager="dnf"
    fi

    check_dependencies ${pkg_manager}

    local -r bashrc_loc="$HOME/.bashrc"
    if [[ -f ${bashrc_loc} ]]; then
        source "${bashrc_loc}"
    fi

    create_venv
}

main
