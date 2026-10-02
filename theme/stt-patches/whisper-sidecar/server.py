#!/usr/bin/env python3
"""SkyScale local Whisper sidecar — faster-whisper over HTTP on 127.0.0.1.

Endpoints:
  GET  /health
  POST /jobs   JSON { "path": "/abs/audio.ogg", "language": "ru", "model": "base" }
  GET  /jobs/{id}
"""

from __future__ import annotations

import json
import os
import queue
import threading
import time
import traceback
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

HOST = os.environ.get("WHISPER_HOST", "127.0.0.1")
PORT = int(os.environ.get("WHISPER_PORT", "8791"))
DEFAULT_MODEL = os.environ.get("WHISPER_MODEL", "base")
DEFAULT_LANGUAGE = os.environ.get("WHISPER_LANGUAGE", "ru")
ALLOWED_PREFIXES = [
    p for p in os.environ.get(
        "WHISPER_ALLOWED_PREFIXES",
        "/storage/usbdisk1/mikopbx,/var/spool/mikopbx/storage,/tmp",
    ).split(",")
    if p
]
MAX_DURATION_SEC = int(os.environ.get("WHISPER_MAX_DURATION_SEC", "5400"))
JOB_TTL_SEC = int(os.environ.get("WHISPER_JOB_TTL_SEC", "7200"))
JOB_TIMEOUT_SEC = int(os.environ.get("WHISPER_JOB_TIMEOUT_SEC", "1800"))
OOM_FALLBACK_MODEL = os.environ.get("WHISPER_OOM_FALLBACK_MODEL", "tiny")

_jobs: dict[str, dict[str, Any]] = {}
_jobs_lock = threading.Lock()
_work_q: queue.Queue[str] = queue.Queue(maxsize=32)
_model_cache: dict[str, Any] = {}
_model_lock = threading.Lock()


def _log(msg: str) -> None:
    print(f"[whisper-sidecar] {msg}", flush=True)


def _allowed_path(path: str) -> bool:
    try:
        real = str(Path(path).resolve())
    except Exception:
        return False
    for prefix in ALLOWED_PREFIXES:
        base = str(Path(prefix).resolve()) if Path(prefix).exists() else prefix.rstrip("/")
        if real == base or real.startswith(base + os.sep):
            return True
    return False


def _get_model(name: str):
    from faster_whisper import WhisperModel

    key = name.strip() or DEFAULT_MODEL
    if key not in ("tiny", "base", "small"):
        key = DEFAULT_MODEL
    with _model_lock:
        if key not in _model_cache:
            _log(f"loading model={key} device=cpu compute_type=int8")
            _model_cache[key] = WhisperModel(key, device="cpu", compute_type="int8")
        return _model_cache[key]


def _is_oom(exc: BaseException) -> bool:
    msg = str(exc).lower()
    return isinstance(exc, MemoryError) or "out of memory" in msg or "cannot allocate" in msg


def _load_audio_f32(path: str, sampling_rate: int = 16000):
    """Decode via ffmpeg to float32 mono — avoids PyAV metadata_errors incompat."""
    import numpy as np

    cmd = [
        "ffmpeg",
        "-nostdin",
        "-threads",
        "1",
        "-i",
        path,
        "-f",
        "f32le",
        "-acodec",
        "pcm_f32le",
        "-ac",
        "1",
        "-ar",
        str(sampling_rate),
        "-",
    ]
    try:
        import subprocess

        raw = subprocess.check_output(cmd, stderr=subprocess.DEVNULL)
    except Exception as exc:  # noqa: BLE001
        raise RuntimeError(f"ffmpeg decode failed: {exc}") from exc
    return np.frombuffer(raw, dtype=np.float32)


def _run_transcribe(path: str, language: str, model_name: str) -> dict[str, Any]:
    model = _get_model(model_name)
    lang = None if language in ("", "auto") else language
    audio = _load_audio_f32(path)
    if audio.size == 0:
        raise RuntimeError("empty audio after decode")
    segments_iter, info = model.transcribe(
        audio,
        language=lang,
        vad_filter=True,
        beam_size=1,
    )
    chunks = []
    texts = []
    for seg in segments_iter:
        start_ms = max(0, int(seg.start * 1000))
        end_ms = max(start_ms, int(seg.end * 1000))
        text = (seg.text or "").strip()
        if not text:
            continue
        if end_ms / 1000.0 > MAX_DURATION_SEC:
            break
        chunks.append(
            {
                "start_ms": start_ms,
                "end_ms": end_ms,
                "text": text,
                "channel": None,
            }
        )
        texts.append(text)
    return {
        "language": getattr(info, "language", language or "ru"),
        "duration_ms": int(getattr(info, "duration", 0) * 1000),
        "plain_text": " ".join(texts).strip(),
        "chunks": chunks,
        "model": model_name,
    }


