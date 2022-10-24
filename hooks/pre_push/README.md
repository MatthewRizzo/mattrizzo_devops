# Pre Push Directory

This directory implements all the executables relating to the `pre-push` hook.

## Pre-Push Bash Script

This script is symbolically used by every cloned repository. DO NOT put
it in a bad state.

This bash script implements the actual hook that will get triggered by every
push. The script does the following:

* Re runs the entire repository through the `pre-commit` hook checker
* Runs the repository through a Rust checker.
  * If the repository does not have Rust code, the step is skipped.

## Check_rust.py

Checking rust files must be done at the push level. Otherwise, every commit
requires a re-compile through cargo, testing, re-formatting, and clippy.
There are times where this doesn't make sense as it slows development down.
However, this check should be done before any code goes to remote.

This script is responsible for running all `Cargo` / Rust related tests
before allowing the script to go to remote. It will get used by
[pre-push.sh](./pre-push.sh).
