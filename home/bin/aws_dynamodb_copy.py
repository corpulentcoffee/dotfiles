#!/usr/bin/env python3


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

    print(source_table.table_arn, "->", destination_table.table_arn)  # TODO
    return 0


def get_parser():
    from argparse import ArgumentParser

    parser = ArgumentParser(
        description="""
            Copy all items from one DynamoDB table to another by scanning for
            its items and then batch writing all items found.
        """,
        epilog="""
            If your source table contains many items and you can create a new
            destination table rather than use an existing one, consider
            restoring from a DynamoDB backup as an alternative.
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

    return parser


if __name__ == "__main__":
    exit(main())
