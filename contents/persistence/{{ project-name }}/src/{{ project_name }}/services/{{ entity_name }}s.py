from uuid import uuid4

import grpc
from grpc import ServicerContext
from sqlalchemy import select

# Generated proto stubs — run `make proto` first. This module is imported lazily
# (from servicer.serve) so the package stays importable before codegen.
from .. import {{ project_name }}_pb2 as pb2  # type: ignore[reportMissingModuleSource]
from ..domain.{{ entity_name }}s import {{ EntityName }}Entity
from ..persistence import get_session


def _to_message(item: {{ EntityName }}) -> pb2.{{ EntityName }}:
    return pb2.{{ EntityName }}Entity(id=item.id, display_name=item.display_name)


# Sample scaffold servicer: CRUD over the persisted {{ EntityName }} entity (domain/items.py) —
# the round trip a black-box test can prove end-to-end. Replace these handlers
# (and the RPCs in proto/{{ project_name }}.proto) as your real domain lands.
class Persisted{{ ProjectName }}Servicer:
    async def Create{{ EntityName }}(self, request, context: ServicerContext) -> "pb2.{{ EntityName }}":
        item = {{ EntityName }}Entity(id=str(uuid4()), display_name=request.display_name)
        async with get_session() as session:
            session.add(item)
            await session.commit()
        return _to_message(item)

    async def Get{{ EntityName }}(self, request, context: ServicerContext) -> "pb2.{{ EntityName }}":
        async with get_session() as session:
            item = await session.get({{ EntityName }}Entity, request.id)
            if item is None:
                await context.abort(grpc.StatusCode.NOT_FOUND, f"no item with id '{request.id}'")
            return _to_message(item)

    async def List{{ EntityName }}s(self, request, context: ServicerContext) -> "pb2.List{{ EntityName }}sResponse":
        async with get_session() as session:
            result = await session.execute(select({{ EntityName }}Entity).order_by({{ EntityName }}Entity.created_at))
            return pb2.List{{ EntityName }}sResponse(
                items=[_to_message(item) for item in result.scalars()]
            )

    async def Update{{ EntityName }}(self, request, context: ServicerContext) -> "pb2.{{ EntityName }}":
        async with get_session() as session:
            item = await session.get({{ EntityName }}Entity, request.id)
            if item is None:
                await context.abort(grpc.StatusCode.NOT_FOUND, f"no item with id '{request.id}'")
            item.display_name = request.display_name
            await session.commit()
            return _to_message(item)

    async def Delete{{ EntityName }}(self, request, context: ServicerContext) -> "pb2.Delete{{ EntityName }}Response":
        async with get_session() as session:
            item = await session.get({{ EntityName }}Entity, request.id)
            if item is None:
                await context.abort(grpc.StatusCode.NOT_FOUND, f"no item with id '{request.id}'")
            await session.delete(item)
            await session.commit()
        return pb2.Delete{{ EntityName }}Response()
