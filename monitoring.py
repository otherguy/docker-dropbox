from argparse import ArgumentParser
from enum import Enum
from functools import partial
import logging
import re
import signal
import subprocess
from threading import Event
from time import time
from typing import Optional

from prometheus_client import start_http_server, Enum as EnumMetric, Gauge  # type: ignore


class Metric(Enum):
    NUM_SYNCING = "num_syncing"
    NUM_DOWNLOADING = "num_downloading"
    NUM_UPLOADING = "num_uploading"


class State(Enum):
    STARTING = "starting"
    SYNCING = "syncing"
    INDEXING = "indexing"
    UP_TO_DATE = "up to date"
    SYNC_ERROR = "sync_error"
    NOT_RUNNING = "not running"
    UNKNOWN = "unknown"


class DropboxInterface:
    """
    This can be mocked for testing as needed
    """

    def __init__(self, logger: logging.Logger) -> None:
        self.logger = logger

    def query_status(self) -> Optional[str]:
        try:
            result = subprocess.run(
                ["dropbox", "status"], capture_output=True, text=True
            )
            if result.stderr:
                self.logger.warning("Dropbox status returned error: %s", result.stderr)
                return None
            elif not result.stdout:
                self.logger.warning("Dropbox status did not produce results")
                return None
            else:
                self.logger.debug("Got result from Dropbox: %s", result.stdout)
                return result.stdout
        except:
            self.logger.exception("Failed to invoke Dropbox")
            return None


