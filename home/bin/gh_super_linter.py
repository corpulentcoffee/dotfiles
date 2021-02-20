#!/usr/bin/env python3

from collections import namedtuple
from os import getcwd
from typing import List, Optional

DOCKER_IMAGE_NAME = "github/super-linter:latest"
CODEBASE_MOUNT = "/tmp/lint"

Setup = namedtuple("SuperLinterSetup", ["path", "job_id", "step_num", "env"])


def main():
    args = get_parser().parse_args()
    setups = get_superlinter_setups(args.workflow_file)
    setup = choose_superlinter_setup(setups)
    run_docker_container(setup, args.codebase_path, args.dry_run)


def get_parser():
    from argparse import ArgumentParser

    parser = ArgumentParser(
        description="Run GitHub's Super-Linter locally using Docker.",
        epilog=f"""
            {DOCKER_IMAGE_NAME} will be pulled and ran. See
            <https://github.com/github/super-linter/blob/master/docs/run-linter-locally.md>
            for more information.
        """,
    )
    parser.add_argument(
        "--codebase-path",
        help=f"""
            this path will mounted as {CODEBASE_MOUNT} in the Docker container;
            defaults to the present working directory, %(default)s
        """,
        default=getcwd(),
    )
    parser.add_argument(
        "--workflow-file",
        help="""
            path to the YAML file defining your Super-Linter job so that the
            Docker container can be started with similar environment variables
            as the real job, or omit this to try to auto-detect your workflow
        """,
    )
    parser.add_argument(
        "--dry-run",
        help="show how Docker would have been invoked without doing so",
        action="store_true",
    )

    return parser


def get_superlinter_setups(workflow_path):
    from yaml import Loader, load

    setups: List[Setup] = []
    for path in [workflow_path] if workflow_path else get_workflow_paths():
        with open(path) as input:
            for job_id, job_spec in load(input, Loader=Loader)["jobs"].items():
                for step_num, step_spec in enumerate(job_spec["steps"], 1):
                    try:
                        if step_spec["uses"].startswith("github/super-linter"):
                            env = get_env_without_expressions(step_spec["env"])
                            if env:
                                setup = Setup(str(path), job_id, step_num, env)
                                setups.append(setup)
                    except KeyError:
                        pass
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


def get_env_without_expressions(env: dict) -> dict:
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
        print(f'        step {setup.step_num} of "{setup.job_id}" job')
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
    from os.path import abspath
    from shlex import quote
    from subprocess import run

    args = ["docker", "run", "--rm", "--env", "RUN_LOCAL=true"]

    if setup:
        print(
            f"Taking environment from step {setup.step_num} in the "
            f'"{setup.job_id}" job as specified by {setup.path}.'
        )
        for key, value in setup.env.items():
            args.extend(["--env", f"{key}={get_env_value_as_str(value)}"])

    codebase_path = abspath(codebase_path)
    print(f"Mounting {codebase_path} as {CODEBASE_MOUNT} in container.")
    args.extend(["--volume", f"{codebase_path}:{CODEBASE_MOUNT}"])

    print(f"Using {DOCKER_IMAGE_NAME} as container image.")
    args.append(DOCKER_IMAGE_NAME)

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
