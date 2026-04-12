#!/usr/bin/env python3
import asyncio
from typing import List, Tuple, Set


# ----------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------

# DOWNSTREAM listener ports on Windows / Linux Host Computer
BEAST_LISTEN_HOST = "0.0.0.0"
BEAST_LISTEN_PORT = 4000

MLAT_LISTEN_HOST = "0.0.0.0"
MLAT_LISTEN_PORT = 4105


# UPSTREAM source RPis
RPIS = [
    "192.168.12.21",
    "192.168.12.22",
    "192.168.12.23",
    "192.168.12.24",
]

# Upstreams: (name, host, port, kind)
# kind is "beast" or "mlat" just for logging / routing
UPSTREAMS: List[Tuple[str, str, int, str]] = []

for ip in RPIS:
    UPSTREAMS.append((f"{ip}-30005", ip, 30005, "beast"))
    UPSTREAMS.append((f"{ip}-30105", ip, 30105, "mlat"))


# ----------------------------------------------------------------------
# Beast / Mlat frame extractor (handles escaping, yields complete frames)
# ----------------------------------------------------------------------

class BeastFrameExtractor:
    """
    Extracts complete Beast frames from a byte stream.

    - Handles 0x1a escaping (0x1a 0x1a -> single 0x1a in payload)
    - Uses frame type + unescaped length to find frame boundaries
    - Yields raw *escaped* frames (exact bytes as received)
    """

    # Valid Beast message types we care about
    BEAST_TYPES = {0x31, 0x32, 0x33, 0x34}

    # Unescaped payload lengths (after the type byte):
    # 6 bytes timestamp + 1 byte RSSI + data
    # 0x31: Mode-AC (2 data bytes)
    # 0x32: Mode-S short (7 data bytes)
    # 0x33: Mode-S long (14 data bytes)
    TYPE_PAYLOAD_LENGTHS = {
        0x31: 6 + 1 + 2,
        0x32: 6 + 1 + 7,
        0x33: 6 + 1 + 14,
        # 0x34 (status) is variable; we skip those frames for simplicity
    }

    def __init__(self):
        self.buffer = bytearray()

    def feed(self, data: bytes):
        """
        Feed raw bytes into the extractor.
        Yields complete frames as bytes objects.
        """
        self.buffer.extend(data)

        while True:
            start = self._find_start()
            if start is None:
                # No plausible start found; keep any trailing partial marker
                return

            if start > 0:
                del self.buffer[:start]

            if len(self.buffer) < 2:
                # Need at least 0x1a + type
                return

            if self.buffer[0] != 0x1A:
                # Shouldn't happen due to _find_start, but be defensive
                del self.buffer[0]
                continue

            msg_type = self.buffer[1]

            if msg_type not in self.BEAST_TYPES:
                # Not a valid Beast type; drop the 0x1a and resync
                del self.buffer[0]
                continue

            # Skip 0x34 (status) frames entirely (unknown length)
            if msg_type not in self.TYPE_PAYLOAD_LENGTHS:
                # Drop this 0x1a and resync
                del self.buffer[0]
                continue

            needed_unescaped = self.TYPE_PAYLOAD_LENGTHS[msg_type]

            end_index = self._find_frame_end(needed_unescaped)
            if end_index is None:
                # Not enough data yet
                return

            frame = bytes(self.buffer[:end_index + 1])
            del self.buffer[:end_index + 1]
            yield frame

    def _find_start(self):
        """
        Find index of a plausible frame start (0x1a followed by a type).
        Returns None if not found.
        """
        i = 0
        while True:
            try:
                i = self.buffer.index(0x1A, i)
            except ValueError:
                return None

            # Need at least one more byte for type
            if i + 1 >= len(self.buffer):
                return i  # partial start, keep it

            t = self.buffer[i + 1]
            if t in self.BEAST_TYPES:
                return i

            # 0x1a 0x1a is escaped data, not a start
            i += 1

    def _find_frame_end(self, needed_unescaped: int):
        """
        Given that buffer[0] == 0x1a and buffer[1] is a valid type with
        known unescaped payload length, find the end index of the frame
        in the *escaped* buffer.

        Returns the index (inclusive) or None if not enough data yet.
        """
        i = 2  # start of payload (escaped)
        unescaped_count = 0

        while i < len(self.buffer):
            b = self.buffer[i]

            if b == 0x1A:
                # Escaped 0x1a in payload must be 0x1a 0x1a
                if i + 1 >= len(self.buffer):
                    # Need more data to know if this is escape or next frame
                    return None
                if self.buffer[i + 1] == 0x1A:
                    # This is escaped 0x1a -> counts as one unescaped byte
                    unescaped_count += 1
                    i += 2
                else:
                    # 0x1a followed by non-0x1a here would be a new frame start,
                    # meaning the current frame is corrupt/incomplete.
                    return None
            else:
                unescaped_count += 1
                i += 1

            if unescaped_count == needed_unescaped:
                # i is now index AFTER the last byte of this frame
                return i - 1

        # Ran out of buffer before completing frame
        return None


