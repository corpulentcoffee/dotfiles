#!/usr/bin/env python3

from typing import Dict, Iterable, List, cast

from boto3 import Session

DynamoValue = Dict[str, str]  # e.g. {"N": "12345"}
DynamoItem = Dict[str, DynamoValue]  # e.g. {"id": {"N": "12345"}}


def main() -> int:
    args = get_parser().parse_args()
    session = Session(profile_name=args.profile, region_name=args.region)

    # see https://github.com/boto/boto3/issues/2039
    client = session.client("dynamodb")
    table = session.resource("dynamodb").Table(args.table_name)

    batches = in_batches(get_items(client, table))
    try:
        first_batch = next(batches)
    except StopIteration:
        print(f"{table.name} is already empty.")
        return 0

    if get_confirmation(table.name, table.item_count, first_batch) is not True:
        return 1

    delete_items(client, table.name, first_batch)
    for successive_batch in batches:
        delete_items(client, table.name, successive_batch)

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


def get_items(client, table):
    keys = [definition["AttributeName"] for definition in table.key_schema]
    enumerated = list(enumerate(keys))
    params = dict(
        TableName=table.name,
        ProjectionExpression=", ".join(f"#attr{i}" for i, _ in enumerated),
        ExpressionAttributeNames={f"#attr{i}": name for i, name in enumerated},
    )
    paginator = client.get_paginator("scan")  # handles LastEvaluatedKey

    for result in paginator.paginate(**params):
        yield from cast(List[DynamoItem], result["Items"])


def in_batches(sequence: Iterable[DynamoItem], count: int = 25):
    accumulated: List[DynamoItem] = []

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
    sample: List[DynamoItem],
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


def delete_items(client, table_name: str, items: List[DynamoItem]):
    print("deleting:", get_formatted_items(items))

    request_items = {
        table_name: [{"DeleteRequest": {"Key": item}} for item in items]
    }
    backoff_time = 1

    while request_items:
        response = client.batch_write_item(RequestItems=request_items)

        if response.get("UnprocessedItems"):
            from time import sleep

            request_items = cast(dict, response["UnprocessedItems"])
            print(
                f"Retrying {len(request_items)}",
                "item" if len(request_items) == 1 else "items",
                f"after a {backoff_time}-second delay",
            )

            sleep(backoff_time)
            backoff_time *= 2

        else:
            request_items = None


def get_formatted_items(items: List[DynamoItem]) -> str:
    return ", ".join(get_formatted_item(item) for item in items)


def get_formatted_item(item: DynamoItem) -> str:
    return " w/ ".join(
        f'{key}="{value_str}"'
        for key, value in item.items()
        for value_str in value.values()
    )


if __name__ == "__main__":
    exit(main())
