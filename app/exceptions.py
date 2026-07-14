from fastapi import FastAPI


def register_exception_handlers(app: FastAPI) -> None:
    """Register application exception handlers as they are introduced."""
    _ = app
