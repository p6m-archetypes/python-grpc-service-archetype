import grpc
{% if persistence == 'None' %}
from grpc import ServicerContext
{% endif %}

from .settings import settings


async def serve(settings) -> None:
    # Import generated proto code inside function — run 'make proto' to generate first
    from . import (  # type: ignore[reportMissingModuleSource]
        {{ project_name }}_pb2 as pb2_module,
        {{ project_name }}_pb2_grpc as grpc_module,
    )

    from grpc_health.v1 import health, health_pb2_grpc
    from grpc_reflection.v1alpha import reflection

{% if persistence ~= 'None' %}
    # Sample scaffold: CRUD handlers persisted through the persistence resource
    # (services/items.py over domain/items.py). Replace as your real domain lands.
    from .services.{{ entity_name }}s import Persisted{{ ProjectName }}Servicer

    servicer = Persisted{{ ProjectName }}Servicer()
{% else %}
    servicer = {{ ProjectName }}Servicer()
{% endif %}
    server = grpc.aio.server()
    grpc_module.add_{{ ProjectName }}Servicer_to_server(servicer, server)

    health_servicer = health.HealthServicer()
    health_pb2_grpc.add_HealthServicer_to_server(health_servicer, server)

    service_names = (
        pb2_module.DESCRIPTOR.services_by_name["{{ ProjectName }}"].full_name,
        health.SERVICE_NAME,
        reflection.SERVICE_NAME,
    )
    reflection.enable_server_reflection(service_names, server)

    listen_addr = f"[::]:{settings.port}"
    server.add_insecure_port(listen_addr)
    await server.start()
    await server.wait_for_termination()


{% if persistence == 'None' %}
class {{ ProjectName }}Servicer:
    """UNIMPLEMENTED stubs — select a persistence option to render the persisted CRUD scaffold."""

    async def Create{{ EntityName }}(self, request, context: ServicerContext):
        context.set_code(grpc.StatusCode.UNIMPLEMENTED)
        context.set_details("Not implemented")
        raise NotImplementedError

    async def Get{{ EntityName }}(self, request, context: ServicerContext):
        context.set_code(grpc.StatusCode.UNIMPLEMENTED)
        context.set_details("Not implemented")
        raise NotImplementedError

    async def List{{ EntityName }}s(self, request, context: ServicerContext):
        context.set_code(grpc.StatusCode.UNIMPLEMENTED)
        context.set_details("Not implemented")
        raise NotImplementedError

    async def Update{{ EntityName }}(self, request, context: ServicerContext):
        context.set_code(grpc.StatusCode.UNIMPLEMENTED)
        context.set_details("Not implemented")
        raise NotImplementedError

    async def Delete{{ EntityName }}(self, request, context: ServicerContext):
        context.set_code(grpc.StatusCode.UNIMPLEMENTED)
        context.set_details("Not implemented")
        raise NotImplementedError
{% if cache ~= 'None' %}
    # Access cache via: from .cache import get_cache
{% endif %}{% if messaging ~= 'None' %}
    # Access messaging via: from .messaging import get_producer
{% endif %}
{% endif %}
