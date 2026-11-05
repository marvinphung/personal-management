"""Run the API using HOST and PORT from the repository .env file."""

import uvicorn

from qlt.config import get_settings


def main() -> None:
    settings = get_settings()
    uvicorn.run(
        "qlt.main:app",
        host=settings.host,
        port=settings.port,
        access_log=not settings.is_production(),
    )


if __name__ == "__main__":
    main()
