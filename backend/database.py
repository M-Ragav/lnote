import sqlite3
import os
from datetime import datetime, timezone
from typing import List, Optional, Tuple, Dict, Any
from models import AttendanceDayModel, SessionModel, SkillModel, UserProfileModel, SyncRequest, SyncResponse

DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "lnote.db")

def get_connection() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH, timeout=10.0)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    return conn

def init_db():
    with get_connection() as conn:
        cursor = conn.cursor()
        # Days
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS attendance_days (
                date TEXT PRIMARY KEY,
                last_updated TEXT
            )
        """)
        # Sessions
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY,
                date TEXT NOT NULL,
                in_time TEXT NOT NULL,
                out_time TEXT,
                tag TEXT,
                updated_at TEXT,
                FOREIGN KEY (date) REFERENCES attendance_days (date)
            )
        """)
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_sessions_date ON sessions (date)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_sessions_in_time ON sessions (date, in_time)")

        # Skills
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS skills (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                updated_at TEXT
            )
        """)

        # User Profile (single row)
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS user_profile (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                name TEXT NOT NULL,
                birthday TEXT NOT NULL,
                updated_at TEXT
            )
        """)

        # Sync audit log
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS sync_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                device_id TEXT,
                device_name TEXT,
                timestamp TEXT,
                summary TEXT
            )
        """)

        # Pending device notifications
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS notifications (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                message TEXT NOT NULL,
                created_at TEXT NOT NULL,
                delivered INTEGER DEFAULT 0
            )
        """)
        conn.commit()

def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()

def merge_sync_data(request: SyncRequest) -> SyncResponse:
    now = now_iso()
    with get_connection() as conn:
        cursor = conn.cursor()

        # 1. Merge Profile if provided
        if request.profile:
            cursor.execute("""
                INSERT INTO user_profile (id, name, birthday, updated_at)
                VALUES (1, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    name = excluded.name,
                    birthday = excluded.birthday,
                    updated_at = excluded.updated_at
            """, (request.profile.name, request.profile.birthday, now))

        # 2. Merge Skills if provided
        if request.skills:
            for skill in request.skills:
                cursor.execute("""
                    INSERT INTO skills (id, name, updated_at)
                    VALUES (?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                        name = excluded.name,
                        updated_at = excluded.updated_at
                """, (skill.id, skill.name, now))

        # 3. Merge Attendance Days & Sessions if provided
        if request.attendanceDays:
            for day in request.attendanceDays:
                cursor.execute("""
                    INSERT INTO attendance_days (date, last_updated)
                    VALUES (?, ?)
                    ON CONFLICT(date) DO UPDATE SET
                        last_updated = excluded.last_updated
                """, (day.date, now))

                for session in day.sessions:
                    # Look for existing session on that date with matching in_time
                    cursor.execute(
                        "SELECT id, out_time, tag FROM sessions WHERE date = ? AND in_time = ?",
                        (day.date, session.inTime)
                    )
                    row = cursor.fetchone()
                    if row is None:
                        # Insert new session
                        session_id = f"{day.date}_{session.inTime}"
                        cursor.execute("""
                            INSERT INTO sessions (id, date, in_time, out_time, tag, updated_at)
                            VALUES (?, ?, ?, ?, ?, ?)
                        """, (session_id, day.date, session.inTime, session.outTime, session.tag, now))
                    else:
                        # Existing session: update out_time and tag if client has newer/non-null data
                        existing_out = row["out_time"]
                        existing_tag = row["tag"]
                        new_out = session.outTime if session.outTime is not None else existing_out
                        new_tag = session.tag if session.tag is not None else existing_tag

                        cursor.execute("""
                            UPDATE sessions
                            SET out_time = ?, tag = ?, updated_at = ?
                            WHERE id = ?
                        """, (new_out, new_tag, now, row["id"]))

        # 4. Log sync
        summary = f"Days: {len(request.attendanceDays or [])}, Skills: {len(request.skills or [])}"
        cursor.execute("""
            INSERT INTO sync_logs (device_id, device_name, timestamp, summary)
            VALUES (?, ?, ?, ?)
        """, (request.deviceId, request.deviceName, now, summary))

        conn.commit()

    return get_full_state()

def get_full_state() -> SyncResponse:
    with get_connection() as conn:
        cursor = conn.cursor()

        # Load Profile
        cursor.execute("SELECT name, birthday FROM user_profile WHERE id = 1")
        p_row = cursor.fetchone()
        profile = UserProfileModel(name=p_row["name"], birthday=p_row["birthday"]) if p_row else None

        # Load Skills
        cursor.execute("SELECT id, name FROM skills ORDER BY name ASC")
        skills = [SkillModel(id=r["id"], name=r["name"]) for r in cursor.fetchall()]

        # Load Days and Sessions
        cursor.execute("SELECT date FROM attendance_days ORDER BY date ASC")
        days = []
        for d_row in cursor.fetchall():
            date_str = d_row["date"]
            cursor.execute(
                "SELECT in_time, out_time, tag FROM sessions WHERE date = ? ORDER BY in_time ASC",
                (date_str,)
            )
            sessions = [
                SessionModel(
                    inTime=s["in_time"],
                    outTime=s["out_time"],
                    tag=s["tag"]
                ) for s in cursor.fetchall()
            ]
            days.append(AttendanceDayModel(date=date_str, sessions=sessions))

    return SyncResponse(
        status="success",
        serverTimestamp=now_iso(),
        attendanceDays=days,
        skills=skills,
        profile=profile,
    )

def get_stats() -> Tuple[int, int]:
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM attendance_days")
        days_count = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(*) FROM sessions")
        sessions_count = cursor.fetchone()[0]
        return days_count, sessions_count

def reset_db():
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM sessions")
        cursor.execute("DELETE FROM attendance_days")
        cursor.execute("DELETE FROM skills")
        cursor.execute("DELETE FROM user_profile")
        cursor.execute("DELETE FROM sync_logs")
        cursor.execute("DELETE FROM notifications")
        conn.commit()

def add_notification(title: str, message: str) -> int:
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO notifications (title, message, created_at, delivered)
            VALUES (?, ?, ?, 0)
        """, (title, message, now_iso()))
        conn.commit()
        return cursor.lastrowid

def get_pending_notifications() -> List[Dict[str, Any]]:
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT id, title, message, created_at
            FROM notifications
            WHERE delivered = 0
            ORDER BY id ASC
        """)
        rows = cursor.fetchall()
        return [
            {
                "id": row["id"],
                "title": row["title"],
                "message": row["message"],
                "created_at": row["created_at"],
            }
            for row in rows
        ]

def mark_notifications_delivered(ids: List[int]):
    if not ids:
        return
    with get_connection() as conn:
        cursor = conn.cursor()
        placeholders = ",".join("?" for _ in ids)
        cursor.execute(f"""
            UPDATE notifications
            SET delivered = 1
            WHERE id IN ({placeholders})
        """, ids)
        conn.commit()

