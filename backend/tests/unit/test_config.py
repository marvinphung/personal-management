import pytest
from qlt.config import Settings


def test_reject_production_db_in_destructive_operations():
    prod_settings = Settings(
        database_url="postgresql://user:pass@db.supabase.co:5432/postgres",
        environment="production",
    )
    with pytest.raises(RuntimeError, match="Destructive operation forbidden"):
        prod_settings.assert_test_database()

    cloud_settings = Settings(
        database_url="postgresql://user:pass@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres",
        environment="test",
    )
    with pytest.raises(RuntimeError, match="target a cloud/production database"):
        cloud_settings.assert_test_database()


def test_allow_isolated_test_db():
    test_settings = Settings(
        database_url="postgresql://test_user:test_password@localhost:5433/qlt_test?sslmode=disable",
        environment="test",
    )
    # Should not raise
    test_settings.assert_test_database()
