#!/usr/bin/env bash
# DO NOT MODIFY THIS SCRIPT IF IN A .git/ DIR.
# THIS IS SYMBOLICALLY LINKED FROM mattrizzo_devops.
# USE setup_cloned_repo TO COPY THE SCRIPT FROM mattrizzo_devops/hooks/pre_push/pre-push.sh

#### Inspired by pre-commit template
INSTALL_PYTHON=/usr/bin/python
ARGS=(hook-impl --config=.pre-commit-config.yaml --hook-type=pre-push)
# end templated

HERE="$(cd "$(dirname "$0")" && pwd)"
ARGS+=(--hook-dir "$HERE" -- "$@")

####################################

repo_top_dir="$(git rev-parse --show-toplevel 2> /dev/null)"

function check_rust(){
    ${gists_location}/git/hooks/pre_push/check_rust.py \
        --cwd ${repo_top_dir} \
        --verbose
    local -r return_code=$?
    return ${return_code}
}

function rerun_commit_check() {
    echo "Running Pre Commit Again"
    pre-commit run --all-files --hook-stage push

    local -r return_code=$?
    return ${return_code}
}

function main() {
    exit_code=0

    check_rust
    ((exit_code|=$?))

    rerun_commit_check
    ((exit_code|=$?))

    exit $exit_code

    # TODO: add checker for C, C++, pylint
}


main
