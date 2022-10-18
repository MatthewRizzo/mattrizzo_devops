# Matt Rizzo Devops

Repository containing all things related to CI and devops for any code I develop

## WHY

Because you want a portable way to manage you git environment.

## Install

Run `sudo ./bootstrap.sh`.

Add to your `pyproject.toml` (or create a new one) this repo as a dependency.
For a full example, please see [pyproject.toml.example](pyproject.toml.example).
The briefest example can be seen below:

```toml
[tool.poetry.dependencies]
python = "^3.10"
mattrizzo-devops = {git = "https://github.com/MatthewRizzo/mattrizzo_devops"}
```

## Hook Template

Once you have run `bootstrap.sh`, you'd want to actually start using hooks.
For an example set of templates see the example
[hooks/pre_commit/.pre-commit-config.yaml](hooks/pre_commit/.pre-commit-config.yaml).

Feel free to copy it into your repositories!

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

* Add a hook that acts as a boostrap
   * curl's the bootstrap script
   * tells the user to run it as sudo
