#!/usr/bin/env python3

from typing import List, cast


def main() -> int:
    args = get_parser().parse_args()
    table = get_table(args.profile, args.region, args.table_name)
    pages = get_item_pages(table)
    first_page = next(pages)

    if not first_page:
        print(f"{table.name} is already empty.")
        return 0
    elif get_confirmation(table, first_page) is not True:
        return 1

    with table.batch_writer() as batch_writer:  # also handles UnprocessedItems
        delete_items(batch_writer, first_page)
        for successive_page in pages:
            delete_items(batch_writer, successive_page)
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


def get_table(profile: str, region: str, table_name: str):
    from boto3 import Session

    session = Session(profile_name=profile, region_name=region)
    return session.resource("dynamodb").Table(table_name)


def get_item_pages(table):
    keys = [definition["AttributeName"] for definition in table.key_schema]
    enumerated = list(enumerate(keys))
    params = dict(
        TableName=table.name,
        ProjectionExpression=", ".join(f"#attr{i}" for i, _ in enumerated),
        ExpressionAttributeNames={f"#attr{i}": name for i, name in enumerated},
    )

    while params:
        result = table.scan(**params)
        yield cast(List[dict], result["Items"])

        # one can either have the paginator from the DynamoDB client or data
        # marshalling from the Table resource, and implementing the former is
        # easier than the latter; see https://github.com/boto/boto3/issues/2039
        if result.get("LastEvaluatedKey"):
            params["ExclusiveStartKey"] = result["LastEvaluatedKey"]
        else:
            params = None


def get_confirmation(table, sample: List[dict]) -> bool:
    from textwrap import dedent

    estimate = (
        f"About {table.item_count} items are estimated to be in this table."
        if table.item_count > 0
        else "An estimate for the item count of this table is not available."
    )
    if table.item_count >= 100_000:
        estimate += (
            " For a table of this size, consider deleting and recreating it "
            "as a faster and cheaper alternative."
        )

    prompt = f"""
        All items from {table.name} will be deleted.
        {estimate}

        This is the first batch of items that would be deleted:
        {get_formatted_items(sample)}

        Are you sure you want to continue?
    """

    return input(f"{dedent(prompt).strip()} ").lower().startswith("y")


def delete_items(batch_writer, items: List[dict]):
    print("deleting:", get_formatted_items(items))
    for item in items:
        batch_writer.delete_item(item)


def get_formatted_items(items: List[dict]) -> str:
    return ", ".join(repr(item) for item in items)


if __name__ == "__main__":
    exit(main())
