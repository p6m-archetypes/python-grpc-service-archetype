from datetime import datetime

from sqlalchemy import DateTime, String, func
from sqlalchemy.orm import Mapped, mapped_column

from ..persistence.models import Base


# Sample scaffold entity proving the persistence round trip end-to-end.
# Replace with your real domain model (and rename the handlers in services/items.py to match).
class {{ EntityName }}(Base):
    __tablename__ = "{{ entity_name }}s"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    display_name: Mapped[str] = mapped_column(String(255), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
