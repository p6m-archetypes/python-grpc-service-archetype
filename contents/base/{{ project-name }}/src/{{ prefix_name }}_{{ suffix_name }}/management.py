import uvicorn
from fastapi import FastAPI, Response
from fastapi.responses import JSONResponse
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest

management_app = FastAPI(title="{{ PrefixName }}{{ SuffixName }} Management")


# Prometheus metrics endpoint — an explicit route so `GET /metrics` answers 200 directly
# (mounting an ASGI sub-app 307-redirects the slashless path, which probes don't follow).
@management_app.get("/metrics")
async def metrics() -> Response:
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


@management_app.get("/health/readiness")
async def readiness() -> JSONResponse:
    return JSONResponse({"status": "ok"})


@management_app.get("/health/liveness")
async def liveness() -> JSONResponse:
    return JSONResponse({"status": "ok"})


async def serve(settings) -> None:
    config = uvicorn.Config(
        management_app,
        host=settings.host,
        port=settings.management_port,
        log_level=settings.log_level.lower(),
    )
    server = uvicorn.Server(config)
    await server.serve()
