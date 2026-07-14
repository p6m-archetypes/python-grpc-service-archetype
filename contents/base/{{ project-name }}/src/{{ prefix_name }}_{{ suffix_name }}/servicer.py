import grpc
from grpc import ServicerContext

from .settings import settings


async def serve(settings) -> None:
    # Import generated proto code inside function — run 'make proto' to generate first
    from . import (  # type: ignore[reportMissingModuleSource]
        {{ prefix_name }}_{{ suffix_name }}_pb2 as pb2,
        {{ prefix_name }}_{{ suffix_name }}_pb2_grpc as grpc_module,
    )

    from grpc_health.v1 import health, health_pb2_grpc
    from grpc_reflection.v1alpha import reflection

    servicer = {{ PrefixName }}{{ SuffixName }}Servicer()
    server = grpc.aio.server()
    grpc_module.add_{{ PrefixName }}{{ SuffixName }}Servicer_to_server(servicer, server)

    health_servicer = health.HealthServicer()
    health_pb2_grpc.add_HealthServicer_to_server(health_servicer, server)

    service_names = (
        pb2.DESCRIPTOR.services_by_name["{{ PrefixName }}{{ SuffixName }}"].full_name,
        health.SERVICE_NAME,
        reflection.SERVICE_NAME,
    )
    reflection.enable_server_reflection(service_names, server)

    listen_addr = f"[::]:{settings.port}"
    server.add_insecure_port(listen_addr)
    await server.start()
    await server.wait_for_termination()


class {{ PrefixName }}{{ SuffixName }}Servicer:
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
{% if persistence ~= 'None' %}
    # Access database via: from .persistence import get_session
{% endif %}{% if cache ~= 'None' %}
    # Access cache via: from .cache import get_cache
{% endif %}{% if messaging ~= 'None' %}
    # Access messaging via: from .messaging import get_producer
{% endif %}
