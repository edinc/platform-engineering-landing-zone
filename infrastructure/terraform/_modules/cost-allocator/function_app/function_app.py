import csv
import io
import logging
import os
from datetime import datetime, timezone

import azure.functions as func
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient, ContentSettings

from shared_code.cost_showback import allocate_cost_rows, write_showback_csv


app = func.FunctionApp()


def _required_setting(name: str) -> str:
    value = os.environ.get(name, "")
    if not value:
        raise RuntimeError(f"Missing required setting: {name}")
    return value


def _latest_export_blobs(container_client, root_folder: str):
    candidates = [
        blob
        for blob in container_client.list_blobs(name_starts_with=root_folder.rstrip("/") + "/")
        if blob.name.endswith(".csv")
    ]
    if not candidates:
        raise RuntimeError(f"No Cost Management CSV exports found under {root_folder!r}.")
    latest = max(candidates, key=lambda blob: blob.last_modified)
    latest_folder = latest.name.rsplit("/", 1)[0]
    return [blob for blob in candidates if blob.name.rsplit("/", 1)[0] == latest_folder]


@app.schedule(
    schedule="%COST_ALLOCATOR_SCHEDULE%",
    arg_name="timer",
    run_on_startup=False,
    use_monitor=True,
)
def allocate_costs(timer: func.TimerRequest) -> None:
    credential = DefaultAzureCredential()
    export_service = BlobServiceClient(_required_setting("COST_EXPORT_ACCOUNT_URL"), credential=credential)
    showback_service = BlobServiceClient(_required_setting("COST_SHOWBACK_ACCOUNT_URL"), credential=credential)

    export_container = export_service.get_container_client(_required_setting("COST_EXPORT_CONTAINER"))
    export_blobs = _latest_export_blobs(export_container, _required_setting("COST_EXPORT_ROOT_FOLDER"))
    rows = []
    for export_blob in export_blobs:
        raw_csv = export_container.download_blob(export_blob.name).readall().decode("utf-8-sig")
        rows.extend(csv.DictReader(io.StringIO(raw_csv)))
    allocations = allocate_cost_rows(rows)

    generated_at = datetime.now(timezone.utc)
    output_name = f"showback/{generated_at:%Y/%m/%d}/team-showback.csv"
    output_container = showback_service.get_container_client(_required_setting("COST_SHOWBACK_CONTAINER"))
    output_container.upload_blob(
        output_name,
        write_showback_csv(allocations, generated_at).encode("utf-8"),
        overwrite=True,
        content_settings=ContentSettings(content_type="text/csv"),
    )
    logging.info("Published %s allocation rows to %s.", len(allocations), output_name)
