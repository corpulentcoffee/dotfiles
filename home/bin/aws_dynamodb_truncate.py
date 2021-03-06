#!/usr/bin/env python3

from typing import Dict, Iterable, List, Tuple, cast

DynamoValue = Dict[str, str]  # e.g. {"N": "12345"}
DynamoItem = Dict[str, DynamoValue]  # e.g. {"id": {"N": "12345"}}


def main():
    args = get_parser().parse_args()
    client = get_dynamodb_client(args.profile, args.region)
    table_name = args.table_name
    item_count, keys = get_table_info(client, table_name)
    batches = in_batches(get_items(client, table_name, keys))

    try:
        first_batch = next(batches)
    except StopIteration:
        print(f"{table_name} is already empty.")
        return

    print(item_count, first_batch)


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


def get_items(client, table_name: str, attrs: List[str]):
    enumerated = list(enumerate(attrs))
    params = dict(
        TableName=table_name,
        ProjectionExpression=", ".join(f"#attr{i}" for i, _ in enumerated),
        ExpressionAttributeNames={f"#attr{i}": name for i, name in enumerated},
    )

    while params:
        result = client.scan(**params)
        yield from cast(List[DynamoItem], result["Items"])

        if result.get("LastEvaluatedKey"):
            params["ExclusiveStartKey"] = result["LastEvaluatedKey"]
        else:
            params = None


def in_batches(sequence: Iterable[DynamoItem], count: int = 25):
    accumulated: List[DynamoItem] = []

    for item in sequence:
        accumulated.append(item)
        if len(accumulated) == count:
            yield accumulated
            accumulated = []

    if accumulated:
        yield accumulated


if __name__ == "__main__":
    main()
