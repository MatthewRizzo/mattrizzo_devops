# Matt Rizzo Devops

Repository containing all things related to CI and devops for any code I develop

## WHY

Because you want a portable way to manage you git environment.

## Install

Run `sudo bootstrap.sh`.

Add to your `pyproject.toml` (or create a new one) the dependency of this repo.
A full example, please see [pyproject.toml.example](pyproject.toml.example).
The briefest example can be seen below:

```toml
[tool.poetry.dependencies]
python = "^3.10"
mattrizzo-devops = {git = "https://github.com/MatthewRizzo/mattrizzo_devops"}
```

## Adding the Python Type Checking

This can be easily done, as is in this repository's
[.pre-commit-config.yaml](.pre-commit-config.yaml).

```yaml
    -   id: mypy
        name: Python Typing - mypy
        entry: poetry run mypy -p # <package name defined by pyproject.toml>
        language: system
        types: [python]
```

## TODO

* Get the install of pre-push hooks through
    [setup_hooks.sh](hooks/pre_push/README.md) to work.
* Move all non-system dependencies into the proper dependency file
  * i.e. take poetry version out of [bootstrap.sh](bootstrap.sh)
* Add a python typing hook
