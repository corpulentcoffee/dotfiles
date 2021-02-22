#!/usr/bin/env python3

from sys import stderr

from boto3 import Session


def main():
    from shlex import quote
    from subprocess import run

    args = get_parser().parse_args()
    session = Session(profile_name=args.profile, region_name=args.region)
    vars = get_lambda_vars(session, args.function_name)
    vars_quoted = ("=".join(map(quote, pair)) for pair in vars.items())

    if args.command:
        # display shell-safe copy-and-pasteable rendition of what we're doing
        print(*vars_quoted, sep=" \\\n", end=" \\\n", file=stderr)
        print(*map(quote, args.command), file=stderr)
        print(file=stderr)

        env = {
            **({} if args.no_local_env else get_local_vars()),
            **({} if args.no_auth_env else get_auth_vars(session)),
            **vars,
        }
        run(args.command, env=env)

    else:  # ".env file"-compatible output to stdout
        print(*vars_quoted, sep="\n")


def get_parser():
    from argparse import ArgumentParser

    parser = ArgumentParser(
        description="""
            Given a Lambda function, display its environment variables or run a
            command with those environment variables set.
        """,
        epilog="""
            Note that any command run will be using the AWS credentials of the
            user invoking the script (or no credentials at all if --no-auth-env
            is used); the command will not run with the permissions of the role
            used by a real invocation of the Lambda function.
        """,
    )
    parser.add_argument(
        "--profile",
        help="""
            use named AWS profile (e.g. "development") or omit to use
            environment variables
        """,
    )
    parser.add_argument(
        "--region",
        help="region where Lambda function is provisioned",
    )
    parser.add_argument(
        "--function-name",
        help="provisioned name of the Lambda function",
        required=True,
    )
    parser.add_argument(
        "--no-local-env",
        help="""
            when running a command, do not inherit caller's local environment
            variables that aren't related to AWS credentials; see also
            --no-auth-env
        """,
        action="store_true",
    )
    parser.add_argument(
        "--no-auth-env",
        help="when running a command, do not inherit caller's AWS credentials",
        action="store_true",
    )
    parser.add_argument(
        "command",
        nargs="*",
        help="""
            run this command with the environment variables of the Lambda
            function or omit to send ".env file"-style output to stdout
        """,
    )

    return parser


def get_lambda_vars(session: Session, function_name: str):
    awslambda = session.client("lambda")
    response = awslambda.get_function(FunctionName=function_name)
    config = response["Configuration"]

    # This is a partial list; for all built-in environment variables, see:
    # <https://docs.aws.amazon.com/lambda/latest/dg/configuration-envvars.html>
    builtin_vars = {
        "AWS_DEFAULT_REGION": session.region_name,
        "AWS_EXECUTION_ENV": f"AWS_Lambda_{config['Runtime']}",
        "AWS_LAMBDA_FUNCTION_MEMORY_SIZE": config["MemorySize"],
        "AWS_LAMBDA_FUNCTION_NAME": config["FunctionName"],
        "AWS_REGION": session.region_name,
        "TZ": "UTC",
    }

    try:
        function_vars = config["Environment"]["Variables"]
    except KeyError:
        function_vars = {}
    if not function_vars:
        print(
            f"warning: {function_name} has no environment variables of its own",
            file=stderr,
        )

    merged_vars = {**builtin_vars, **function_vars}
    return {str(key): str(value) for key, value in merged_vars.items()}


def get_local_vars():
    from os import environ

    return {
        key: value
        for key, value in environ.items()
        if key
        not in [
            "AWS_PROFILE",
            "AWS_ACCESS_KEY_ID",
            "AWS_SECRET_ACCESS_KEY",
            "AWS_SESSION_TOKEN",
        ]
    }


def get_auth_vars(session: Session):
    """
    In real invocations, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and
    AWS_SESSION_TOKEN would be set rather than using the credentials of
    the user invoking this script (i.e. usually AWS_PROFILE).

    Ideally, this script would assume the role of the function and set
    said variables (e.g. to test IAM policies), but that is usually not
    possible. Usually, the trusted entity for a function role is
    lambda.amazonaws.com (and maybe edgelambda.amazonaws.com), and that
    does *not* allow IAM users of an AWS account to assume the role.
    """

    from os import getenv

    return {
        key: str(value)
        for key, value in {
            "AWS_PROFILE": session.profile_name,
            "AWS_ACCESS_KEY_ID": getenv("AWS_ACCESS_KEY_ID"),
            "AWS_SECRET_ACCESS_KEY": getenv("AWS_SECRET_ACCESS_KEY"),
            "AWS_SESSION_TOKEN": getenv("AWS_SESSION_TOKEN"),
        }.items()
        if value and value != "default"
    }


if __name__ == "__main__":
    main()
