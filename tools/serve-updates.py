# Serves update directories to a QEMU guest for tools/boot-checks/
# gcc-update.txt:  python3 tools/serve-updates.py <dir>  (127.0.0.1:8000,
# which the guest reaches as 10.0.2.2:8000).
#
# A test server only, on loopback only.  QEMU's user-mode
# network loses the tail of a large download when the host side closes the
# connection while the guest is still reading (HTTP/1.0 closes right after
# the body), so this speaks HTTP/1.1 and keeps the connection open, and paces
# its writes.
import functools, http.server, sys, time

class PacedHandler(http.server.SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def copyfile(self, source, outputfile):
        while chunk := source.read(65536):
            outputfile.write(chunk)
            time.sleep(0.0005)

directory = sys.argv[1]
handler = functools.partial(PacedHandler, directory=directory)
http.server.ThreadingHTTPServer(("127.0.0.1", 8000), handler).serve_forever()
