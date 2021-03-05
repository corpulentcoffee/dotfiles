#!/usr/bin/env python3

from typing import Tuple

AS_ROLE = "aws-as-role"
PROFILE_PATH = "~/.aws/credentials"


def main():
    args = get_parser().parse_args()
    profile_config = get_profile_config()
    destination_config = profile_config[args.profile]
    destination_role_arn = destination_config["role_arn"]
    source_profile_name = destination_config["source_profile"]
    print(destination_role_arn, "via", source_profile_name)


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
        parser.add_argument(
            "--profile",
            default=environ["AWS_PROFILE"],
            help=f"{profile_help}; defaults to AWS_PROFILE (%(default)s)",
        )
    except KeyError:
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
    from textwrap import dedent, fill

    width = get_terminal_size().columns - 2  # same as argparse HelpFormatter
    format = lambda text: fill(dedent(text).strip(), width)

    description = f"""
        Use {AS_ROLE} to run a command using the role_arn and source_profile
        specified by an {PROFILE_PATH} profile.
    """

    epilog_intro = f"""
        You must have an {PROFILE_PATH} similar to this:
    """

    epilog_example = f"""
        [organization]
        aws_access_key_id = XXX
        aws_secret_access_key = XXX

        [production]
        role_arn = arn:aws:iam::6789012345:role/OrganizationAccountAccessRole
        source_profile = organization
        mfa_serial = arn:aws:iam::1234567890:mfa/username
    """

    epilog_explanation = f"""
        Here, the "organization" profile has credentials with permission to
        assume the role specified by the destination "production" profile.

        While mfa_serial is optional, both role_arn and source_profile must be
        specified on the destination profile. This script does not support
        credential_source on the destination profile; only source_profile is
        supported.
    """

    epilog_blocks = [
        format(epilog_intro),
        dedent(epilog_example),
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


if __name__ == "__main__":
    main()
