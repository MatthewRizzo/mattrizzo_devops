# Pre-commit README

The `.pre-commit-config.yaml` in this dir is what gets copied around to other
repos. Make sure to keep it up to date.

## Mypy Package Notes

For the mypy hook, it gets complicated pretty fast. As the hook allows for pass
through, all of the mypy flags can be used. However, as the example indicates,
the easiest to setup with your projects is the -p flag for projects.

The name passed to that flag should be the name of the top level directory with
and `__init__.py` file. All other modules/python files for the project should
by sub-dirs and properly use it as the project root in all subsequent
`__init__.py`'s.
