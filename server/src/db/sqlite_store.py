import os
import sqlite3
import time
import uuid
from typing import Optional, Dict, Any, Tuple

from .store import Store


def _uuid() -> str:
    return str(uuid.uuid4())


class SqliteStore(Store):
    def __init__(self, db_path: str) -> None:
        self.db_path = db_path
        os.makedirs(os.path.dirname(db_path), exist_ok=True)
        self.conn = sqlite3.connect(self.db_path, check_same_thread=False)
        self.conn.row_factory = sqlite3.Row
        # Melhor concorrência
        self.conn.execute("PRAGMA journal_mode=WAL;")

    def create_tables(self) -> None:
        cur = self.conn.cursor()
        cur.executescript(
            """
            CREATE TABLE IF NOT EXISTS users (
                id TEXT PRIMARY KEY,
                username TEXT UNIQUE NOT NULL,
                email TEXT,
                pwd_hash BLOB,
                salt BLOB,
                created_at INTEGER NOT NULL
            );

            CREATE TABLE IF NOT EXISTS characters (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                name TEXT NOT NULL,
                level INTEGER NOT NULL,
                xp INTEGER NOT NULL,
                xp_max INTEGER NOT NULL,
                attr_points INTEGER NOT NULL,
                map TEXT NOT NULL,
                pos_x REAL NOT NULL,
                pos_y REAL NOT NULL,
                hp INTEGER NOT NULL,
                hp_max INTEGER NOT NULL,
                created_at INTEGER NOT NULL,
                FOREIGN KEY(user_id) REFERENCES users(id)
            );

            CREATE TABLE IF NOT EXISTS character_attributes (
                character_id TEXT PRIMARY KEY,
                strength INTEGER NOT NULL,
                defense INTEGER NOT NULL,
                intelligence INTEGER NOT NULL,
                vitality INTEGER NOT NULL,
                FOREIGN KEY(character_id) REFERENCES characters(id)
            );

            CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
            CREATE INDEX IF NOT EXISTS idx_chars_user ON characters(user_id);
            """
        )
        self.conn.commit()

    def get_user_by_username(self, username: str) -> Optional[Dict[str, Any]]:
        row = self.conn.execute("SELECT * FROM users WHERE username=?", (username,)).fetchone()
        return dict(row) if row else None

    def create_user(self, username: str, pwd_hash: Optional[bytes], salt: Optional[bytes]) -> str:
        user_id = _uuid()
        self.conn.execute(
            "INSERT INTO users(id, username, email, pwd_hash, salt, created_at) VALUES(?,?,?,?,?,?)",
            (user_id, username, None, pwd_hash, salt, int(time.time())),
        )
        self.conn.commit()
        return user_id

    def get_character_by_user_id(self, user_id: str) -> Optional[Dict[str, Any]]:
        row = self.conn.execute("SELECT * FROM characters WHERE user_id=?", (user_id,)).fetchone()
        return dict(row) if row else None

    def create_character(self, user_id: str, name: str, defaults: Dict[str, Any]) -> str:
        char_id = _uuid()
        now = int(time.time())
        self.conn.execute(
            """
            INSERT INTO characters(
                id, user_id, name, level, xp, xp_max, attr_points,
                map, pos_x, pos_y, hp, hp_max, created_at
            ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)
            """,
            (
                char_id,
                user_id,
                name,
                defaults.get("level", 1),
                defaults.get("xp", 0),
                defaults.get("xp_max", 100),
                defaults.get("attr_points", 0),
                defaults.get("map", "Cidade"),
                float(defaults.get("pos_x", 0.0)),
                float(defaults.get("pos_y", 0.0)),
                defaults.get("hp", 100),
                defaults.get("hp_max", 100),
                now,
            ),
        )
        # Atributos
        self.conn.execute(
            "INSERT INTO character_attributes(character_id, strength, defense, intelligence, vitality) VALUES(?,?,?,?,?)",
            (
                char_id,
                defaults.get("strength", 5),
                defaults.get("defense", 5),
                defaults.get("intelligence", 5),
                defaults.get("vitality", 5),
            ),
        )
        self.conn.commit()
        return char_id

    def load_character_full(self, user_id: str) -> Optional[Tuple[Dict[str, Any], Dict[str, Any]]]:
        char = self.get_character_by_user_id(user_id)
        if not char:
            return None
        attrs_row = self.conn.execute(
            "SELECT * FROM character_attributes WHERE character_id=?",
            (char["id"],),
        ).fetchone()
        attrs = dict(attrs_row) if attrs_row else None
        return (char, attrs)

    def save_character_state(self, character_id: str, state: Dict[str, Any]) -> None:
        fields = [
            ("level", int(state.get("level"))) if "level" in state else None,
            ("xp", int(state.get("xp"))) if "xp" in state else None,
            ("xp_max", int(state.get("xp_max"))) if "xp_max" in state else None,
            ("attr_points", int(state.get("attr_points"))) if "attr_points" in state else None,
            ("map", state.get("map")) if "map" in state else None,
            ("pos_x", float(state.get("pos_x"))) if "pos_x" in state else None,
            ("pos_y", float(state.get("pos_y"))) if "pos_y" in state else None,
            ("hp", int(state.get("hp"))) if "hp" in state else None,
            ("hp_max", int(state.get("hp_max"))) if "hp_max" in state else None,
        ]
        sets = ", ".join([f"{k}=?" for k, v in fields if v is not None])
        params = [v for k, v in fields if v is not None]
        if not sets:
            return
        params.append(character_id)
        self.conn.execute(f"UPDATE characters SET {sets} WHERE id=?", params)
        self.conn.commit()

    def save_character_attributes(self, character_id: str, attrs: Dict[str, int]) -> None:
        fields = [
            ("strength", int(attrs.get("strength"))) if "strength" in attrs else None,
            ("defense", int(attrs.get("defense"))) if "defense" in attrs else None,
            ("intelligence", int(attrs.get("intelligence"))) if "intelligence" in attrs else None,
            ("vitality", int(attrs.get("vitality"))) if "vitality" in attrs else None,
        ]
        sets = ", ".join([f"{k}=?" for k, v in fields if v is not None])
        params = [v for k, v in fields if v is not None]
        if not sets:
            return
        params.append(character_id)
        self.conn.execute(f"UPDATE character_attributes SET {sets} WHERE character_id=?", params)
        self.conn.commit()

    def update_position(self, character_id: str, map_name: str, x: float, y: float) -> None:
        self.conn.execute(
            "UPDATE characters SET map=?, pos_x=?, pos_y=? WHERE id=?",
            (map_name, float(x), float(y), character_id),
        )
        self.conn.commit()

