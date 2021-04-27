from typing import List, Literal, Optional, cast


def get_table(
    table_name: str,
    profile: Optional[str] = None,
    region: Optional[str] = None,
    retries: Optional[int] = None,
):
    from boto3 import Session
    from botocore.config import Config

    session = Session(profile_name=profile, region_name=region)
    config = Config(retries={"max_attempts": retries}) if retries else Config()
    dynamodb = session.resource("dynamodb", config=config)

    return dynamodb.Table(table_name)


def get_item_pages(table, method: Literal["query", "scan"], **params):
    """
    Yields pages of items for the given query/scan operation.

    Any None values in params will be dropped as a convenience to the
    caller before passing the underlying boto3 method, e.g. for passing
    an optional value from argparse as-is. (Neither query nor scan
    methods accept nulls.)
    """

    params = {key: value for key, value in params.items() if value is not None}

    while True:
        result = getattr(table, method)(**params)
        yield cast(List[dict], result["Items"])

        # one can either have the paginator from the DynamoDB client or data
        # marshalling from the Table resource, but not both, and implementing
        # the former is easier than the latter, so that's what we do here; see
        # https://github.com/boto/boto3/issues/2039
        if result.get("LastEvaluatedKey"):
            params["ExclusiveStartKey"] = result["LastEvaluatedKey"]
        else:
            break
