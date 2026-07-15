import asyncio
import logging

import structlog

from .settings import settings

log = structlog.get_logger()


def setup_telemetry() -> None:
    """Initialize OpenTelemetry tracing when OTEL_EXPORTER_OTLP_ENDPOINT is configured."""
    if not settings.otel_exporter_otlp_endpoint:
        return
    from opentelemetry import trace
    from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
    from opentelemetry.sdk.resources import Resource
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import BatchSpanProcessor

    resource = Resource.create({"service.name": settings.otel_service_name})
    provider = TracerProvider(resource=resource)
    provider.add_span_processor(
        BatchSpanProcessor(OTLPSpanExporter(endpoint=settings.otel_exporter_otlp_endpoint))
    )
    trace.set_tracer_provider(provider)


def configure_logging() -> None:
    """Configure structlog with JSON output when LOGGING_STRUCTURED=true."""
    processors: list = [
        structlog.contextvars.merge_contextvars,
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
    ]
    if settings.logging_structured:
        processors.append(structlog.processors.JSONRenderer())
    else:
        processors.append(structlog.dev.ConsoleRenderer())

    structlog.configure(
        processors=processors,
        wrapper_class=structlog.make_filtering_bound_logger(
            logging.getLevelName(settings.log_level)
        ),
        logger_factory=structlog.PrintLoggerFactory(),
    )


async def run() -> None:
    from . import management, servicer
{% if persistence ~= 'None' %}
    from .persistence import init_db, close_db
    await init_db(settings)

    # Sample scaffold: importing the domain module registers its entities on the
    # persistence Base; ensure_schema creates any missing tables. Replace with
    # real migrations (alembic) as the domain solidifies.
    from .domain import items  # noqa: F401
    from .persistence import ensure_schema
    await ensure_schema()
{% endif %}
{% if cache ~= 'None' %}
    from .cache import init_cache, close_cache
    await init_cache(settings)
{% endif %}
{% if messaging ~= 'None' %}
    from .messaging import init_messaging, close_messaging
    await init_messaging(settings)
{% endif %}
{% if has_s3 %}
    from .storage.s3 import init_s3, close_s3
    await init_s3(settings)
{% endif %}
{% if has_azure_blob %}
    from .storage.azure_blob import init_azure_blob, close_azure_blob
    await init_azure_blob(settings)
{% endif %}
    log.info(
        "{{ project-name }} starting",
        grpc_port=settings.port,
        management_port=settings.management_port,
    )

    try:
        await asyncio.gather(
            servicer.serve(settings),
            management.serve(settings),
        )
    finally:
{% if persistence ~= 'None' %}
        await close_db()
{% endif %}
{% if cache ~= 'None' %}
        await close_cache()
{% endif %}
{% if messaging ~= 'None' %}
        await close_messaging()
{% endif %}
{% if has_s3 %}
        await close_s3()
{% endif %}
{% if has_azure_blob %}
        await close_azure_blob()
{% endif %}
        log.info("{{ project-name }} stopped")


def main() -> None:
    configure_logging()
    setup_telemetry()
    asyncio.run(run())


if __name__ == "__main__":
    main()
