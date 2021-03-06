#!/usr/bin/env python3

from typing import List, Tuple


def main():
    args = get_parser().parse_args()
    client = get_dynamodb_client(args.profile, args.region)
    table_name = args.table_name
    item_count, keys = get_table_info(client, table_name)
    print(item_count, keys)


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


def get_table_info(client, table_name: str) -> Tuple[int, List[str]]:
    response = client.describe_table(TableName=table_name)
    table = response["Table"]
    item_count = table["ItemCount"]
    keys = [definition["AttributeName"] for definition in table["KeySchema"]]
    return item_count, keys


if __name__ == "__main__":
    main()
