import grpc
{% if persistence == 'None' %}
from grpc import ServicerContext
{% endif %}

from .settings import settings


async def serve(settings) -> None:
    # Import generated proto code inside function — run 'make proto' to generate first
    from . import (  # type: ignore[reportMissingModuleSource]
        {{ prefix_name }}_{{ suffix_name }}_pb2 as pb2_module,
        {{ prefix_name }}_{{ suffix_name }}_pb2_grpc as grpc_module,
    )

    from grpc_health.v1 import health, health_pb2_grpc
    from grpc_reflection.v1alpha import reflection

{% if persistence ~= 'None' %}
    # Sample scaffold: CRUD handlers persisted through the persistence resource
    # (services/items.py over domain/items.py). Replace as your real domain lands.
    from .services.items import Persisted{{ PrefixName }}{{ SuffixName }}Servicer

    servicer = Persisted{{ PrefixName }}{{ SuffixName }}Servicer()
{% else %}
    servicer = {{ PrefixName }}{{ SuffixName }}Servicer()
{% endif %}
    server = grpc.aio.server()
    grpc_module.add_{{ PrefixName }}{{ SuffixName }}Servicer_to_server(servicer, server)

    health_servicer = health.HealthServicer()
    health_pb2_grpc.add_HealthServicer_to_server(health_servicer, server)

    service_names = (
        pb2_module.DESCRIPTOR.services_by_name["{{ PrefixName }}{{ SuffixName }}"].full_name,
        health.SERVICE_NAME,
        reflection.SERVICE_NAME,
    )
    reflection.enable_server_reflection(service_names, server)

    listen_addr = f"[::]:{settings.port}"
    server.add_insecure_port(listen_addr)
    await server.start()
    await server.wait_for_termination()


{% if persistence == 'None' %}
class {{ PrefixName }}{{ SuffixName }}Servicer:
    """UNIMPLEMENTED stubs — select a persistence option to render the persisted CRUD scaffold."""

    async def Create{{ PrefixName }}(self, request, context: ServicerContext):
        context.set_code(grpc.StatusCode.UNIMPLEMENTED)
        context.set_details("Not implemented")
        raise NotImplementedError

    async def Get{{ PrefixName }}(self, request, context: ServicerContext):
        context.set_code(grpc.StatusCode.UNIMPLEMENTED)
        context.set_details("Not implemented")
        raise NotImplementedError

    async def List{{ PrefixName }}s(self, request, context: ServicerContext):
        context.set_code(grpc.StatusCode.UNIMPLEMENTED)
        context.set_details("Not implemented")
        raise NotImplementedError

    async def Update{{ PrefixName }}(self, request, context: ServicerContext):
        context.set_code(grpc.StatusCode.UNIMPLEMENTED)
        context.set_details("Not implemented")
        raise NotImplementedError

    async def Delete{{ PrefixName }}(self, request, context: ServicerContext):
        context.set_code(grpc.StatusCode.UNIMPLEMENTED)
        context.set_details("Not implemented")
        raise NotImplementedError
{% if cache ~= 'None' %}
    # Access cache via: from .cache import get_cache
{% endif %}{% if messaging ~= 'None' %}
    # Access messaging via: from .messaging import get_producer
{% endif %}
{% endif %}
