--- Render-verification suite for the Python gRPC service archetype: each persistence variant lays
--- out correctly and is fully rendered, and the hollow (None) rendering stays hollow.
---
--- The BEHAVIORAL bar — CRUD through the production image (which runs the protoc codegen), the
--- platform env contract, health/metrics/structured logs, both name shapes — lives in
--- tests/standards_test.lua (the shared p6m standards suite), fully containerized: docker is the
--- only requirement. No host toolchain is invoked here either (S8b): compile coverage is
--- containerized — the standards SUT builds each persistence variant's production image, and the
--- hollow (None) rendering is proven by a docker-gated `docker.build` of its production
--- Dockerfile below. The rendered project's own unit tests belong to the rendered project's CI,
--- not to this suite.
---
--- Run from the archetype repo root (uses ./prova.toml):   prova

local p6m = require("p6m")

local SRC = "."

-- prefix Example / suffix Service => project dir `example-service`, package `example_service`,
-- proto package `example_service`, gRPC service `ExampleService`.
local PROJECT_DIR = "example-service"

local BASE_ANSWERS = {
  project_name = "example-service",
  solution_name = "acme-platform",
  entity_name = "example",
  image_registry = "ghcr.io/acme",
}

-- NOTE: named, and that is load-bearing. `ctx:tempdir("render1")` is ADDRESSED, not created, so every
-- unnamed call in one scope answers with the SAME directory: two renders into one destination
-- leave the first winner in place and the second silently asserts against it. That is what made
-- the hollow variant see the persistence variant's files.
local function answers_with(extra)
  local out = {}
  for k, v in pairs(BASE_ANSWERS) do out[k] = v end
  for k, v in pairs(extra) do out[k] = v end
  return out
end

-- Files the persistence scaffold must produce (relative to the rendered project root):
-- the archetype's sample entity + persisted servicer, and the resource library's wiring.
local SCAFFOLD_FILES = {
  "src/example_service/domain/examples.py",
  "src/example_service/services/examples.py",
  "src/example_service/persistence/__init__.py",
  "src/example_service/persistence/models.py",
}

for _, persistence in ipairs({ "PostgreSQL", "MySQL" }) do
  local label = "python-grpc[" .. persistence .. "]"

  local project = prova.fixture(label .. ":project", Scope.File, function(ctx)
    return archetect.render{
      source = SRC,
      answers = answers_with{ persistence = persistence },
      destination = ctx:tempdir("render1"),
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
  })
end

-- The hollow rendering stays hollow: no persistence, no scaffold files.
local none_project = prova.fixture("python-grpc[None]:project", Scope.File, function(ctx)
  return archetect.render{
    source = SRC,
    answers = answers_with{ persistence = "None" },
    destination = ctx:tempdir("render2"),
    defaults = true,
  }
end)

archetect.verify(none_project, {
  name = "python-grpc[None]",
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
})

-- Containerized compile proof for the hollow variant (S8b): the persistence variants compile
-- inside the standards SUT image builds; None never boots there, so prove it compiles (protoc
-- codegen included) by building its production image — build success IS the compile check.
prova.group("python-grpc[None]:image", { requires = { "docker" } }, function(g)
  g:test("production image builds from a clean render", function(t)
    local root = t:use(none_project):dir(PROJECT_DIR)
    local image = docker.build{
      context = root.path,
      dockerfile = ".platform/docker/prd/Dockerfile",
    }
    t:expect(image, "built image"):never():is_nil()
  end)
end)

-- CI parity (S10): the rendered project's own Build workflow path — python-uv-setup/
-- python-uv-build's exact command sequence on a fresh clone, in the toolchain image. The
-- Dockerfile and CI are two independent build paths; S10 holds the second. The hollow render
-- suffices: resource variants change dependencies, not the command path.
prova.group("python-grpc[None]:ci", { requires = { "docker" }, tags = { "standards" } }, function(g)
  p6m.standards.ci_parity(g, none_project, {
    stack = "python",
    project_dir = "example-service",
    name = "python-grpc",
  })
end)
