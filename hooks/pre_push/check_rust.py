#!/usr/bin/env python
"""Script responsible for checking the formatting / clippy of all rust
files being pushed to remote."""
from __future__ import annotations
import argparse
import subprocess
from subprocess import check_output, STDOUT, CalledProcessError
import os
from pathlib import Path

from hooks.pre_push import constants
from hooks.pre_push.pre_push_utils import get_repo_top_dir

constants.SUCCESS_CODE = 0
constants.FAILURE_CODE = 1

def is_rust_installed(is_verbose: bool) -> bool:
    """Return's true if rustup and cargo are installed. False otherwise"""
    try:
        cargo_res = check_output(
            ["cargo"],
            stderr=STDOUT,
            encoding='utf-8'
        )
        if cargo_res == constants.FAILURE_CODE:
            return False
        return True
    except CalledProcessError as err:
        if is_verbose:
            print(f"Running cargo failed with:\n{err}")
        return False

def check_rust() -> int:
    """Uses Clippy and cargo fmt to make sure all Rust code is up to standard"""
    parser = argparse.ArgumentParser()

    parser.add_argument("-d", "--cwd",
        help='Path to dir with Cargo.toml',
        type=Path,
        default=get_repo_top_dir())
    parser.add_argument("-v", "--verbose",
        help='Set to make verbose',
        action="store_true",
        default=False)

    # Git push also gives a bunch of other args we don't want
    args, _unknown_args = parser.parse_known_args()

    # Only run if cargo file is here
    path_to_cargo = args.cwd / "Cargo.toml"
    if not os.path.exists(path_to_cargo):
        if args.verbose:
            print("Rust - Skipped! No Cargo.toml file here.")
        return constants.SUCCESS_CODE

    if not is_rust_installed(args.verbose):
        url = "https://raw.githubusercontent.com/MatthewRizzo/mattrizzo_devops/main/bootstrap.sh"
        err_msg = "Rustup and cargo must be installed to run this hook.\n"
        err_msg += "Please run:\n"
        err_msg += f"curl -SL {url} | sudo bash"
        print(err_msg)
        return constants.FAILURE_CODE

    # Force the flush because newline is removed and this is called by bash script
    verbose_msg = "Running Rust linters..................................................."
    if args.verbose:
        print(verbose_msg, end="", flush=True)

    try:
        fmt_res = check_output(
            ["cargo",  "fmt"],
            stderr=STDOUT,
            cwd=args.cwd,
            encoding='utf-8'
        )
        if fmt_res == constants.FAILURE_CODE:
            if args.verbose:
                print("Failure! Cargo fmt made some changes! ")
            return constants.FAILURE_CODE
    except CalledProcessError as err:
        print("Failure!")
        print(err.output)
        return constants.FAILURE_CODE

    try:
        _clippy_res = subprocess.check_output(
            ["cargo",  "clippy"],stderr=STDOUT, cwd=args.cwd
        ).decode('UTF-8').strip()
    except CalledProcessError as err:
        print(f"Failure! {err.output}")
        return constants.FAILURE_CODE

    if args.verbose:
        print("Success!")
    return constants.SUCCESS_CODE

def main():
    """Entry to script"""
    res = check_rust()
    raise SystemExit(res)

if __name__ == "__main__":
    main()
