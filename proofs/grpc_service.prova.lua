--- Render-verification suite for the Python gRPC service archetype: each persistence variant lays
--- out correctly and is fully rendered, and the hollow (None) rendering stays hollow.
---
--- Every rendering comes from `p6m.spec{}` + `p6m.render` — the shape harness — so the paths this
--- file expects are BUILT from the same identity the archetype was answered with, never spelled by
--- hand. A hand-spelled path list is how `.../items.py` outlived the entity it was named for.
---
--- The BEHAVIORAL bar — CRUD through the production image, the platform env contract, health/
--- metrics/structured logs, both name shapes — lives in proofs/standards.prova.lua, which also owns
--- S10 CI parity. No host toolchain is invoked here (S8b): compile coverage is containerized, and
--- the hollow rendering is proven by building its production Dockerfile below.

local p6m = require("p6m")

local function spec_for(persistence)
  return p6m.spec{
    language = "python", shape = "full", transport = "grpc",
    project = "example-service", entity = "example", solution = "acme-platform",
    persistence = persistence, registry = "ghcr.io/acme",
  }
end

-- The layout, derived from the spec. `pkg` is the python package the project renders into and
-- `mod` the entity-named scaffold module — both follow the identity, so a renamed entity moves
-- these with it instead of leaving a stale literal behind.
local function paths(s)
  local pkg = "src/" .. s.id.project_snake
  local mod = s.id.entity_snake .. "s.py"
  return {
    base = {
      "pyproject.toml",
      ".python-version",
      ".dockerignore",
      pkg .. "/__init__.py",
      pkg .. "/main.py",
      pkg .. "/settings.py",
      ".github/workflows/build.yaml",
      ".platform/docker/local/Dockerfile",
      ".platform/docker/prd/Dockerfile",
    },
    scaffold = {
      pkg .. "/domain/" .. mod,
      pkg .. "/persistence/__init__.py",
      pkg .. "/persistence/models.py",
    },
  }
end

for _, persistence in ipairs({ "PostgreSQL", "MySQL" }) do
  local s = spec_for(persistence)
  local f = paths(s)

  local expected = {}
  for _, x in ipairs(f.base) do expected[#expected + 1] = x end
  for _, x in ipairs(f.scaffold) do expected[#expected + 1] = x end

  archetect.verify{
    name = s.label,
    source = ".",
    answers = s.answers,
    project_dir = s.project_dir,
    expected_files = expected,
    yaml_globs = { ".platform/kubernetes/**/*.yaml" },
  }
end

-- The hollow rendering stays hollow: no persistence module, no scaffold files.
local none = spec_for("None")
local none_paths = paths(none)
local none_project = p6m.render(none)

archetect.verify(none_project, {
  name = none.label,
  project_dir = none.project_dir,
  expected_files = none_paths.base,
  absent_files = none_paths.scaffold,
  yaml_globs = { ".platform/kubernetes/**/*.yaml" },
})

-- Containerized compile proof for the hollow variant (S8b): the persistence variants compile
-- inside the standards SUT image builds; None never boots there, so prove it compiles by
-- building its production image — build success IS the compile check, no boot needed.
prova.group(none.label .. ":image", { requires = { "docker" } }, function(g)
  g:test("production image builds from a clean render", function(t)
    local root = t:use(none_project):dir(none.project_dir)
    local image = docker.build{
      context = root.path,
      dockerfile = ".platform/docker/prd/Dockerfile",
    }
    t:expect(image, "built image"):never():is_nil()
  end)
end)
