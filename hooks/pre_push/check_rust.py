#!/usr/bin/env python
"""Script responsible for checking the formatting / clippy of all rust
files being pushed to remote."""
from __future__ import annotations
import argparse
import subprocess
from subprocess import check_output, STDOUT, CalledProcessError
import os
from pathlib import Path
from git import Repo

SUCCESS_CODE = 0
FAILURE_CODE = 1

def get_repo_top_dir() -> Path:
    """Retrieves the path to the top-level directory of the repository"""
    git_repo = Repo(os.getcwd(), search_parent_directories=True)
    git_root = git_repo.git.rev_parse("--show-toplevel")
    return Path(git_root)

def is_rust_installed(is_verbose: bool) -> bool:
    """Return's true if rustup and cargo are installed. False otherwise"""
    try:
        cargo_res = check_output(
            ["cargo"],
            stderr=STDOUT,
            encoding='utf-8'
        )
        if cargo_res == FAILURE_CODE:
            return False
    except CalledProcessError as err:
        if is_verbose:
            print(f"Running cargo failed with:\n{err}")
        return False

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
        return SUCCESS_CODE

    if not is_rust_installed(args.verbose):
        err_msg="Rustup and cargo must be installed to run this hook.\n"
        err_msg+="Please download"
        err_msg+="https://github.com/MatthewRizzo/mattrizzo_devops/blob/main/bootstrap.sh"
        err_msg+="\nThen run sudo ./boostrap.sh"
        print(err_msg)
        return FAILURE_CODE

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
        if fmt_res == FAILURE_CODE:
            if args.verbose:
                print("Failure! Cargo fmt made some changes! ")
            return FAILURE_CODE
    except CalledProcessError as err:
        print("Failure!")
        print(err.output)
        return FAILURE_CODE

    try:
        _clippy_res = subprocess.check_output(
            ["cargo",  "clippy"],stderr=STDOUT, cwd=args.cwd
        ).decode('UTF-8').strip()
    except CalledProcessError as err:
        print(f"Failure! {err.output}")
        return FAILURE_CODE

    print("Success!")
    return SUCCESS_CODE

def main():
    """Entry to script"""
    res = check_rust()
    print(f"res = {res}")
    raise SystemExit(res)
