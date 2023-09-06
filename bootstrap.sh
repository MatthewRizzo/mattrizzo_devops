#!/usr/bin/env bash

# Boostraps the git hook process by installing needed dependencies
readonly SCRIPT_DIR_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
readonly SCRIPTPATH="${SCRIPT_DIR_PATH}/bootstrap.sh"
readonly REPO_TOP_DIR="$(realpath ${SCRIPT_DIR_PATH})"

# Set in main
RUN_PREFIX=""
SUDO_USER=""

readonly PYTHON_VERSION="3.10"
readonly PYTHON="python${PYTHON_VERSION}"

# Don't make a dependency file because I want this script to be self-contained
declare -a DEPENDECY_LIST=(
    plantuml
    software-properties-common
    ruby
    gh
    gem
    pre-commit=2.17.0-1
    python${PYTHON_VERSION}
    keychain
    python3.10 # MUST be AFTER software-properties
    python3.10-dev
    python3.10-venv
)

function usage {
    cat << EOF
$(basename "${0}"): Bootstraps the devops environment
General: sudo ./$(basename "${0}") [Optional]
    This is how you should run the script unless you are installing JUST --no-sudo.
Run Sudo Bootstrap: ./$(basename "${0}") --sudo-user=username

Setup pre-commit: ./$(basename "${0}") --no-sudo

Required Args:
    None
Optional Args:
    --sudo-user: REQUIRED IF SUDO. This is the name of the user ELEVATED to sudo.
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
# $2 = verbose. Set to true for more details. Defaults to not being verbose.
function run_cmd_as_user(){
    local -r command_to_run="$1"
    local -r verbose="$2"

    echo "${command_to_run}"
    if [[ ${verbose} == true ]]; then
        echo "Full Command: ${RUN_PREFIX}='${command_to_run}'"
    fi
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

# $1 = sudo allowed
function install_python() {
    local -r sudo_allowed=$1
    if [[ $(command -v ${PYTHON} &> /dev/null) == 1 ]]; then
        echo "python not installed"
        local -r curl_cmd="curl -sSL https://bootstrap.pypa.io/get-pip.py"
        local -r install_script_cmd="python3.10"
        local -r install_cmd="${curl_cmd} | ${install_script_cmd}"
        if [[ ${sudo_allowed} == true ]]; then
            run_cmd_as_user "${install_cmd}"
        else
            echo "${curl_cmd} | ${install_script_cmd}"
            ${curl_cmd} | ${install_script_cmd}
        fi
    fi
}

# Check's if a python3.10 is installed. Installs it if it isn't
# $1 = sudo_allowed
function check_python_version(){
    local -r sudo_allowed=$1
    if ! command -v ${PYTHON} > /dev/null; then
        echo "${PYTHON} not installed. Installing it!"
    fi
    install_python ${sudo_allowed}
}

# Adding pip and poetry to path is necessary for it to work
# Check if the path is already added, if not, add an source for it in
# ~/.bashrc
# $1 = user
function add_local_to_path() {
    local -r user=$1
    local -r path_to_add="/home/${user}/.local/bin/"
local -r cmd_to_print=$(cat <<END_HEREDOC

PATH="\$PATH:$path_to_add"
END_HEREDOC
)
    if ! echo "$PATH" | /bin/grep -Eq "(^|:)${path_to_add}($|:)" ; then
        echo "Adding ${path_to_add} to path"
        echo "$cmd_to_print" >> /home/${user}/.bashrc
        source /home/${user}/.bashrc
    fi
}


# $1 = sudo_allowed. true = sudoer. false = regular user.
# $2 = user - the name of the actual user
# Return - The current poetry version (if it is installed)
function get_current_poetry_version() {
    local -r sudo_allowed=$1
    local -r user=$2
    local -r expected_poetry_loc="/home/${user}/.local/bin/poetry"
    local -r get_poetry_version_cmd="${PYTHON} -m poetry --version --no-ansi"
    local raw_actual_poetry_version=""

    if [[ ! -f ${expected_poetry_loc} ]]; then
        echo "Poetry is not installed!"
        return
    fi


    if [[ ${sudo_allowed} == true ]]; then
        raw_actual_poetry_version=$(run_cmd_as_user "${get_poetry_version_cmd}" true)
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

    curl_cmd="curl -sSL https://install.python-poetry.org"
    install_script_cmd="${PYTHON} - --version 1.2.2"

    # https://python-poetry.org/docs/
    # local -r install_cmd="${PYTHON} -m pip install --user poetry==1.2.2"
    local -r install_cmd="${curl_cmd} | ${install_script_cmd}"
    if [[ ${sudo_allowed} == true ]]; then
        run_cmd_as_user "${install_cmd}"
    else
        echo "${curl_cmd} | bash -c \"${install_script_cmd}\""
        ${curl_cmd} | bash -c "${install_script_cmd}"

        if ! command poetry &> /dev/null; then
            add_local_to_path ${user}
        fi
    fi
}

# Some python packages must be installed via pip
# $1 = sudo_allowed. true = sudoer. false = regular user.
# $2 = user - the name of the actual user
function install_python_dep() {
    local -r sudo_allowed=$1
    local -r user=$2
    check_python_version ${sudo_allowed}

    install_poetry ${sudo_allowed} ${user}

    local -r setup_poetry_config="poetry config --ansi virtualenvs.in-project true"
    if [[ ${sudo_allowed} == true ]]; then
        run_cmd_as_user "${PYTHON} -m ${setup_poetry_config}"
        # Sudo shouldnt be adding to a user's path
        echo -e "\n-----------------------------------------"
        echo "Make sure to add poetry to the local path. "
        echo "Or rerun ./bootstrap --no-sudo"
        echo -e "-----------------------------------------\n"
    else
        ${setup_poetry_config}
        add_local_to_path ${user}
    fi
}

# Adding Rust (Cargo) to path is necessary for it to work
# Check if the path is already added, if not, add an source for it in
# ~/.bashrc
# $1 = user
function add_rust_to_path() {
    local -r user=$1
local -r cmd_to_print=$(cat <<END_HEREDOC

if [[ -f "/home/$user/.cargo/env" ]]; then
    source "/home/$user/.cargo/env"
fi
END_HEREDOC
)
if ! grep -q -w ".cargo/env" /home/$user/.bashrc; then
    echo "Adding cargo to path"
    echo "$cmd_to_print" >> /home/${user}/.bashrc
fi
}

# $1 = user
function install_rust_deps() {
    local -r user=$1
    if [[ -f "$HOME/.cargo/env" ]]; then
        source "$HOME/.cargo/env"
    fi

    if ! command -v cargo rustup > /dev/null ; then
        # https://doc.rust-lang.org/cargo/getting-started/installation.html
        local -r rustup_url="https://sh.rustup.rs"
        echo "Installing Rust ${rustup_url}"
        curl ${rustup_url} -sSf | sh -s -- -y
    fi
    add_rust_to_path ${user}
    source "${HOME}/.cargo/env"
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
        sudo add-apt-repository ppa:deadsnakes/ppa --yes
        sudo ${pkg_manager} install -y "${DEPENDECY_LIST[@]}"

        # Need Ruby package manager to get mdl - markdown linter
        install_mdl
    fi

    local user=${USER}
    if [[ ${sudo_allowed} == true ]]; then
        user=${SUDO_USER}
    fi

    install_rust_deps ${user}
    install_python_dep ${sudo_allowed} ${user}
}

# $2 = sudo_allowed. true = sudoer. false = regular user.
function create_venv() {
    local -r sudo_allowed=$1
    create_poetry_venv_cmd="poetry install"
    if [[ ${sudo_allowed} == true ]]; then
        run_cmd_as_user "${PYTHON} -m ${create_poetry_venv_cmd}"
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
            "--sudo-user="* )
                SUDO_USER="${arg#*=}"
                shift
                ;;
            * )
                echo -e >&2 "Unexpected argument: ${arg}\n";
                usage
                exit 1
                ;;
        esac
    done

    # MUST get set here
    # Sudo related constants
    ORIGINAL_USER=${SUDO_USER}
    RUN_PREFIX="sudo runuser ${ORIGINAL_USER} --command"

    if [[ $sudo_allowed == true && "$ORIGINAL_USER" == "" ]]; then
        echo "The --sudo-user=<username> flag MUST be set when running with sudo"
        exit 1
    fi

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
