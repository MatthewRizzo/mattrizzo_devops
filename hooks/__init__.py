"""init for the hooks module"""
import hooks.pre_push.check_rust
import hooks.pre_push.run_mypy

# pylint: disable=redefined-builtin
all = [
    "check_rust",
    "run_mypy"
]
