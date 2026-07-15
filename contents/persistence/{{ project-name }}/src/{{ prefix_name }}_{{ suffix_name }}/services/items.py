from uuid import uuid4

import grpc
from grpc import ServicerContext
from sqlalchemy import select

# Generated proto stubs — run `make proto` first. This module is imported lazily
# (from servicer.serve) so the package stays importable before codegen.
from .. import {{ prefix_name }}_{{ suffix_name }}_pb2 as pb2  # type: ignore[reportMissingModuleSource]
from ..domain.items import Item
from ..persistence import get_session


def _to_message(item: Item) -> pb2.{{ PrefixName }}:
    return pb2.{{ PrefixName }}(id=item.id, display_name=item.display_name)


# Sample scaffold servicer: CRUD over the persisted Item entity (domain/items.py) —
# the round trip a black-box test can prove end-to-end. Replace these handlers
# (and the RPCs in proto/{{ prefix_name }}_{{ suffix_name }}.proto) as your real domain lands.
class Persisted{{ PrefixName }}{{ SuffixName }}Servicer:
    async def Create{{ PrefixName }}(self, request, context: ServicerContext) -> "pb2.{{ PrefixName }}":
        item = Item(id=str(uuid4()), display_name=request.display_name)
        async with get_session() as session:
            session.add(item)
            await session.commit()
        return _to_message(item)

    async def Get{{ PrefixName }}(self, request, context: ServicerContext) -> "pb2.{{ PrefixName }}":
        async with get_session() as session:
            item = await session.get(Item, request.id)
            if item is None:
                await context.abort(grpc.StatusCode.NOT_FOUND, f"no item with id '{request.id}'")
            return _to_message(item)

    async def List{{ PrefixName }}s(self, request, context: ServicerContext) -> "pb2.List{{ PrefixName }}sResponse":
        async with get_session() as session:
            result = await session.execute(select(Item).order_by(Item.created_at))
            return pb2.List{{ PrefixName }}sResponse(
                items=[_to_message(item) for item in result.scalars()]
            )

    async def Update{{ PrefixName }}(self, request, context: ServicerContext) -> "pb2.{{ PrefixName }}":
        async with get_session() as session:
            item = await session.get(Item, request.id)
            if item is None:
                await context.abort(grpc.StatusCode.NOT_FOUND, f"no item with id '{request.id}'")
            item.display_name = request.display_name
            await session.commit()
            return _to_message(item)

    async def Delete{{ PrefixName }}(self, request, context: ServicerContext) -> "pb2.Delete{{ PrefixName }}Response":
        async with get_session() as session:
            item = await session.get(Item, request.id)
            if item is None:
                await context.abort(grpc.StatusCode.NOT_FOUND, f"no item with id '{request.id}'")
            await session.delete(item)
            await session.commit()
        return pb2.Delete{{ PrefixName }}Response()
