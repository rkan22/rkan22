"""Vercel serverless entrypoint."""

from app import app

# Vercel expects a module-level variable named `app` for WSGI runtimes.
