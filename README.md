# Matt Rizzo Devops

Repository containing all things related to CI and devops for any code I develop

## WHY

Because you want a portable way to manage you git environment.

## Install

```bash

curl -SL https://raw.githubusercontent.com/MatthewRizzo/mattrizzo_devops/main/bootstrap.sh | sudo bash

```

This is the equivalent of cloning this repository and running the
[bootstrap.sh](bootstrap.sh) script with `sudo ./bootstrap.sh`.

### Setting Up the pyproject

This is needed in order to setup the virtual environment for pre-commit hooks.

Add to your `pyproject.toml` (or create a new one) this repo as a dependency.
For a full example, please see [pyproject.toml.example](pyproject.toml.example).
The briefest example can be seen below:

```toml
[tool.poetry.dependencies]
python = "^3.10"
mattrizzo-devops = {git = "https://github.com/MatthewRizzo/mattrizzo_devops"}
poetry = "1.2.2"
```

### Setup Utility

To properly setup the hooks, every time you clone a new repository, you'd have
to

1. Re-run `bootstrap.sh --no-root` to see if there are any updates.
2. Run `pre-commit install --hook-type pre-commit --hook-type pre-push`.

This is tedious and repetitive. The perfect usecase of a devops repo!!

To you `.bashrc` (or similar file type), add the following function:

```bash
# Used to alias clone and auto-setup any cloned repo
function git(){
    if [[ $1 == "clone" ]]; then
        # The last arg to clone must be the name
        local -r raw_cloned_dir_name="${@: -1}"
        local -r cloned_dir_name="$(echo ${raw_cloned_dir_name} | cut -d '/' -f2 | cut -d '.' -f1)"
        command git "$@" && (cd ${cloned_dir_name} && pre-commit install --hook-type pre-commit --hook-type pre-push);
    else
        command git "$@";
    fi;
}
```

There is a better version of this, but that requires having cloned this
repository and pathing to [setup_hooks.sh](hooks/setup_hooks.sh) instead.
That is part of [todo](#todo).

## Hook Template

Once you have run `bootstrap.sh`, you'd want to actually start using hooks.
For an example set of templates see the example
[hooks/pre_commit/.pre-commit-config.yaml](hooks/pre_commit/.pre-commit-config.yaml).

Feel free to copy it into your repositories!

## Adding the Python Type Checking

This can be easily done, as is in this repository's
[.pre-commit-config.yaml](.pre-commit-config.yaml).

```yaml
-   repo: local
    hooks:
    -   id: mypy
        name: Python Typing - mypy
        entry: poetry run mypy -p # <package name defined by pyproject.toml>
        language: system
        types: [python]
```

## Adding the markdown linter

```yaml
-   repo: local
    hooks:
    -   id: markdown-linter
        name: markdown-linter
        entry: mdl -s .mdl_ruleset.rb
        language: ruby
        files: \.(md|mdown|markdown)$
        stages: [commit]
```

Define `.mdl_ruleset.rb` at the top level of your repository as follows:

```ruby
all
rule 'MD013', :ignore_code_blocks => true
# Any other rules you want to customize
# See https://github.com/markdownlint/markdownlint/blob/main/docs/RULES.md
```

## TODO

* Refactor `setup_hooks.sh` so a curl command would work like bootsrap.
* Add hook / program to fail a tag if it is > "version" in `pyproject.toml`
* Refine check_rust to use the `Makefile.toml` if it exists at top level of a repo

```bash
function check_rust(){
    local return_code=""
    if [[ ! -f ${repo_top_dir}/Makefile.toml ]]; then
        ${gists_location}/git/hooks/pre_push.d/check-rust.py --cwd ${repo_top_dir}
        return_code=$?
    else
        cargo make all
    fi
    return ${return_code}
}
```

* Bootstrap add check for poetry -> make sure python 3.10 is installed.
  * If not try to install it.
  * Have script specifically install poetry using python3.10
* Add export of path to poetry bin to path (similar to cargo)
