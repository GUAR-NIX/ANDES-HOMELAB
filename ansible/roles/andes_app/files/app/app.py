"""Andes App: aplicación mínima de tres capas para el homelab (proxy -> app -> PostgreSQL)."""
import os
import socket

import psycopg
from flask import Flask, jsonify

VERSION = "1.0.1"
app = Flask(__name__)


def conectar():
    with open(os.environ.get("DATABASE_PASSWORD_FILE", "/run/secrets/db_password")) as f:
        password = f.read().strip()
    return psycopg.connect(
        host=os.environ.get("DATABASE_HOST", "db"),
        dbname=os.environ.get("DATABASE_NAME", "andes"),
        user=os.environ.get("DATABASE_USER", "andes_app"),
        password=password,
        connect_timeout=3,
    )


@app.get("/health")
def health():
    try:
        with conectar() as c:
            c.execute("SELECT 1")
        return jsonify(status="ok", db="ok", version=VERSION)
    except Exception as e:  # noqa: BLE001
        return jsonify(status="error", db=str(e)[:200], version=VERSION), 503


@app.get("/")
def index():
    with conectar() as c:
        c.execute("CREATE TABLE IF NOT EXISTS visitas (id serial PRIMARY KEY, ts timestamptz DEFAULT now())")
        c.execute("INSERT INTO visitas DEFAULT VALUES")
        total = c.execute("SELECT count(*) FROM visitas").fetchone()[0]
    return (
        f"<h1>Andes App {VERSION}</h1>"
        f"<p>Visitas registradas en PostgreSQL: <b>{total}</b></p>"
        f"<p>Contenedor: {socket.gethostname()}</p>\n"
    )