def _transcribe(path: str, language: str, model_name: str) -> dict[str, Any]:
    try:
        return _run_transcribe(path, language, model_name)
    except Exception as exc:  # noqa: BLE001
        if model_name != OOM_FALLBACK_MODEL and _is_oom(exc):
            _log(f"OOM on model={model_name}, falling back to {OOM_FALLBACK_MODEL}")
            return _run_transcribe(path, language, OOM_FALLBACK_MODEL)
        raise


def _worker() -> None:
    while True:
        job_id = _work_q.get()
        with _jobs_lock:
            job = _jobs.get(job_id)
            if job is None:
                _work_q.task_done()
                continue
            job["status"] = "running"
            job["started_at"] = time.time()
            path = job["path"]
            language = job["language"]
            model_name = job["model"]
        try:
            result_box: dict[str, Any] = {}
            error_box: dict[str, str] = {}

            def _do() -> None:
                try:
                    result_box["result"] = _transcribe(path, language, model_name)
                except Exception as exc:  # noqa: BLE001
                    error_box["error"] = str(exc)
                    error_box["trace"] = traceback.format_exc()

            t = threading.Thread(target=_do, name=f"whisper-job-{job_id[:8]}", daemon=True)
            t.start()
            t.join(timeout=JOB_TIMEOUT_SEC)
            if t.is_alive():
                with _jobs_lock:
                    job = _jobs.get(job_id)
                    if job is not None:
                        job["status"] = "failed"
                        job["error"] = f"timeout after {JOB_TIMEOUT_SEC}s"
                        job["finished_at"] = time.time()
                _log(f"job {job_id} timed out after {JOB_TIMEOUT_SEC}s")
            elif "error" in error_box:
                with _jobs_lock:
                    job = _jobs.get(job_id)
                    if job is not None:
                        job["status"] = "failed"
                        job["error"] = error_box["error"]
                        job["finished_at"] = time.time()
                _log(f"job {job_id} failed: {error_box['error']}\n{error_box.get('trace', '')}")
            else:
                result = result_box["result"]
                with _jobs_lock:
                    job = _jobs.get(job_id)
                    if job is not None:
                        job["status"] = "completed"
                        job["result"] = result
                        job["finished_at"] = time.time()
                _log(f"job {job_id} completed chunks={len(result.get('chunks', []))}")
        finally:
            _work_q.task_done()
            _gc_jobs()


def _gc_jobs() -> None:
    now = time.time()
    with _jobs_lock:
        dead = [
            jid
            for jid, job in _jobs.items()
            if job.get("finished_at") and now - float(job["finished_at"]) > JOB_TTL_SEC
        ]
        for jid in dead:
            del _jobs[jid]


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt: str, *args: Any) -> None:
        _log("%s - %s" % (self.address_string(), fmt % args))

    def _send(self, code: int, payload: dict[str, Any]) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        if parsed.path == "/health":
            self._send(
                200,
                {
                    "ok": True,
                    "model_default": DEFAULT_MODEL,
                    "queue": _work_q.qsize(),
                    "jobs": len(_jobs),
                },
            )
            return
        if parsed.path.startswith("/jobs/"):
            job_id = parsed.path[len("/jobs/") :].strip("/")
            with _jobs_lock:
                job = _jobs.get(job_id)
                if job is None:
                    self._send(404, {"ok": False, "error": "not_found"})
                    return
                payload = {
                    "ok": True,
                    "id": job_id,
                    "status": job["status"],
                    "error": job.get("error"),
                    "result": job.get("result"),
                }
            self._send(200, payload)
            return
        self._send(404, {"ok": False, "error": "not_found"})

    def do_POST(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        if parsed.path != "/jobs":
            self._send(404, {"ok": False, "error": "not_found"})
            return
        length = int(self.headers.get("Content-Length") or "0")
        raw = self.rfile.read(length) if length > 0 else b"{}"
        try:
            data = json.loads(raw.decode("utf-8") or "{}")
        except Exception:
            self._send(400, {"ok": False, "error": "invalid_json"})
            return
        path = str(data.get("path") or "").strip()
        language = str(data.get("language") or DEFAULT_LANGUAGE).strip() or DEFAULT_LANGUAGE
        model = str(data.get("model") or DEFAULT_MODEL).strip() or DEFAULT_MODEL
        if not path or not os.path.isfile(path):
            self._send(400, {"ok": False, "error": "file_not_found"})
            return
        if not _allowed_path(path):
            self._send(403, {"ok": False, "error": "path_not_allowed"})
            return
        job_id = str(uuid.uuid4())
        with _jobs_lock:
            _jobs[job_id] = {
                "status": "queued",
                "path": path,
                "language": language,
                "model": model,
                "created_at": time.time(),
            }
        try:
            _work_q.put_nowait(job_id)
        except queue.Full:
            with _jobs_lock:
                _jobs.pop(job_id, None)
            self._send(503, {"ok": False, "error": "queue_full"})
            return
        self._send(202, {"ok": True, "id": job_id, "status": "queued"})


def main() -> None:
    threading.Thread(target=_worker, name="whisper-worker", daemon=True).start()
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    _log(f"listening on http://{HOST}:{PORT}")
    server.serve_forever()


if __name__ == "__main__":
    main()
