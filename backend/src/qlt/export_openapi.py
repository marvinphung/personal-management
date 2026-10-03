import json
from pathlib import Path
from qlt.main import app


def export_openapi(output_path: Path | None = None) -> None:
    if output_path is None:
        output_path = Path(__file__).resolve().parents[3] / "docs/api/openapi.json"

    output_path.parent.mkdir(parents=True, exist_ok=True)
    openapi_schema = app.openapi()
    output_path.write_text(json.dumps(openapi_schema, indent=2), encoding="utf-8")
    print(f"Exported OpenAPI schema to {output_path}")


def main():
    export_openapi()


if __name__ == "__main__":
    main()