# ----------------------------------------------------------------------
# Broadcaster: manages downstream clients and sends frames to all
# ----------------------------------------------------------------------

class Broadcaster:
    def __init__(self, label: str):
        self.label = label
        self.clients: Set[asyncio.StreamWriter] = set()
        self.lock = asyncio.Lock()

    async def register(self, writer: asyncio.StreamWriter):
        async with self.lock:
            self.clients.add(writer)

    async def unregister(self, writer: asyncio.StreamWriter):
        async with self.lock:
            self.clients.discard(writer)

    async def broadcast(self, data: bytes):
        async with self.lock:
            dead = []
            for w in self.clients:
                try:
                    w.write(data)
                except Exception:
                    dead.append(w)
            for w in dead:
                self.clients.discard(w)
            # We rely on OS buffering; if you want stricter flow control,
            # you can occasionally await w.drain() here.


# ----------------------------------------------------------------------
# Upstream handling: connect, read, parse, broadcast
# ----------------------------------------------------------------------

async def handle_upstream(name: str,
                          host: str,
                          port: int,
                          kind: str,
                          broadcaster: Broadcaster):
    while True:
        try:
            print(f"[{kind.upper()}][{name}] Connecting to {host}:{port} ...")
            reader, writer = await asyncio.open_connection(host, port)
            print(f"[{kind.upper()}][{name}] Connected.")

            extractor = BeastFrameExtractor()

            while True:
                data = await reader.read(4096)
                if not data:
                    print(f"[{kind.upper()}][{name}] Disconnected (EOF).")
                    break

                for frame in extractor.feed(data):
                    await broadcaster.broadcast(frame)

        except Exception as e:
            print(f"[{kind.upper()}][{name}] Error: {e}")

        print(f"[{kind.upper()}][{name}] Reconnecting in 30 seconds...")
        await asyncio.sleep(30)


# ----------------------------------------------------------------------
# Downstream handling: accept clients and keep them registered
# ----------------------------------------------------------------------
async def handle_downstream(reader: asyncio.StreamReader,
                            writer: asyncio.StreamWriter,
                            broadcaster: Broadcaster):
    addr = writer.get_extra_info("peername")
    print(f"[{broadcaster.label}] Client connected from {addr}")
    await broadcaster.register(writer)

    try:
        while True:
            try:
                data = await reader.read(1024)
                if not data:
                    break
            except (ConnectionResetError, OSError):
                # Windows throws WinError 64 when client disconnects abruptly
                break

    finally:
        print(f"[{broadcaster.label}] Client disconnected from {addr}")
        await broadcaster.unregister(writer)

        writer.close()
        try:
            await writer.wait_closed()
        except Exception:
            pass

# ----------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------

async def main():
    beast_broadcaster = Broadcaster("BEAST-OUT(4000)")
    mlat_broadcaster = Broadcaster("MLAT-OUT(4105)")

    # Start upstream tasks
    upstream_tasks = []
    for (name, host, port, kind) in UPSTREAMS:
        if kind == "beast":
            broadcaster = beast_broadcaster
        else:
            broadcaster = mlat_broadcaster

        upstream_tasks.append(
            asyncio.create_task(
                handle_upstream(name, host, port, kind, broadcaster)
            )
        )

    # Start downstream servers
    beast_server = await asyncio.start_server(
        lambda r, w: handle_downstream(r, w, beast_broadcaster),
        BEAST_LISTEN_HOST,
        BEAST_LISTEN_PORT,
    )

    mlat_server = await asyncio.start_server(
        lambda r, w: handle_downstream(r, w, mlat_broadcaster),
        MLAT_LISTEN_HOST,
        MLAT_LISTEN_PORT,
    )

    beast_addr = ", ".join(str(sock.getsockname()) for sock in beast_server.sockets)
    mlat_addr = ", ".join(str(sock.getsockname()) for sock in mlat_server.sockets)
    print(f"[MUX] Beast mixed output listening on {beast_addr}")
    print(f"[MUX] MLAT mixed output listening on {mlat_addr}")

    async with beast_server, mlat_server:
        await asyncio.gather(
            *upstream_tasks,
            beast_server.serve_forever(),
            mlat_server.serve_forever(),
        )


if __name__ == "__main__":
    # On Windows, asyncio.run is the simplest entry point
    asyncio.run(main())

