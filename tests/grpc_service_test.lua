--- Acceptance suite for the Python gRPC service archetype (grpcio + reflection + a FastAPI
--- management sidecar). Renders the project, verifies the layout and template substitution,
--- installs it, runs its own unit suite, then generates the proto stubs, boots the real gRPC
--- server, and proves over the wire that: server reflection discovers the service, the gRPC health
--- service reports SERVING, the (stub) RPCs answer UNIMPLEMENTED, and the management sidecar (health
--- probes + Prometheus metrics) responds.
---
--- The default configuration weaves in no resources (persistence/cache/messaging = None); the RPC
--- handlers are UNIMPLEMENTED stubs. The gRPC server binds one port; the management sidecar a second.
---
--- prova's in-process archetect engine renders once per run (prova.toml pins jobs = 1), so the whole
--- suite shares a single rendered tree (the `project` fixture). The static tier reads it with no
--- toolchain; the build tier requires `uv`; the live tier additionally requires `make` (the proto
--- codegen step) and skips cleanly when either is absent.
---
--- Run from the archetype repo root (uses ./prova.toml):   prova

local SRC = "."

local ANSWERS = {
  author_name    = "Test Author",
  author_email   = "test@example.com",
  org_name       = "acme",
  solution_name  = "platform",
  prefix_name    = "Example",
  suffix_name    = "Service",
  image_registry = "ghcr.io/acme",
}

-- prefix Example / suffix Service => project dir `example-service`, package `example_service`,
-- proto package `example_service`, gRPC service `ExampleService`.
local PROJECT_DIR = "example-service"
local SVC = "example_service.ExampleService"

local EXPECTED_FILES = {
  "pyproject.toml",
  ".python-version",
  "Makefile",
  "proto/example_service.proto",
  "src/example_service/__init__.py",
  "src/example_service/main.py",
  "src/example_service/servicer.py",
  "src/example_service/management.py",
  "src/example_service/settings.py",
  "tests/test_health.py",
  ".github/workflows/build.yaml",
  ".platform/docker/local/Dockerfile",
  ".platform/docker/prd/Dockerfile",
}

-- Render once for the whole suite (single in-process render; every tier shares this one tree).
local project = prova.fixture("python-grpc:project", Scope.Suite, function(ctx)
  local tree = archetect.render{
    source = SRC,
    answers = ANSWERS,
    destination = ctx:tempdir(),
    defaults = true,
  }
  return tree:dir(PROJECT_DIR)
end)

-- Install once (shared by the build tier and the live-service fixture). Only reached from uv-gated
-- groups, so `uv` is guaranteed present here.
local installed = prova.fixture("python-grpc:installed", Scope.Suite, function(ctx)
  local root = ctx:use(project)
  local sync = shell.run("uv sync --group dev", { cwd = root.path, timeout = "300s" })
  assert(sync:ok(), "uv sync failed:\n" .. sync.stderr .. sync.stdout)
  return root
end)

-- Generate the gRPC stubs (`make proto`) then boot the server on free ports. Waiting on both the
-- gRPC reflection endpoint and the management sidecar proves the whole process came up. Only reached
-- from the live group (requires uv + make).
local service = prova.fixture("python-grpc:service", Scope.Suite, function(ctx)
  local root = ctx:use(installed)

  local proto = shell.run("make proto", { cwd = root.path, timeout = "180s" })
  assert(proto:ok(), "make proto failed:\n" .. proto.stderr .. proto.stdout)

  local port, mgmt = net.free_port(), net.free_port()
  ctx:manage(shell.spawn("uv run " .. PROJECT_DIR, {
    cwd = root.path,
    env = {
      HOST            = "127.0.0.1",
      PORT            = tostring(port),
      MANAGEMENT_PORT = tostring(mgmt),
    },
  }))

  local addr = "127.0.0.1:" .. port
  local mgmt_url = "http://127.0.0.1:" .. mgmt
  -- Reflection answering proves the gRPC server is serving; liveness proves the sidecar is too.
  grpc.wait_for(addr, { timeout = "60s" })
  http.wait_for(mgmt_url .. "/health/liveness", { timeout = "60s" })
  return { addr = addr, mgmt_url = mgmt_url }
end)

