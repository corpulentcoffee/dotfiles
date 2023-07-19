#!/usr/bin/env python3
"""
Run a command after assuming an IAM role.

Your own credentials must have authorization to obtain temporary tokens
from the AWS Security Token Service (STS) for the given role.
"""

from os import environ
from typing import Dict, List, TypedDict, cast

# IAM roles always allow at least one hour, so when a token does have to
# be requested, ask for an hour to increase the likelihood that a future
# aws-as-role invocation will be able to re-use the token. The user can
# push this higher with `--duration-seconds`, but otherwise use an hour.
MIN_DURATION_REQUEST = 3600


def main():
    from time import time

    parser = get_parser()
    args = parser.parse_args()
    credential_cache = get_credential_cache(prog=parser.prog)
    cache_key = get_cache_key(args.role_arn)
    need_credentials_until = time() + args.duration_seconds

    try:
        credentials = credential_cache[cache_key]
        assert need_credentials_until <= credentials["Expiration"]
    except (KeyError, AssertionError):
        credential_cache[cache_key] = credentials = get_credentials(
            profile=args.profile,
            role_arn=args.role_arn,
            session_name=args.session_name,
            serial_number=args.serial_number,
            duration_seconds=max(args.duration_seconds, MIN_DURATION_REQUEST),
        )

    do_spawn(
        access_key_id=credentials["AccessKeyId"],
        secret_access_key=credentials["SecretAccessKey"],
        session_token=credentials["SessionToken"],
        command=args.command,
    )


def get_parser():
    from argparse import ArgumentParser

    # if changing this interface, review aws-as-profile's usage of aws-as-role
    assert type(__doc__) is str, "expecting module-level docstring"
    description, epilog = __doc__.split("\n\n")
    parser = ArgumentParser(description=description, epilog=epilog)
    parser.add_argument(
        "--profile",
        help="""
            use named AWS profile (e.g. "development") for requesting the token
            from STS or omit to use environment variables
        """,
    )
    parser.add_argument(
        "--role-arn",
        help="""
            full ARN of the role you need to assume, e.g.
            arn:aws:iam::123456789012:role/OrganizationAccountAccessRole
        """,
        required=True,
    )
    parser.add_argument(
        "--session-name",
        help="""
            give STS a custom session name when assuming the role, e.g. if you
            need to conform to an IAM policy using an "sts:RoleSessionName"
            condition or want to see it in CloudTrail logs; defaults to
            "%(default)s"
        """,
        default=parser.prog,
    )
    parser.add_argument(
        "--serial-number",
        help="""
            if using multi-factor authentication, the serial number for a
            hardware device or the full ARN for a TOTP-based registration, e.g.
            arn:aws:iam::123456789012:mfa/user123
        """,
    )
    parser.add_argument(
        "--duration-seconds",
        type=int,
        default=600,
        help=f"""
            %(prog)s requests {MIN_DURATION_REQUEST}-second lifespans on tokens
            from STS in order to cache them for future invocations, and this
            option configures how many seconds must be remaining on such cached
            tokens to safely run your command (by default, %(default)s seconds
            must be remaining before needing to request fresh tokens); if the
            value given here is greater than {MIN_DURATION_REQUEST}, %(prog)s
            will use the given value instead of {MIN_DURATION_REQUEST} to
            request a longer lifespan on the tokens from STS (but the role you
            are assuming must be configured to allow a longer session duration)
        """,
    )
    parser.add_argument(
        "command",
        nargs="*",
        help="""
            run this command with temporary credentials obtained from STS after
            assuming the role; if unspecified, defaults to your shell, which is
            currently %(default)s
        """,
        default=[environ["SHELL"]],
    )

    return parser


class StsCredentials(TypedDict):
    AccessKeyId: str
    SecretAccessKey: str
    SessionToken: str
    Expiration: int


def get_credential_cache(prog: str):
    """
    Returns a dict-like object for caching credentials on-disk. This is
    similar to how the AWS CLI does things with `~/.aws/cli/cache/`, but
    unfortunately stored at a different location such that neither tool
    benefits from the other's cache.

    There's another way to cache credentials by overriding the `cache`
    attribute on the `assume-role` provider of the `credential_provider`
    component (see <https://github.com/boto/botocore/pull/1157>), but
    that cannot be leveraged here because

    - we are the ones doing the call to `assume_role()` rather than it
      being called for us by another AWS service client, and
    - we want to be able to inspect the `Expiration` value of what we
      have cached to make sure the caller has the requisite time left.
    """

    from appdirs import user_cache_dir
    from botocore.utils import JSONFileCache

    our_cache_dir = user_cache_dir(appname=prog)  # e.g. ~/.cache/aws-as-role/
    credential_cache = JSONFileCache(working_dir=our_cache_dir)
    return cast(Dict[str, StsCredentials], credential_cache)


def get_cache_key(role_arn: str):
    from hashlib import sha1

    return sha1(role_arn.encode("utf-8")).hexdigest()


def get_credentials(
    profile: str,
    role_arn: str,
    session_name: str,
    serial_number: str,
    duration_seconds: int,
):
    from getpass import getpass

    from boto3 import Session

    session = Session(profile_name=profile)
    sts = session.client("sts")
    assume_role_args = dict(
        RoleArn=role_arn,
        RoleSessionName=session_name,
        DurationSeconds=duration_seconds,
    )
    if serial_number:
        mfa_code = getpass(f"Enter MFA code for {serial_number}: ")
        assume_role_args.update(SerialNumber=serial_number, TokenCode=mfa_code)

    response = sts.assume_role(**assume_role_args)
    credentials = dict(
        response["Credentials"],
        Expiration=response["Credentials"]["Expiration"].timestamp(),
    )
    return cast(StsCredentials, credentials)


def do_spawn(
    access_key_id: str,
    secret_access_key: str,
    session_token: str,
    command: List[str],
):
    from subprocess import run

    # copy current set of environment variables, but clear AWS_PROFILE if set
    # so that the subprocess only sees the new credentials.
    new_environ = dict(environ)
    try:
        del new_environ["AWS_PROFILE"]
    except KeyError:
        pass

    # configure new credentials into environment
    new_environ.update(
        AWS_ACCESS_KEY_ID=access_key_id,
        AWS_SECRET_ACCESS_KEY=secret_access_key,
        AWS_SESSION_TOKEN=session_token,
    )

    run(command, env=new_environ)


if __name__ == "__main__":
    main()
