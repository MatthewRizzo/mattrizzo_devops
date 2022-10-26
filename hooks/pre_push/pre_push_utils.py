"""Abstracts common functionality to 1 script that the rest of module uses"""
import os
from pathlib import Path
from git import Repo

def get_repo_top_dir() -> Path:
    """Retrieves the path to the top-level directory of the repository"""
    git_repo = Repo(os.getcwd(), search_parent_directories=True)
    git_root = git_repo.git.rev_parse("--show-toplevel")
    return Path(git_root)
