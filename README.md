# Matt Rizzo Devops

Repository containing all things related to CI and devops for any code I develop

## WHY

Because you want a portable way to manage you git environment.

## Install

All you need to do is run `sudo bootstrap.sh`.

If you are just using the hooks, the python environment) will get
installed for you (assuming you have poetry). If you don't, the boostrap
will take care of that for you.

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
