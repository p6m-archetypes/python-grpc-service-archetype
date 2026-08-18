local context = Context.new()

-- Identity (S1). One library, one implementation: p6m-identity asks for the project name and
-- the solution slug, plus the sample CRUD entity defaulted off the project name.
-- It replaces the author x org x project composition — nothing rendered here read the author, and
-- org_name x solution_name were two prompts building one string. `repo_name` and `github_owner`
-- are derived inside the library, never asked.
local identity = require("p6m-identity")
identity.prompt(context)

-- Service configuration
-- `debug` is not asked: nothing any archetype renders reads `debug_port` (measured
-- fleet-wide 2026-08-18) — a prompt whose answer nothing consumes cannot justify itself
-- (S1b / E2). Re-add it here if a Dockerfile or manifest ever publishes the port.
require("ports").prompt(context, { ports = { "service", "management" } })

-- Resources
context:prompt_select("Persistence:", "persistence", {
    "None", "PostgreSQL", "MySQL",
}, { default = "None" })

context:prompt_select("Cache:", "cache", {
    "None", "Redis",
}, { default = "None" })

context:prompt_select("Messaging:", "messaging", {
    "None", "Kafka", "Pulsar",
}, { default = "None" })

if context:get("messaging") ~= "None" then
    context:prompt_select("Messaging Access:", "messaging_access", {
        "produce", "consume",
    }, { default = "produce" })
else
    context:set("messaging_access", "produce")
end

context:prompt_multiselect("Object Storage:", "object_storage", {
    "S3", "Azure Blob",
}, { default = {} })

context:set("has_persistence", context:get("persistence") ~= "None")
context:set("has_cache",       context:get("cache")       ~= "None")
context:set("has_messaging",   context:get("messaging")   ~= "None")
context:set("has_s3",         context:contains("object_storage", "S3"))
context:set("has_azure_blob", context:contains("object_storage", "Azure Blob"))

-- EditorConfig + gitignore
local editor_config = require("editor-config")
editor_config.prompt(context, {
    languages     = { "Python", "YAML", "Markdown" },
    gitattributes = true,
})

local gitignore = require("gitignore")
gitignore.prompt(context, {
    ignores = { "Python", "Claude", "IDEA", "VSCode", "macOS" },
})

-- SCM
local scm = require("scm")
scm.prompt(context)

if archetype.switches.is_enabled("debug-context") then
    log.info(archetype.description .. " Context:")
    output.print(format.yaml(context))
end

-- Render base workspace
directory.render("contents/base", context)

-- Resource libraries
local dest = { destination = context:get("project-name") }

if context:get("persistence") == "PostgreSQL" then
    require("python-resource-postgresql").render(context, dest)
elseif context:get("persistence") == "MySQL" then
    require("python-resource-mysql").render(context, dest)
end

-- Sample scaffold entity + persisted gRPC CRUD servicer over the persistence resource
-- (wired into servicer.serve and main.run behind the persistence conditionals).
if context:get("has_persistence") then
    directory.render("contents/persistence", context)
end

if context:get("has_cache") then
    require("python-resource-redis").render(context, dest)
end

if context:get("messaging") == "Kafka" then
    require("python-resource-kafka").render(context, dest)
elseif context:get("messaging") == "Pulsar" then
    require("python-resource-pulsar").render(context, dest)
end

if context:get("has_s3") then
    require("python-resource-s3").render(context, dest)
end

if context:get("has_azure_blob") then
    require("python-resource-azure-blob").render(context, dest)
end

-- CI workflows
local ci = require("python-ci")
ci.render(context, dest)

-- Platform manifests
context:set("protocol", "gRPC")
local platform = require("platform-application-manifests")
platform.prompt(context)
platform.finalize(context, dest)

-- EditorConfig, gitignore, SCM finalize
editor_config.finalize(context, dest)
gitignore.finalize(context, dest)
scm.finalize(context)

-- Archive (zip / tarball switches for Ybor Studio)
require("archiver").finalize(context)

return context
