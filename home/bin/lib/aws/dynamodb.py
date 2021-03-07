from typing import Optional


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
