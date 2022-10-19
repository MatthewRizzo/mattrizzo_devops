#!/usr/bin/env bash

# Boostraps the git hook process by installing needed dependencies
readonly SCRIPT_DIR_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
readonly SCRIPTPATH="${SCRIPT_DIR_PATH}/bootstrap.sh"
readonly REPO_TOP_DIR="$(realpath ${SCRIPT_DIR_PATH})"

# Sudo related constants
readonly ORIGINAL_USER=${SUDO_USER}
readonly RUN_PREFIX="sudo runuser ${ORIGINAL_USER} --command"

# Don't make a dependency file because I want this script to be self-contained
declare -a DEPENDECY_LIST=(
    ruby
    gh
    pre-commit=2.17.0-1

)

function usage {
    cat << EOF
$(basename "${0}"): Bootstraps the devops environment
General: sudo ./$(basename "${0}") [Optional]
    This is how you should run the script unless you are installing JUST --no-sudo.
Setup pre-commit: ./$(basename "${0}") --no-sudo

Required Args:
    None
Optional Args:
    --no-sudo: Set this flag if you are setting up pre-commit.
        You are guaranteeing NO command requiring sudo will be executed.
    -h | --help: Print this message
EOF
}

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
        echo -e "Please run \tsudo .${SCRIPTPATH}"
        echo -e "Or \t\t.${SCRIPTPATH} --help\n"
        exit
    fi
}

# There are packages / modules which MUST be installed at the user level
# As this script is often also a sudoer for system level installs, this causes
#   an issue.
# Using the runuser command, it is possible to run commands at the user
#   level again.
# $1 = command_to_run
function run_cmd_as_user(){
    local -r command_to_run="$1"

    echo "Short Command: ${command_to_run}"
    echo "Full Command: ${RUN_PREFIX}='${command_to_run}'"
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
            check_if_sudo ${pkg_to_install}
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
        check_if_sudo "mdl via gem"
        echo "gem install mdl"
        sudo gem install mdl
    fi

}

# $1 = sudo_allowed. true = sudoer. false = regular user.
# $2 = user - the name of the actual user
# Return - The current poetry version (if it is installed)
function get_current_poetry_version() {
    local -r sudo_allowed=$1
    local -r user=$2
    local -r expected_poetry_loc="/home/${user}/.local/bin/poetry"
    local -r get_poetry_version_cmd="python -m poetry --version --no-ansi"
    local raw_actual_poetry_version=""

    if [[ ! -f ${expected_poetry_loc} ]]; then
        echo "Poetry is not installed!"
        return
    fi


    if [[ ${sudo_allowed} == true ]]; then
        raw_actual_poetry_version=$(run_cmd_as_user "${get_poetry_version_cmd}")
    else
        raw_actual_poetry_version=$(${get_poetry_version_cmd})
    fi

    # Trim down the version to what we care about
    local actual_poetry_version="$(echo ${raw_actual_poetry_version} | sed -e  's/.*(version\(.*\)*./\1/' )"
    actual_poetry_version="$(echo ${actual_poetry_version} | tr -d ' \t\n\r ' )"
    echo "${actual_poetry_version}"
}

# $1 = sudo_allowed. true = sudoer. false = regular user.
# $2 = user - the name of the actual user
function install_poetry()
{
    local -r sudo_allowed=$1
    local -r user=$2
    local -r expected_poetry_version="1.2.2"

    # https://python-poetry.org/docs/
    local -r curl_cmd="curl -sSL https://install.python-poetry.org"
    local -r install_script_cmd="python3 - --version ${expected_poetry_version}"
    local -r install_cmd="${curl_cmd} | ${install_script_cmd}"
    if [[ ${sudo_allowed} == true ]]; then
        run_cmd_as_user "${install_cmd}"
    else
        ${curl_cmd} | ${install_script_cmd}
    fi
}

# Some python packages must be installed via pip
# $1 = sudo_allowed. true = sudoer. false = regular user.
# $2 = user - the name of the actual user
function install_python_dep() {
    local -r sudo_allowed=$1
    local -r user=$2
    install_poetry ${sudo_allowed}

    local -r setup_poetry_config="poetry config --ansi virtualenvs.in-project true"
    if [[ ${sudo_allowed} == true ]]; then
        run_cmd_as_user "python -m ${setup_poetry_config}"
    else
        ${setup_poetry_config}
    fi
}

function install_rust_deps() {
    if [[ -f "$HOME/.cargo/env" ]]; then
        source "$HOME/.cargo/env"
    fi

    if ! command -v cargo rustup > /dev/null ; then
        # https://doc.rust-lang.org/cargo/getting-started/installation.html
        local -r rustup_url="https://sh.rustup.rs"
        echo "Installing Rust ${rustup_url}"
        curl ${rustup_url} -sSf | sh
        source "$HOME/.cargo/env"
    fi
}

# $1 = pkg_manager - the pkg manager of the system
# $2 = sudo_allowed. true = sudoer. false = regular user.
function check_dependencies() {
    local -r pkg_manager=$1
    local -r sudo_allowed=$2
    local -r dependencies_file="${REPO_TOP_DIR}/dependencies.txt"
    local -r dependencies=


    if [[ ${sudo_allowed} == true ]]; then
        check_if_sudo
        sudo ${pkg_manager} install -y "${DEPENDECY_LIST[@]}"

        # Need Ruby package manager to get mdl - markdown linter
        install_mdl
    fi

    local user=${USER}
    if [[ ${sudo_allowed} == true ]]; then
        user=${SUDO_USER}
    fi

    install_rust_deps
    install_python_dep ${sudo_allowed} ${user}
}

# $2 = sudo_allowed. true = sudoer. false = regular user.
function create_venv() {
    local -r sudo_allowed=$1
    create_poetry_venv_cmd="poetry install"
    if [[ ${sudo_allowed} == true ]]; then
        run_cmd_as_user "python -m ${create_poetry_venv_cmd}"
    else
        ${create_poetry_venv_cmd}
    fi
}

# Args: all args from script entry = "$@"
function main() {
    local sudo_allowed=true

    while [[ $# -gt 0 ]]; do
        arg="$1";
        shift;
        case ${arg} in
            "-h" | "--help")
                usage
                exit
                ;;
            "--no-sudo" )
                sudo_allowed="false"
                shift
                ;;
            * )
                echo -e >&2 "Unexpected argument: ${arg}\n";
                usage
                exit 1
                ;;
        esac
    done

    local pkg_manager=""
    if [ -x "$(command -v apt)" ]; then pkg_manager="apt"
    elif [ -x "$(command -v dnf)" ];     then pkg_manager="dnf"
    fi

    check_dependencies ${pkg_manager} ${sudo_allowed}

    local -r bashrc_loc="$HOME/.bashrc"
    if [[ -f ${bashrc_loc} ]]; then
        source "${bashrc_loc}"
    fi

    create_venv ${sudo_allowed}
}

main "$@"
