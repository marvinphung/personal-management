import uuid
from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from pydantic import BaseModel
from qlt.auth.dependencies import require_active_user
from qlt.catalog.seeds import make_key
from qlt.config import get_settings
from qlt.db import get_connection

router = APIRouter(prefix="/v1", tags=["Catalog"])


class CategoryCreateRequest(BaseModel):
    direction: str  # 'income' or 'expense'
    name: str
    icon: str | None = None


class CategoryUpdateRequest(BaseModel):
    name: str | None = None
    icon: str | None = None
    archived: bool | None = None


class TagCreateRequest(BaseModel):
    name: str


class TagUpdateRequest(BaseModel):
    name: str | None = None
    archived: bool | None = None


@router.get("/categories")
def list_categories(
    direction: str | None = Query(None),
    user: dict = Depends(require_active_user),
):
    settings = get_settings()
    schema = settings.database_schema
    user_id = str(user["user_id"])

    # Compute usage count from recorded ledger transactions
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                SELECT c.id, c.direction, c.name, c.icon, c.archived, c.seed_rank, c.version,
                       COALESCE(u.usage_count, 0) as usage_count
                FROM {schema}.categories c
                LEFT JOIN (
                    SELECT category_id, COUNT(*) as usage_count
                    FROM {schema}.transactions
                    WHERE user_id = %s
                    GROUP BY category_id
                ) u ON c.id = u.category_id
                WHERE c.user_id = %s
                  AND (%s::text IS NULL OR c.direction = %s)
                ORDER BY c.archived ASC, usage_count DESC, c.seed_rank ASC, c.name ASC, c.id ASC;
                """,
                (user_id, user_id, direction, direction),
            )
            rows = cur.fetchall()

    return [
        {
            "id": str(r["id"]),
            "direction": r["direction"],
            "name": r["name"],
            "icon": r["icon"],
            "archived": r["archived"],
            "seed_rank": r["seed_rank"],
            "usage_count": r["usage_count"],
            "version": r["version"],
        }
        for r in rows
    ]


@router.post("/categories")
def create_category(req: CategoryCreateRequest, response: Response, user: dict = Depends(require_active_user)):
    dir_str = req.direction.strip().lower()
    if dir_str not in ("income", "expense"):
        raise HTTPException(status_code=422, detail="Direction must be income or expense")

    name = req.name.strip()
    if not name:
        raise HTTPException(status_code=422, detail="Category name cannot be empty")

    name_key = make_key(name)
    settings = get_settings()
    schema = settings.database_schema
    user_id = str(user["user_id"])

    with get_connection() as conn:
        with conn.cursor() as cur:
            # Check if existing category with same normalized name exists -> return canonical ID
            cur.execute(
                f"""
                SELECT id, direction, name, icon, archived, seed_rank, version
                FROM {schema}.categories
                WHERE user_id = %s AND direction = %s AND name_key = %s;
                """,
                (user_id, dir_str, name_key),
            )
            existing = cur.fetchone()
            if existing:
                response.status_code = status.HTTP_200_OK
                return {
                    "id": str(existing["id"]),
                    "direction": existing["direction"],
                    "name": existing["name"],
                    "icon": existing["icon"],
                    "archived": existing["archived"],
                    "seed_rank": existing["seed_rank"],
                    "version": existing["version"],
                }

            cat_id = uuid.uuid4()
            cur.execute(
                f"""
                INSERT INTO {schema}.categories (
                    id, user_id, direction, name, name_key, icon, seed_rank
                ) VALUES (%s, %s, %s, %s, %s, %s, 999)
                RETURNING id, version;
                """,
                (str(cat_id), user_id, dir_str, name, name_key, req.icon),
            )
            row = cur.fetchone()
        conn.commit()

    response.status_code = status.HTTP_201_CREATED
    return {
        "id": str(cat_id),
        "direction": dir_str,
        "name": name,
        "icon": req.icon,
        "archived": False,
        "seed_rank": 999,
        "version": row["version"],
    }


@router.get("/categories/{category_id}/tags")
def list_tags(category_id: uuid.UUID, user: dict = Depends(require_active_user)):
    settings = get_settings()
    schema = settings.database_schema
    user_id = str(user["user_id"])

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                SELECT id, category_id, name, archived, version
                FROM {schema}.tags
                WHERE user_id = %s AND category_id = %s
                ORDER BY archived ASC, name ASC;
                """,
                (user_id, str(category_id)),
            )
            rows = cur.fetchall()

    return [
        {
            "id": str(r["id"]),
            "category_id": str(r["category_id"]),
            "name": r["name"],
            "archived": r["archived"],
            "version": r["version"],
        }
        for r in rows
    ]


@router.post("/categories/{category_id}/tags")
def create_tag(
    category_id: uuid.UUID,
    req: TagCreateRequest,
    response: Response,
    user: dict = Depends(require_active_user),
):
    name = req.name.strip()
    if not name:
        raise HTTPException(status_code=422, detail="Tag name cannot be empty")

    name_key = make_key(name)
    settings = get_settings()
    schema = settings.database_schema
    user_id = str(user["user_id"])

    with get_connection() as conn:
        with conn.cursor() as cur:
            # Verify category belongs to user
            cur.execute(
                f"SELECT id FROM {schema}.categories WHERE id = %s AND user_id = %s;",
                (str(category_id), user_id),
            )
            if not cur.fetchone():
                raise HTTPException(status_code=404, detail="Category not found")

            # Check if tag already exists for this category -> return canonical tag
            cur.execute(
                f"""
                SELECT id, category_id, name, archived, version
                FROM {schema}.tags
                WHERE user_id = %s AND category_id = %s AND name_key = %s;
                """,
                (user_id, str(category_id), name_key),
            )
            existing = cur.fetchone()
            if existing:
                response.status_code = status.HTTP_200_OK
                return {
                    "id": str(existing["id"]),
                    "category_id": str(existing["category_id"]),
                    "name": existing["name"],
                    "archived": existing["archived"],
                    "version": existing["version"],
                }

            tag_id = uuid.uuid4()
            cur.execute(
                f"""
                INSERT INTO {schema}.tags (id, user_id, category_id, name, name_key)
                VALUES (%s, %s, %s, %s, %s)
                RETURNING version;
                """,
                (str(tag_id), user_id, str(category_id), name, name_key),
            )
            row = cur.fetchone()
        conn.commit()

    response.status_code = status.HTTP_201_CREATED
    return {
        "id": str(tag_id),
        "category_id": str(category_id),
        "name": name,
        "archived": False,
        "version": row["version"],
    }
