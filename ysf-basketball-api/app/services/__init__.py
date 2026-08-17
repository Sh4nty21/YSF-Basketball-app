"""Business logic layer.

Everything in here decides *what the data should be* (spec Section 3, golden
rule). These modules are pure Python — they never import SQLAlchemy or
FastAPI — so they can be unit-tested without a database or an HTTP client.
"""
