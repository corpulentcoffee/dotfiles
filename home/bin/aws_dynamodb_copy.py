#!/usr/bin/env python3


from typing import List, Optional


def main() -> int:
    from lib.aws.dynamodb import get_item_pages, get_table

    args = get_parser().parse_args()
    source_table = get_table(
        args.source_table_name,
        args.source_profile,
        args.source_region,
        args.source_retries,
    )
    destination_table = get_table(
        args.destination_table_name,
        args.destination_profile,
        args.destination_region,
        args.destination_retries,
    )

    if source_table.table_arn == destination_table.table_arn:
        print("You cannot copy from/to the same table.")
        return 1

    source_pages = get_item_pages(
        source_table,
        "scan",
        ConsistentRead=args.source_consistent_scan,
        Limit=args.source_scan_size,
    )
    first_page = next(source_pages)

    if not first_page:
        print(f"{source_table.name} does not have any items to copy.")
        return 1
    elif (
        get_confirmation(
            source_table,
            destination_table,
            first_page[0:10],
            args.transform_command,
        )
        is not True
    ):
        print("Copy canceled.")
        return 1

    with destination_table.batch_writer() as batch_writer:
        print(f"copying first {len(first_page)}-item page...")
        copy_items(batch_writer, first_page, args.transform_command)
        print("scanning the remaining items", end="... ")
        for successive_page in source_pages:
            print(f"copying next {len(successive_page)}-item page...")
            copy_items(batch_writer, successive_page, args.transform_command)
            print("looking for additional items", end="... ")
        print("got everything; finishing up...")
    print(f"{destination_table.name} should now be populated.")
    return 0


def get_parser():
    from argparse import ArgumentParser

    parser = ArgumentParser(
        description="""
            Copy all items from one DynamoDB table to another by scanning for
            its items, optionally applying a data transformation, and then
            batch writing all items.
        """,
        epilog="""
            If your source table contains many items, you do not need to do any
            data transformations, and you can create a new destination table
            rather than use an existing one, consider restoring from a DynamoDB
            backup as an alternative.
        """,
    )
    parser.add_argument(
        "--source-consistent-scan",
        help="""
            set to ensure item scan against source table reflects
            recently-completed changes; note that this will double read
            capacity units consumed
        """,
        action="store_true",
        default=False,
    )
    parser.add_argument(
        "--source-scan-size",
        help="limit number of items read from source table at once",
        metavar="COUNT",
        type=int,
    )
    for which in ["source", "destination"]:
        parser.add_argument(
            f"--{which}-profile",
            help=f"""
                use named AWS profile
                (e.g. "{'qa' if which == "source" else 'development'}")
                to access {which} table
            """,
            metavar="PROFILE",
        )
        parser.add_argument(
            f"--{which}-region",
            help=f"region where {which} table is provisioned",
            metavar="REGION",
        )
        parser.add_argument(
            f"--{which}-table-name",
            help=f"""
                {which} table you want to
                {'read from' if which == "source" else 'write to'}
            """,
            metavar="TABLE",
            required=True,
        )
        parser.add_argument(
            f"--{which}-retries",
            help=f"""
                control how many times to retry a request
                (e.g. {'scans' if which == "source" else 'batch writes'} might
                be throttled because {which} table has a relatively low
                {'read' if which == "source" else 'write'} capacity)
            """,
            metavar="COUNT",
            type=int,
        )
    parser.add_argument(
        "--transform-command",
        help="""
            if supplied, each item will be dumped to a JSON string, passed as
            stdin to this shell command, and then loaded back from stdout (e.g.
            one might do "gron | grep '^json.id =' | gron --ungron" or
            "jq '{id: .id}'" as a quick and dirty way to copy only the "id"
            attribute of source items to the destination); simplejson is used
            to convert to and from JSON when running the transform command,
            which might have consequences for certain values (e.g. loss of
            precision for decimal numbers)
        """,
        metavar="SHELL",
    )

    return parser


def get_confirmation(
    source_table,
    destination_table,
    sample: List[dict],
    transform_command: Optional[str],
) -> bool:
    from textwrap import dedent

    copy_sample = (
        ", ".join(
            f"{item} as {get_transformed_item(item, transform_command)}"
            for item in sample
        )
        if transform_command
        else ", ".join(repr(item) for item in sample)
    )

    prompt = f"""
        Copy all items?
          from {get_confirmation_summary(source_table)}
          into {get_confirmation_summary(destination_table)}

        Here's a sample of the first batch of items that would be copied:
        {copy_sample}

        Enter destination table name to confirm copying items:
    """

    response = input(f"{dedent(prompt).strip()} ")
    return response.strip().lower() == destination_table.name.strip().lower()


def get_confirmation_summary(table) -> str:
    abbreviated_arn = ":".join(table.table_arn.split(":")[3:])
    estimate = (
        f"~{table.item_count} items"
        if table.item_count > 0
        else "no item estimate"
    )

    return f"{abbreviated_arn} ({estimate})"


def copy_items(
    batch_writer,
    original_items: List[dict],
    transform_command: Optional[str],
):
    for original_item in original_items:
        transformed_item = (
            get_transformed_item(original_item, transform_command)
            if transform_command
            else original_item
        )
        batch_writer.put_item(Item=transformed_item)


def get_transformed_item(original_item: dict, transform_command: str) -> dict:
    from subprocess import PIPE, run

    # DynamoDB Table resources convert numbers to Decimal, which simplejson
    # handles by converting to regular floats when dumping (possibly losing
    # precision) whereas the standard library json doesn't handle Decimal at
    # all; if changing how this works, update `--transform-command` help text
    # as appropriate
    from simplejson import dumps, loads

    transformed_output = run(
        args=transform_command,
        shell=True,
        input=dumps(original_item),
        encoding="utf-8",
        stdout=PIPE,
    ).stdout

    transformed_item = loads(transformed_output)
    return transformed_item


if __name__ == "__main__":
    exit(main())