-- Tier 1 - static: layout, template substitution, and generated k8s manifests. No toolchain.
prova.group("python-grpc layout", function(g)
  g:test("scaffolds the expected project layout", function(t)
    local root = t:use(project).path
    t:expect_all(function()
      for _, f in ipairs(EXPECTED_FILES) do
        t:expect(fs.exists(root .. "/" .. f), f):is_true()
      end
    end)
  end)

  g:test("wires prefix/suffix and ports through file contents", function(t)
    local root = t:use(project).path
    -- The proto declares package example_service + service ExampleService.
    local proto = fs.read(root .. "/proto/example_service.proto")
    t:expect(proto, "proto package"):contains("package example_service")
    t:expect(proto, "proto service"):contains("service ExampleService")
    -- The servicer implements that service.
    t:expect(fs.read(root .. "/src/example_service/servicer.py"), "servicer class")
      :contains("ExampleServiceServicer")
    -- service-port + derived management-port land in settings.
    local settings = fs.read(root .. "/src/example_service/settings.py")
    t:expect(settings, "service port"):contains("port: int = 8080")
    t:expect(settings, "management port"):contains("management_port: int = 8081")
  end)

  g:test("renders valid, non-empty kubernetes manifests", function(t)
    local root = t:use(project).path
    local manifests = fs.glob(root, ".platform/kubernetes/**/*.yaml")
    t:expect(#manifests > 0, "at least one k8s manifest"):is_true()
    t:expect_all(function()
      for _, m in ipairs(manifests) do
        local docs = yaml.parse_all(fs.read(m))
        t:expect(#docs > 0, m .. " has ≥1 document"):is_true()
      end
    end)
  end)

  g:test("leaves no unrendered template markers", function(t)
    t:expect(t:use(project)):is_fully_rendered()
  end)
end)

-- Tier 2 - build + unit: the generated project's own pytest suite passes.
prova.group("python-grpc build + unit tests", { requires = { "uv" } }, function(g)
  g:test("the generated pytest suite passes", function(t)
    local root = t:use(installed).path
    local pytest = shell.run("uv run pytest -q", { cwd = root, timeout = "180s" })
    t:expect(pytest.code, "pytest exit code"):equals(0)
    t:expect(pytest.stdout .. pytest.stderr, "pytest reports a passing suite"):contains("passed")
  end)
end)

-- Tier 3 - live gRPC: the running server answers reflection, health, and RPC calls; the management
-- sidecar answers real HTTP requests.
prova.group("python-grpc endpoints", { requires = { "uv", "make" } }, function(g)
  g:test("server reflection exposes the service and stub RPCs answer UNIMPLEMENTED", function(t)
    local svc = t:use(service)
    -- grpc.connect performs reflection to discover the schema - success means it is enabled.
    local client = grpc.connect(svc.addr)
    -- The default config leaves the handlers as UNIMPLEMENTED stubs.
    local res = client:call_status(SVC .. "/CreateExample", { display_name = "widget" })
    t:expect(res.ok, "stub RPC does not succeed"):is_falsy()
    t:expect(res.code, "stub RPC status code"):equals("Unimplemented")
  end)

  g:test("the gRPC health service reports SERVING", function(t)
    local svc = t:use(service)
    local client = grpc.connect(svc.addr)
    local health = client:call("grpc.health.v1.Health/Check", {})
    t:expect(health.status, "overall health status"):equals("SERVING")
  end)

  g:test("the management sidecar reports readiness and liveness", function(t)
    local svc = t:use(service)

    local ready = http.get(svc.mgmt_url .. "/health/readiness")
    t:expect(ready.status, "readiness status code"):equals(200)
    t:expect(ready:json().status, "readiness body"):equals("ok")

    local live = http.get(svc.mgmt_url .. "/health/liveness")
    t:expect(live.status, "liveness status code"):equals(200)
    t:expect(live:json().status, "liveness body"):equals("ok")
  end)

  g:test("the management sidecar exposes Prometheus metrics", function(t)
    local svc = t:use(service)
    -- /metrics 307-redirects to /metrics/; hit the canonical path directly.
    local r = http.get(svc.mgmt_url .. "/metrics/")
    t:expect(r.status, "metrics status code"):equals(200)
    t:expect(r.body, "Prometheus exposition format"):contains("# HELP")
  end)
end)
