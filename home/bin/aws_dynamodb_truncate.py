#!/usr/bin/env python3


def main():
    args = get_parser().parse_args()
    client = get_dynamodb_client(args.profile, args.region)
    print(args, client)


def get_parser():
    from argparse import ArgumentParser

    parser = ArgumentParser(
        description="Delete all items in a DynamoDB table.",
        epilog="""
            If your table contains many items, consider deleting the table and
            creating it again as a cheaper/faster alternative.
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
        help="region where DynamoDB table is provisioned",
    )
    parser.add_argument(
        "--table-name",
        help="name of table whose items will be deleted",
        metavar="TABLE",
        required=True,
    )

    return parser


def get_dynamodb_client(profile: str, region: str):
    from boto3 import Session

    session = Session(profile_name=profile, region_name=region)
    return session.client("dynamodb")


if __name__ == "__main__":
    main()
