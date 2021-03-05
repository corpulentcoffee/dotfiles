#!/usr/bin/env python3

from typing import List, Optional, Tuple

AS_ROLE = "aws-as-role"
PROFILE_PATH = "~/.aws/credentials"


def main():
    args = get_parser().parse_args()
    profile_config = get_profile_config()
    destination_config = profile_config[args.profile]
    as_role_command = get_as_role_command(
        source_profile=destination_config["source_profile"],
        destination_role_arn=destination_config["role_arn"],
        session_name=args.session_name,
        serial_number=destination_config.get("mfa_serial"),
        duration_seconds=args.duration_seconds,
        command=args.command,
    )
    do_spawn(as_role_command)


def get_parser():
    from argparse import ArgumentParser, RawDescriptionHelpFormatter
    from os import environ

    description, epilog = get_parser_help()
    parser = ArgumentParser(
        description=description,
        epilog=epilog,
        formatter_class=RawDescriptionHelpFormatter,
    )

    profile_help = """
        destination profile with the role_arn you want to assume using its
        source_profile
    """.strip()
    try:
        default_profile = environ["AWS_PROFILE"].strip()
        assert len(default_profile) > 0
        parser.add_argument(
            "--profile",
            default=default_profile,
            help=f'{profile_help}; defaults to your AWS_PROFILE "%(default)s"',
        )
    except (KeyError, AssertionError):
        parser.add_argument(
            "--profile",
            required=True,
            help=f"{profile_help}; you must set this",
        )

    passed_help = f"passed thru to {AS_ROLE}"
    parser.add_argument("--session-name", help=passed_help)
    parser.add_argument("--duration-seconds", help=passed_help)
    parser.add_argument("command", nargs="*", help=passed_help)

    return parser


def get_parser_help() -> Tuple[str, str]:
    from shutil import get_terminal_size
    from textwrap import dedent, fill, indent

    width = get_terminal_size().columns - 2  # same as argparse HelpFormatter

    def format(text):
        return fill(dedent(text).strip(), width)

    description = f"""
        Use {AS_ROLE} to run a command after assuming a destination profile's
        role_arn via its source_profile as specified by {PROFILE_PATH}. This
        can be helpful for tools that don't implement cross-profile roles but
        do understand AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY/AWS_SESSION_TOKEN
        environment variables.
    """

    epilog_intro = f"""
        You must have an {PROFILE_PATH} similar to this:
    """

    epilog_example = """
        [organization]
        aws_access_key_id = XXX
        aws_secret_access_key = XXX

        [production]
        role_arn = arn:aws:iam::6789012345:role/OrganizationAccountAccessRole
        source_profile = organization
        mfa_serial = arn:aws:iam::1234567890:mfa/username
    """

    epilog_explanation = """
        Here, the "organization" profile has credentials with permission to
        assume the role specified by the destination "production" profile.

        While mfa_serial is optional, both role_arn and source_profile must be
        specified on the destination profile. This script does not support
        credential_source on the destination profile; only source_profile is
        supported.
    """

    epilog_blocks = [
        format(epilog_intro),
        indent(dedent(epilog_example), prefix="  "),
        format(epilog_explanation),
    ]

    return format(description), "\n\n".join(epilog_blocks)


def get_profile_config():
    from configparser import ConfigParser
    from os.path import expanduser

    profile_path = expanduser(PROFILE_PATH)
    profile_config = ConfigParser()
    profile_config.read(profile_path)
    return profile_config


def get_as_role_command(
    source_profile: str,
    destination_role_arn: str,
    session_name: Optional[str],
    serial_number: Optional[str],
    duration_seconds: Optional[str],
    command: List[str],
):
    as_role_command = ["aws-as-role"]
    as_role_command.extend(["--profile", source_profile])
    as_role_command.extend(["--role-arn", destination_role_arn])

    if session_name:
        as_role_command.extend(["--session-name", session_name])
    if serial_number:
        as_role_command.extend(["--serial-number", serial_number])
    if duration_seconds:
        as_role_command.extend(["--duration-seconds", duration_seconds])
    if command:
        as_role_command.extend(["--", *command])

    return as_role_command


def do_spawn(command: List[str]):
    from shlex import quote
    from subprocess import run
    from sys import stderr

    print(*map(quote, command), file=stderr)  # inform user what we're doing
    print(file=stderr)
    run(command)


if __name__ == "__main__":
    main()
