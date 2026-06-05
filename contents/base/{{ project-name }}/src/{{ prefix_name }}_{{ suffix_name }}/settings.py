from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    host: str = "0.0.0.0"
    port: int = {{ service_port }}
    management_port: int = {{ management_port }}
    log_level: str = "INFO"
    logging_structured: bool = False

    # OpenTelemetry — injected by platform at deploy time
    otel_service_name: str = "{{ project-name }}"
    otel_exporter_otlp_endpoint: str = ""
{% if persistence == 'PostgreSQL' %}
    # PostgreSQL — assembled from PAO-injected env vars
    db_host: str = "localhost"
    db_port: int = 5432
    db_username: str = "user"
    db_password: str = "pass"
    db_dbname: str = "{{ project-name }}"

    @property
    def database_url(self) -> str:
        return (
            f"postgresql+asyncpg://{self.db_username}:{self.db_password}"
            f"@{self.db_host}:{self.db_port}/{self.db_dbname}"
        )
{% endif %}
{% if persistence == 'MySQL' %}
    # MySQL — assembled from PAO-injected env vars
    db_host: str = "localhost"
    db_port: int = 3306
    db_username: str = "user"
    db_password: str = "pass"
    db_dbname: str = "{{ project-name }}"

    @property
    def database_url(self) -> str:
        return (
            f"mysql+aiomysql://{self.db_username}:{self.db_password}"
            f"@{self.db_host}:{self.db_port}/{self.db_dbname}"
        )
{% endif %}
{% if cache ~= 'None' %}
    # Redis — assembled from PAO-injected env vars
    cache_host: str = "localhost"
    cache_port: int = 6379
    cache_username: str = ""
    cache_password: str = ""

    @property
    def redis_url(self) -> str:
        if self.cache_password:
            return f"redis://{self.cache_username}:{self.cache_password}@{self.cache_host}:{self.cache_port}/0"
        return f"redis://{self.cache_host}:{self.cache_port}/0"
{% endif %}
{% if messaging == 'Kafka' %}
    # Kafka — PAO-injected env vars (camelCase → UPPER_SNAKE by sanitize_env_key)
    messaging_brokers: str = "localhost:9092"
    messaging_topic: str = "{{ project-name }}"
    messaging_username: str = ""
    messaging_password: str = ""
    messaging_sasl_mechanism: str = "PLAIN"
{% endif %}
{% if messaging == 'Pulsar' %}
    # Pulsar — PAO-injected env vars (camelCase → UPPER_SNAKE by sanitize_env_key)
    messaging_broker_url: str = "pulsar://localhost:6650"
    messaging_topic: str = "persistent://public/default/{{ project-name }}"
    messaging_jwt_token: str = ""
    messaging_subscription_name: str = "{{ project-name }}-sub"
{% endif %}
{% if has_s3 %}
    s3_endpoint: str = "http://localhost:9000"
    s3_bucket: str = "{{ project-name }}"
    s3_prefix: str = ""
    s3_access_key: str = "minioadmin"
    s3_secret_key: str = "minioadmin"
{% endif %}
{% if has_azure_blob %}
    azure_endpoint: str = "http://localhost:10000/devstoreaccount1"
    azure_container: str = "{{ project-name }}"
    azure_account_name: str = "devstoreaccount1"
    azure_account_key: str = "Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KkZB2M0XK3Xg=="
{% endif %}
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
    )


settings = Settings()
