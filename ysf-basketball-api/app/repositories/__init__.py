"""Persistence layer.

The only place in the codebase that talks to the database. Routers call these
functions; business rules stay in ``app.services``. Keeping queries here means
the algorithm can be tested with plain tuples and the HTTP layer never has to
know SQLAlchemy exists.
"""
