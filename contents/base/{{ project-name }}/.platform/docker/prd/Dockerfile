FROM python:3.12-slim AS builder
WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Install pip and uv
RUN pip install --no-cache-dir uv

# Generate the gRPC stubs into the package before installing it (grpc_tools bundles protoc).
# The sed mirrors the Makefile's rewrite to a package-relative import: raw codegen emits a
# top-level `import ..._pb2` that fails once the stubs load as package submodules.
COPY pyproject.toml ./
COPY proto/ ./proto/
COPY src/ ./src/
RUN uv pip install --system --no-cache grpcio-tools && \
    python -m grpc_tools.protoc \
    -I proto \
    --python_out=src/{{ prefix_name }}_{{ suffix_name }} \
    --grpc_python_out=src/{{ prefix_name }}_{{ suffix_name }} \
    proto/{{ prefix_name }}_{{ suffix_name }}.proto && \
    sed -i 's/^import {{ prefix_name }}_{{ suffix_name }}_pb2 /from . import {{ prefix_name }}_{{ suffix_name }}_pb2 /' \
    src/{{ prefix_name }}_{{ suffix_name }}/{{ prefix_name }}_{{ suffix_name }}_pb2_grpc.py

# Install the package with the generated stubs baked in
RUN uv pip install --system --no-cache .

FROM python:3.12-slim
WORKDIR /app

# Install CA certificates for TLS
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN addgroup --system --gid 1001 appgroup && \
    adduser --system --uid 1001 --gid 1001 appuser

# Copy installed packages from builder
COPY --from=builder /usr/local/lib/python3.12 /usr/local/lib/python3.12
COPY --from=builder /usr/local/bin/{{ project-name }} /usr/local/bin/{{ project-name }}

# Copy application source (with generated proto stubs)
COPY --from=builder /app/src/ ./src/

USER appuser

EXPOSE {{ service_port }} {{ management_port }}

ENTRYPOINT ["{{ project-name }}"]
