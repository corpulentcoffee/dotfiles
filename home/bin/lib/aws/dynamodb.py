from typing import Optional


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
