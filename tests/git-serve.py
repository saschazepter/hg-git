#!/usr/bin/env python3
#
# Totally stupid Git HTTP server. Serves a single repository:
#
# */secret can read
# admin/secret can write
#
# When $DAEMON_PIDS is set by the test suite, the script writes forks
# a child and writes its PID to that file.
#
# This script uses os.fork(), so it doesn't work on Windows...
#

import base64
import io
import os
import sys
import wsgiref.simple_server

import dulwich.repo
import dulwich.web
import dulwich.server


class AuthMiddleware:
    def __init__(self, app):
        self._app = app

    def __call__(self, environ, start_response):
        status = "401 Authentication Required"
        header = environ.get("HTTP_AUTHORIZATION")

        if header:
            encoded = header.split(" ", 1)[1]
            decoded = base64.b64decode(encoded)
            username, password = decoded.split(b":", 1)

            if password == b"secret":
                if username != b"admin" and environ["REQUEST_METHOD"] != "GET":
                    status = "403 Forbidden"
                else:
                    return self._app(environ, start_response)

        start_response(
            status,
            [
                ("Content-Type", "text/plain"),
                ("WWW-Authenticate", 'Basic realm="The Test Suite"'),
            ],
        )

        return []


pidfile = os.getenv("DAEMON_PIDS")

if pidfile:
    with open(pidfile, "a") as fp:
        fp.write("{}\n".format(os.getpid()))

backend = dulwich.server.DictBackend({"/": dulwich.repo.Repo(sys.argv[1])})
app = AuthMiddleware(dulwich.web.make_wsgi_chain(backend))
server = wsgiref.simple_server.make_server("localhost", int(sys.argv[2]), app)

with server:
    server.serve_forever()
