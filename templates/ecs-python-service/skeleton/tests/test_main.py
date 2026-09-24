"""Run with: python -m pytest -q"""
import importlib
import os

from fastapi.testclient import TestClient


def make_client(base_path: str) -> TestClient:
    os.environ["BASE_PATH"] = base_path
    import app.main as main

    importlib.reload(main)  # BASE_PATH is read at import time
    return TestClient(main.app)


def test_health_under_base_path():
    client = make_client("/dev/${{ values.name }}")
    response = client.get("/dev/${{ values.name }}/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_root_returns_service_info():
    client = make_client("/dev/${{ values.name }}")
    body = client.get("/dev/${{ values.name }}/").json()
    assert body["service"] == "${{ values.name }}"


def test_unknown_path_returns_404():
    client = make_client("/dev/${{ values.name }}")
    assert client.get("/dev/${{ values.name }}/nope").status_code == 404
