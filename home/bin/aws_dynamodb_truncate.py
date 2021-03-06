#!/usr/bin/env python3

from typing import Any, Dict, Iterable, List, cast

from boto3 import Session

DynamoItemKeys = Dict[str, Any]  # e.g. {"hashKey": 1234, "rangeKey": 5678}


def main() -> int:
    args = get_parser().parse_args()
    session = Session(profile_name=args.profile, region_name=args.region)
    table = session.resource("dynamodb").Table(args.table_name)
    batches = in_batches(get_items(session, table))

    try:
        first_batch = next(batches)
    except StopIteration:
        print(f"{table.name} is already empty.")
        return 0

    if get_confirmation(table.name, table.item_count, first_batch) is not True:
        return 1

    with table.batch_writer() as writer:  # also handles UnprocessedItems
        delete_items(writer, first_batch)
        for successive_batch in batches:
            delete_items(writer, successive_batch)

    return 0


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


def get_items(session: Session, table):
    keys = [definition["AttributeName"] for definition in table.key_schema]
    enumerated = list(enumerate(keys))
    params = dict(
        TableName=table.name,
        ProjectionExpression=", ".join(f"#attr{i}" for i, _ in enumerated),
        ExpressionAttributeNames={f"#attr{i}": name for i, name in enumerated},
    )

    # We use a regular DynamoDB client here because the Table resource doesn't
    # do paging; see https://github.com/boto/boto3/issues/2039
    client = session.client("dynamodb")
    paginator = client.get_paginator("scan")  # handles LastEvaluatedKey

    for result in paginator.paginate(**params):
        for item in result["Items"]:
            item_keys = {key: next(iter(item[key].values())) for key in keys}
            yield cast(DynamoItemKeys, item_keys)


def in_batches(sequence: Iterable[DynamoItemKeys], count: int = 25):
    accumulated: List[DynamoItemKeys] = []

    for item in sequence:
        accumulated.append(item)
        if len(accumulated) == count:
            yield accumulated
            accumulated = []

    if accumulated:
        yield accumulated


def get_confirmation(
    table_name: str,
    item_count: int,
    sample: List[DynamoItemKeys],
) -> bool:
    from textwrap import dedent

    estimate = (
        f"About {item_count} items are estimated to be in this table."
        if item_count > 0
        else "An estimate for the item count of this table is not available."
    )
    if item_count >= 100_000:
        estimate += (
            " For a table of this size, consider deleting and recreating it "
            "as a faster and cheaper alternative."
        )

    prompt = f"""
        All items from {table_name} will be deleted.
        {estimate}

        This is the first batch of items that would be deleted:
        {get_formatted_items(sample)}

        Are you sure you want to continue?
    """

    return input(f"{dedent(prompt).strip()} ").lower().startswith("y")


def delete_items(writer, items: List[DynamoItemKeys]):
    print("deleting:", get_formatted_items(items))
    for item in items:
        print(item)
        writer.delete_item(Key=item)


def get_formatted_items(items: List[DynamoItemKeys]) -> str:
    return ", ".join(repr(item) for item in items)


if __name__ == "__main__":
    exit(main())
