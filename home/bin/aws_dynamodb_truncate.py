#!/usr/bin/env python3

from typing import List, Optional, cast


def main() -> int:
    args = get_parser().parse_args()
    table = get_table(args.profile, args.region, args.table_name, args.retries)
    pages = get_item_pages(table, args.consistent_scan, args.scan_size)
    first_page = next(pages)

    if not first_page:
        print(f"{table.name} is already empty.")
        return 0
    elif get_confirmation(table, first_page[0:10]) is not True:
        print("Action canceled.")
        return 1

    with table.batch_writer() as batch_writer:  # also handles UnprocessedItems
        print(f"deleting first {len(first_page)}-item page...")
        delete_items(batch_writer, first_page)
        print("scanning the remaining items", end="... ")
        for successive_page in pages:
            print(f"deleting next {len(successive_page)}-item page...")
            delete_items(batch_writer, successive_page)
            print("looking for additional items", end="... ")
        print("got everything; finishing up...")
    print(f"{table.name} should now be empty.")
    return 0


def get_parser():
    from argparse import ArgumentParser

    parser = ArgumentParser(
        description="""
            Clear a DynamoDB table by scanning for its item keys and then batch
            deleting all items found.
        """,
        epilog="""
            If your table contains many items, consider deleting the table as
            whole and creating it again as a cheaper/faster alternative.
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
    parser.add_argument(
        "--consistent-scan",
        help="""
            set to ensure item scan reflects recently-completed changes to the
            table; note that this will double the read capacity units consumed
        """,
        action="store_true",
        default=False,
    )
    parser.add_argument(
        "--scan-size",
        help="limit number of items read from table at once",
        metavar="COUNT",
        type=int,
    )
    parser.add_argument(
        "--retries",
        help="""
            control how many times to retry a request (e.g. batch writes might
            be throttled because a table has a relatively low write capacity)
        """,
        metavar="COUNT",
        type=int,
    )

    return parser


def get_table(
    profile: str,
    region: str,
    table_name: str,
    retries: Optional[int],
):
    from boto3 import Session
    from botocore.config import Config

    session = Session(profile_name=profile, region_name=region)
    config = Config(retries={"max_attempts": retries}) if retries else Config()
    dynamodb = session.resource("dynamodb", config=config)

    return dynamodb.Table(table_name)


def get_item_pages(table, consistent_scan: bool, scan_size: Optional[int]):
    keys = [definition["AttributeName"] for definition in table.key_schema]
    enumerated = list(enumerate(keys))
    params = dict(
        TableName=table.name,
        ProjectionExpression=", ".join(f"#attr{i}" for i, _ in enumerated),
        ExpressionAttributeNames={f"#attr{i}": name for i, name in enumerated},
        ConsistentRead=consistent_scan,
    )
    if scan_size:
        params.update(dict(Limit=scan_size))

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

        Here's a sample of the first batch of items that would be deleted:
        {get_formatted_items(sample)}

        Enter table name to confirm deleting all items:
    """

    response = input(f"{dedent(prompt).strip()} ")
    return response.strip().lower() == table.name.strip().lower()


def delete_items(batch_writer, items: List[dict]):
    for item in items:
        batch_writer.delete_item(item)


def get_formatted_items(items: List[dict]) -> str:
    return ", ".join(repr(item) for item in items)


if __name__ == "__main__":
    exit(main())
