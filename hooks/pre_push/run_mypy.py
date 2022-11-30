#!/usr/bin/env python
"""Script to check the typing of a python mopdule"""

import argparse
from pathlib import Path
from subprocess import check_output, STDOUT, CalledProcessError


from hooks.pre_push import constants
from hooks.pre_push.pre_push_utils import get_repo_top_dir

constants.SUCCESS_CODE = 0
constants.FAILURE_CODE = 1


def run_mypy(module: str, repo_top_dir: Path, is_verbose: bool) -> int:
    """Runs mypy on the given module and returns if it succeeded or not"""
    try:
        mypy_res = check_output(
            ["mypy", "-p", module], stderr=STDOUT, cwd=repo_top_dir, encoding="utf-8"
        )
        print(mypy_res)
        if mypy_res == constants.FAILURE_CODE:
            if is_verbose:
                print("Failure! mypy reported some errors! ")
            return constants.FAILURE_CODE
        return constants.SUCCESS_CODE
    except CalledProcessError as err:
        print("Mypy Failure!")
        print(err.output)
        return constants.FAILURE_CODE


def check_mypy() -> int:
    """Uses CLI args to run mypy on all given modules"""
    parser = argparse.ArgumentParser()

    repo_top_dir = get_repo_top_dir()
    parser.add_argument(
        "-v",
        "--verbose",
        help="Set to make verbose",
        action="store_true",
        default=False,
    )
    parser.add_argument(
        "-p", "--package", help="The package to run through mypy", type=str, default=""
    )

    # Git push also gives a bunch of other args we don't want
    args, _unknown_args = parser.parse_known_args()

    if args.package == "":
        if args.verbose:
            print("No package given with '-p | --packages'. Skipping this check")
        return constants.SUCCESS_CODE

    overall_res = constants.SUCCESS_CODE
    overall_res &= run_mypy(args.package, repo_top_dir, args.verbose)

    if overall_res == constants.SUCCESS_CODE:
        return constants.SUCCESS_CODE
    return constants.FAILURE_CODE


def main():
    """Entry to script"""
    res = check_mypy()
    raise SystemExit(res)


if __name__ == "__main__":
    main()
