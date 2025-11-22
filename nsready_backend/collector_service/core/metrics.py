from prometheus_client import Counter, Gauge, generate_latest, CONTENT_TYPE_LATEST
from fastapi import Response

# Metrics
ingest_counter = Counter(
    'ingest_events_total',
    'Total number of events ingested',
    ['status']
)

error_counter = Counter(
    'ingest_errors_total',
    'Total number of ingestion errors',
    ['error_type']
)

queue_depth_gauge = Gauge(
    'ingest_queue_depth',
    'Current depth of the ingestion queue'
)

ingest_rate_gauge = Gauge(
    'ingest_rate_per_second',
    'Current ingestion rate (events per second)'
)


def get_metrics_response() -> Response:
    """Generate Prometheus metrics response"""
    return Response(
        content=generate_latest(),
        media_type=CONTENT_TYPE_LATEST
    )

