.PHONY: proto test run

# `proto` regenerates the gRPC stubs from the .proto definition. grpc_tools emits a
# top-level `import <pkg>_pb2` in *_pb2_grpc.py; the sed step rewrites it to a
# package-relative import so the stub resolves when loaded as a submodule of the
# service package (otherwise the server fails to start with ModuleNotFoundError).
proto:
	uv run python -m grpc_tools.protoc \
		--python_out=src/{{ prefix_name }}_{{ suffix_name }} \
		--grpc_python_out=src/{{ prefix_name }}_{{ suffix_name }} \
		--proto_path=proto \
		proto/{{ prefix_name }}_{{ suffix_name }}.proto
	# grpc_tools emits a top-level `import {{ prefix_name }}_{{ suffix_name }}_pb2`,
	# which fails when the stubs are imported as package submodules. Rewrite it
	# to a package-relative import so `from . import ..._pb2_grpc` works.
	sed -i.bak 's/^import {{ prefix_name }}_{{ suffix_name }}_pb2 /from . import {{ prefix_name }}_{{ suffix_name }}_pb2 /' \
		src/{{ prefix_name }}_{{ suffix_name }}/{{ prefix_name }}_{{ suffix_name }}_pb2_grpc.py
	rm -f src/{{ prefix_name }}_{{ suffix_name }}/{{ prefix_name }}_{{ suffix_name }}_pb2_grpc.py.bak

test:
	uv run pytest

run: proto
	uv run {{ project-name }}
