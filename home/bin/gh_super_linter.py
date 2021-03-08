#!/usr/bin/env python3
"""
Run GitHub's Super-Linter locally using Docker.

{LINTER_NAME} will be pulled and ran. See
<https://github.com/github/super-linter/blob/master/docs/run-linter-locally.md>
for more information.
"""

from collections import namedtuple
from os import getcwd
from typing import Any, Callable, List, Optional

LINTER_NAME = "github/super-linter"  # both GitHub Action and Docker image name
DEFAULT_VERSION = "latest"
CODEBASE_MOUNT = "/tmp/lint"

Setup = namedtuple("SuperLinterSetup", ["path", "job", "step", "img", "env"])


def main():
    parser = get_parser()
    args = parser.parse_args()
    setups = get_superlinter_setups(args.workflow_file, parser.error)
    setup = choose_superlinter_setup(setups)
    run_docker_container(setup, args.codebase_path, args.dry_run)


def get_parser():
    from argparse import ArgumentParser
    from os.path import abspath, isdir

    description, epilog = __doc__.format(**globals()).split("\n\n")
    parser = ArgumentParser(description=description, epilog=epilog)

    def directory_path(value: str) -> str:
        value = abspath(value)
        if not isdir(value):
            parser.error(f"{value} is not a directory")
        return value

    parser.add_argument(
        "codebase_path",
        help=f"""
            this path will mounted as {CODEBASE_MOUNT} in the Docker container;
            defaults to the present working directory, %(default)s
        """,
        nargs="?",
        default=getcwd(),
        type=directory_path,
    )
    parser.add_argument(
        "--workflow-file",
        help="""
            path to the YAML file defining your Super-Linter job so that the
            Docker container can be started with the same version and similar
            environment variables as the real job; omit this to try to
            auto-detect your workflow
        """,
    )
    parser.add_argument(
        "--dry-run",
        help="show how Docker would have been invoked without doing so",
        action="store_true",
    )

    return parser


def get_superlinter_setups(workflow_path: str, error: Callable[[str], Any]):
    from yaml import Loader, load

    setups: List[Setup] = []
    for path in [workflow_path] if workflow_path else get_workflow_paths():
        with open(path) as input:
            for job_id, job_spec in load(input, Loader=Loader)["jobs"].items():
                for step_num, step_spec in enumerate(job_spec["steps"], 1):
                    if img := get_docker_container_image_version(step_spec):
                        env = get_env_without_expressions(step_spec)
                        setup = Setup(str(path), job_id, step_num, img, env)
                        setups.append(setup)

    if workflow_path and not setups:
        error(f"{workflow_path} does not use Super-Linter.")

    return setups


def get_workflow_paths():
    from pathlib import Path

    current = Path(getcwd())

    return (
        path
        for directory in (
            path.joinpath(".github", "workflows")
            for path in [current, *current.parents]
        )
        for paths in [directory.glob("*.yaml"), directory.glob("*.yml")]
        for path in paths
        if path.is_file
    )


def get_docker_container_image_version(step_spec: dict) -> Optional[str]:
    try:
        uses = step_spec["uses"]
    except KeyError:
        pass
    else:
        return (
            DEFAULT_VERSION
            if uses == LINTER_NAME
            else uses.split("@", 1)[1]
            if uses.startswith(f"{LINTER_NAME}@")
            else None
        )


def get_env_without_expressions(step_spec: dict) -> dict:
    try:
        env = step_spec["env"]
    except KeyError:
        return {}
    else:
        return {
            key: value for key, value in env.items() if "${{" not in str(value)
        }


def choose_superlinter_setup(setups: List[Setup]) -> Optional[Setup]:
    if not setups:
        return

    count = len(setups)
    if count == 1:
        return setups[0]

    from sys import stdin, stdout

    is_interactive = stdin.isatty() and stdout.isatty()

    print(
        "Pick which Super-Linter setup to use:"
        if is_interactive
        else "The following Super-Linter setups were found:"
    )
    for number, setup in enumerate(setups, 1):
        print()
        print(f"  #{number:<3}  {setup.path}")
        print(f'        step {setup.step} of "{setup.job}" job on {setup.img}')
        for key, value in setup.env.items():
            print(f"        {key}={value}")
    print()

    if not is_interactive:
        print("Defaulting to the first setup found.")
        return setups[0]

    number = 0
    while not 1 <= number <= count:
        try:
            number = int(input("? "))
        except ValueError:
            pass

    return setups[number - 1]


def run_docker_container(
    setup: Optional[Setup],
    codebase_path: str,
    dry_run: bool,
):
    from shlex import quote
    from subprocess import run

    args = ["docker", "run", "--rm", "--env", "RUN_LOCAL=true"]

    print(f"Mounting {codebase_path} as {CODEBASE_MOUNT} in container.")
    args.extend(["--volume", f"{codebase_path}:{CODEBASE_MOUNT}"])

    if setup:
        print(
            f"Taking environment and container version from step {setup.step} "
            f'in the "{setup.job}" job as specified by {setup.path}.'
        )
        for key, value in setup.env.items():
            args.extend(["--env", f"{key}={get_env_value_as_str(value)}"])
        args.append(f"{LINTER_NAME}:{setup.img}")
    else:
        print(f"Using {DEFAULT_VERSION} Super-Linter without any environment.")
        args.append(f"{LINTER_NAME}:{DEFAULT_VERSION}")

    print()
    print("Would invoke Docker with:" if dry_run else "Starting Docker...")
    print(*map(quote, args))

    if not dry_run:
        print()
        run(args)


def get_env_value_as_str(value) -> str:
    return (
        "true"
        if value is True
        else "false"
        if value is False
        else ""
        if not value
        else str(value)
    )


if __name__ == "__main__":
    main()
