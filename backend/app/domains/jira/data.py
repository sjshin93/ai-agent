import sqlite3
from pathlib import Path

_BASE_DIR = Path(__file__).resolve().parents[2]
_DB_PATH = _BASE_DIR / "data" / "jira_options.db"


def _get_conn() -> sqlite3.Connection:
    _DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(_DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def _init_db(conn: sqlite3.Connection) -> None:
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS jira_field_options (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            field_key TEXT NOT NULL,
            value TEXT NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0,
            is_active INTEGER NOT NULL DEFAULT 1,
            UNIQUE(field_key, value)
        )
        """
    )
    conn.commit()
    _seed_defaults(conn)


def _seed_defaults(conn: sqlite3.Connection) -> None:
    defaults = {
        "customer_part": ["etc"],
        "req_type": ["디버깅(점검)"],
    }
    for field_key, values in defaults.items():
        for value in values:
            conn.execute(
                """
                INSERT OR IGNORE INTO jira_field_options (field_key, value, sort_order)
                VALUES (?, ?, 0)
                """,
                (field_key, value),
            )
    conn.commit()


def fetch_options(field_key: str) -> list[str]:
    conn = _get_conn()
    try:
        _init_db(conn)
        rows = conn.execute(
            """
            SELECT value
            FROM jira_field_options
            WHERE field_key = ? AND is_active = 1
            ORDER BY sort_order ASC, value ASC
            """,
            (field_key,),
        ).fetchall()
        return [row["value"] for row in rows]
    finally:
        conn.close()
