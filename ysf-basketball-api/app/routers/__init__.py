"""HTTP layer.

Routers translate between HTTP and the rest of the app: validate the request
(schemas), fetch rows (repositories), apply rules (services), shape the reply
(presenters). They contain no balancing logic of their own.
"""