class DropboxMonitor:
    def __init__(
        self,
        dropbox: DropboxInterface,
        min_poll_interval_sec: int,
        logger: logging.Logger,
        prom_port: int,
    ) -> None:
        self.dropbox = dropbox
        self.min_poll_interval_sec = min_poll_interval_sec
        self.logger = logger
        self.prom_port = prom_port
        self.status_matcher = re.compile(
            "(Syncing|Downloading|Uploading|Indexing) (\\d+) files"
        )
        self.status_matcher_with_file = re.compile(
            '(Syncing|Downloading|Uploading|Indexing) ".+"'
        )

        self.last_query_time = 0
        self.num_syncing = None  # type: Optional[int]
        self.num_downloading = None  # type: Optional[int]
        self.num_uploading = None  # type: Optional[int]
        self.state = State.STARTING

        self.num_syncing_gauge = Gauge(
            "dropbox_num_syncing",
            "Number of files currently syncing",
        )

        self.num_downloading_gauge = Gauge(
            "dropbox_num_downloading",
            "Number of files currently downloading",
        )

        self.num_uploading_gauge = Gauge(
            "dropbox_num_uploading",
            "Number of files currently uploading",
        )

        self.status_enum = EnumMetric(
            "dropbox_status",
            "Status reported by Dropbox client",
            states=[state.value for state in State.__members__.values()],
        )

    def start(self) -> None:
        self.status_enum.state(State.STARTING.value)
        self.num_syncing_gauge.set_function(
            partial(self.get_status, Metric.NUM_SYNCING)
        )
        self.num_downloading_gauge.set_function(
            partial(self.get_status, Metric.NUM_DOWNLOADING)
        )
        self.num_uploading_gauge.set_function(
            partial(self.get_status, Metric.NUM_UPLOADING)
        )

        start_http_server(self.prom_port)
        self.logger.info("Started Prometheus server on port %d", self.prom_port)

    def get_status(self, metric: Metric) -> int:
        now = time()
        if now - self.last_query_time > self.min_poll_interval_sec:
            dropbox_result = self.dropbox.query_status()
            if dropbox_result:
                self.parse_output(dropbox_result)
            else:
                self.status_enum.state(State.UNKNOWN.value)
                self.num_syncing = None
                self.num_downloading = None
                self.num_uploading = None

        if metric == Metric.NUM_SYNCING:
            return self.num_syncing or 0
        elif metric == Metric.NUM_DOWNLOADING:
            return self.num_downloading or 0
        elif metric == Metric.NUM_UPLOADING:
            return self.num_uploading or 0
        else:
            raise ValueError(metric)

    def parse_output(self, results: str) -> None:
        """
        Observed messages from `dropbox status`

        Up to date
        Syncing...
        Indexing...
        Syncing 176 files • 6 secs
        Downloading 176 files (6 secs)
        Dropbox isn't running!
        Indexing 1 file...
        Can't sync "monitoring.txt" (access denied)
        Syncing "none" • 1 sec
        Downloading 82 files (2,457 KB/sec, 2 secs)
        """
        state = State.UNKNOWN
        num_syncing = None  # type: Optional[int]
        num_downloading = None  # type: Optional[int]
        num_uploading = None  # type: Optional[int]

        for line in results.splitlines():
            try:
                if line.startswith("Up to date"):
                    state = State.UP_TO_DATE
                    self.num_syncing = 0
                    self.num_downloading = 0
                    self.num_uploading = 0
                if line == "Dropbox isn't running!":
                    state = State.NOT_RUNNING
                else:
                    status_match = self.status_matcher.match(line)
                    status_match_with_file = self.status_matcher_with_file.match(line)
                    if status_match:
                        state = State.SYNCING
                        action, num_files_str = status_match.groups()
                        num_files = int(num_files_str)
                        if action == "Syncing":
                            num_syncing = num_files
                        if action == "Downloading":
                            num_downloading = num_files
                        if action == "Uploading":
                            num_uploading = num_files
                    elif status_match_with_file:
                        state = State.SYNCING
                        action = status_match_with_file.groups()[0]
                        if action == "Syncing":
                            num_syncing = 1
                        if action == "Downloading":
                            num_downloading = 1
                        if action == "Uploading":
                            num_uploading = 1
                    elif line.startswith("Starting"):
                        state = State.STARTING
                    elif line.startswith("Syncing"):
                        state = State.SYNCING
                    elif line.startswith("Indexing"):
                        state = State.INDEXING
                    elif line.startswith("Can't sync"):
                        state = State.SYNC_ERROR
                    else:
                        self.logger.debug("Ignoring line '%s'", line)
            except:
                self.logger.exception("Failed to parse status line '%s'", line)

        self.status_enum.state(state.value)
        if state == State.SYNCING:
            self.num_syncing = num_syncing
            self.num_downloading = num_downloading
            self.num_uploading = num_uploading
        else:
            self.num_syncing = None
            self.num_downloading = None
            self.num_uploading = None


if __name__ == "__main__":
    parser = ArgumentParser(
        description="Runs a webserver for Prometheus that reports Dropbox status"
    )
    parser.add_argument(
        "-i",
        "--min_poll_interval_sec",
        help="minimum interval for polling Dropbox (in seconds)",
        default=5,
    )
    parser.add_argument("-p", "--port", help="Prometheus port", default=8000)
    parser.add_argument("--log_level", default="INFO")
    parser.add_argument("--global_log_level", default="INFO")
    args = parser.parse_args()

    log_level = logging.getLevelName(args.log_level)
    global_log_level = logging.getLevelName(args.global_log_level)
    logging.basicConfig(
        format="[MONITORING %(levelname)s]: %(message)s", level=global_log_level
    )
    logger = logging.getLogger("dropbox_monitor")
    logger.setLevel(log_level)

    dropbox = DropboxInterface(logger)
    monitor = DropboxMonitor(
        dropbox=dropbox,
        min_poll_interval_sec=int(args.min_poll_interval_sec),
        logger=logger,
        prom_port=args.port,
    )
    monitor.start()

    exit_event = Event()
    signal.signal(signal.SIGHUP, lambda _s, _f: exit_event.set())
    signal.signal(signal.SIGINT, lambda _s, _f: exit_event.set())
    signal.signal(signal.SIGTERM, lambda _s, _f: exit_event.set())

    exit_event.wait()
    logger.info("Stopped gracefully")
