import uvicorn
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from prometheus_client import make_asgi_app

management_app = FastAPI(title="{{ PrefixName }}{{ SuffixName }} Management")

# Mount Prometheus metrics endpoint
metrics_app = make_asgi_app()
management_app.mount("/metrics", metrics_app)


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
