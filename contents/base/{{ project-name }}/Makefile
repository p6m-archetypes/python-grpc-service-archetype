.PHONY: proto test run

proto:
	uv run python -m grpc_tools.protoc \
		--python_out=src/{{ prefix_name }}_{{ suffix_name }} \
		--grpc_python_out=src/{{ prefix_name }}_{{ suffix_name }} \
		--proto_path=proto \
		proto/{{ prefix_name }}_{{ suffix_name }}.proto

test:
	uv run pytest

run: proto
	uv run {{ project-name }}
