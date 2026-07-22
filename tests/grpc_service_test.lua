--- Render-verification suite for the Python gRPC service archetype: each persistence variant lays
--- out correctly and is fully rendered, and the hollow (None) rendering stays hollow.
---
--- The BEHAVIORAL bar — CRUD through the production image (which runs the protoc codegen), the
--- platform env contract, health/metrics/structured logs, both name shapes — lives in
--- tests/standards_test.lua (the shared p6m standards suite), fully containerized: docker is the
--- only requirement. The `build_steps` here are gated on host `uv` and skip cleanly where it's
--- absent.
---
--- Run from the archetype repo root (uses ./prova.toml):   prova

local SRC = "."

-- prefix Example / suffix Service => project dir `example-service`, package `example_service`,
-- proto package `example_service`, gRPC service `ExampleService`.
local PROJECT_DIR = "example-service"

local BASE_ANSWERS = {
  author_name    = "Test Author",
  author_email   = "test@example.com",
  org_name       = "acme",
  solution_name  = "platform",
  prefix_name    = "Example",
  suffix_name    = "Service",
  image_registry = "ghcr.io/acme",
}

local function answers_with(extra)
  local out = {}
  for k, v in pairs(BASE_ANSWERS) do out[k] = v end
  for k, v in pairs(extra) do out[k] = v end
  return out
end

-- Files the persistence scaffold must produce (relative to the rendered project root):
-- the archetype's sample entity + persisted servicer, and the resource library's wiring.
local SCAFFOLD_FILES = {
  "src/example_service/domain/items.py",
  "src/example_service/services/items.py",
  "src/example_service/persistence/__init__.py",
  "src/example_service/persistence/models.py",
}

for _, persistence in ipairs({ "PostgreSQL", "MySQL" }) do
  local label = "python-grpc[" .. persistence .. "]"

  local project = prova.fixture(label .. ":project", Scope.File, function(ctx)
    return archetect.render{
      source = SRC,
      answers = answers_with{ persistence = persistence },
      destination = ctx:tempdir(),
      defaults = true,
    }
  end)

  archetect.verify(project, {
    name = label,
    project_dir = PROJECT_DIR,
    expected_files = {
      "pyproject.toml",
      ".python-version",
      ".dockerignore",
      "Makefile",
      "proto/example_service.proto",
      "src/example_service/__init__.py",
      "src/example_service/main.py",
      "src/example_service/servicer.py",
      "src/example_service/management.py",
      "src/example_service/settings.py",
      "tests/test_health.py",
      SCAFFOLD_FILES[1], SCAFFOLD_FILES[2], SCAFFOLD_FILES[3], SCAFFOLD_FILES[4],
      ".github/workflows/build.yaml",
      ".platform/docker/local/Dockerfile",
      ".platform/docker/prd/Dockerfile",
    },
    yaml_globs = { ".platform/kubernetes/**/*.yaml" },
    requires = { "uv" },
    build_steps = { "uv sync --group dev", "uv run pytest -q" },
  })
end

-- The hollow rendering stays hollow: no persistence, no scaffold files.
archetect.verify{
  name = "python-grpc[None]",
  source = SRC,
  answers = answers_with{ persistence = "None" },
  project_dir = PROJECT_DIR,
  expected_files = {
    "pyproject.toml",
    "proto/example_service.proto",
    "src/example_service/main.py",
    "src/example_service/servicer.py",
    "src/example_service/settings.py",
  },
  absent_files = SCAFFOLD_FILES,
  yaml_globs = { ".platform/kubernetes/**/*.yaml" },
  requires = { "uv" },
  build_steps = { "uv sync --group dev", "uv run pytest -q" },
}
