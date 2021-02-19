#!/usr/bin/env python3

from argparse import ArgumentParser
from boto3 import Session
from os import getenv
from typing import List, Optional, Tuple

Retention = Optional[int]
GroupRetention = Tuple[str, Retention]
GroupRetentions = List[GroupRetention]


def main():
    args = get_parser().parse_args()
    session = Session(profile_name=args.profile)
    regions = get_regions(session) if args.region == "all" else [args.region]
    wanted = (
        -1 if args.retention_in_days == "forever" else args.retention_in_days
    )

    for region in regions:
        print()
        print(f"checking {region}...")
        run_check(
            session=session,
            region=region,
            prefix=args.log_group_name_prefix,
            wanted=wanted,
            dry_run=args.dry_run,
        )
        print(f"done with {region}")


def get_parser():
    parser = ArgumentParser(
        description="View or set retention policy across multiple log groups.",
        epilog="""
            This script can be helpful used in conjunction with "infrastructure
            as code" deployments that do not explicitly provision log retention
            policies, including Lambda@Edge functions that create their log
            groups across multiple regions.
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
        help="""
            limit to particular AWS region (e.g. "us-east-2") or "all" to check
            every region; based on your environment, default is "%(default)s"
        """,
        default=getenv("AWS_REGION") or getenv("AWS_DEFAULT_REGION") or "all",
        type=lambda value: value.strip().lower(),
    )
    parser.add_argument(
        "--log-group-name-prefix",
        help="""
            limit to groups beginning with given prefix (e.g. "/aws/lambda/")
            or omit to check all log groups
        """,
    )
    parser.add_argument(
        "--retention-in-days",
        help="""
            set retention policy for matching log groups to specified number of
            days, or use "forever" to unset the retention policy, or omit to
            just view the current policy
        """,
        choices=[
            "forever",
            1,
            3,
            5,
            7,
            14,
            30,
            60,
            90,
            120,
            150,
            180,
            365,
            400,
            545,
            731,
            1827,
            3653,
        ],
        type=lambda value: "forever"
        if value.strip().lower() == "forever"
        else int(value, 10),
    )
    parser.add_argument(
        "--dry-run",
        help="show policy retention changes without actually configuring them",
        action="store_true",
    )

    return parser


def get_regions(session: Session) -> List[str]:
    ec2 = session.client("ec2", region_name="us-east-1")
    response = ec2.describe_regions()
    return sorted([region["RegionName"] for region in response["Regions"]])


def run_check(
    session: Session,
    region: str,
    prefix: str,
    wanted: Retention,
    dry_run: bool,
):
    logs = session.client("logs", region_name=region)

    for name, current in get_groups(logs, prefix):
        print(f"  {name}: ", end="")

        if wanted is None:
            print(get_desc(current))
        elif wanted == -1:  # forever
            if not current:
                print("already unset")
            elif dry_run:
                print(f"would unset from {get_desc(current)}")
            else:
                print(f"unsetting from {get_desc(current)}")
                logs.delete_retention_policy(logGroupName=name)
        elif wanted == current:
            print(f"already {get_desc(current)}")
        elif dry_run:
            print(f"would change {get_desc(current)} to {get_desc(wanted)}")
        else:
            print(f"changing {get_desc(current)} to {get_desc(wanted)}")
            logs.put_retention_policy(
                logGroupName=name,
                retentionInDays=wanted,
            )


def get_groups(logs, prefix: str) -> GroupRetentions:
    def page(next_token=None) -> Tuple[GroupRetentions, Optional[str]]:
        response = logs.describe_log_groups(
            **dict(logGroupNamePrefix=prefix) if prefix else {},
            **dict(nextToken=next_token) if next_token else {},
        )
        groups = [
            (group["logGroupName"], group.get("retentionInDays"))
            for group in response["logGroups"]
        ]
        return groups, response.get("nextToken")

    groups, next_token = page()
    yield from groups
    while next_token:
        groups, next_token = page(next_token)
        yield from groups


def get_desc(retention: Retention) -> str:
    return (
        "never expires"
        if retention is None
        else "one day"
        if retention == 1
        else f"{retention} days"
    )


if __name__ == "__main__":
    main()
