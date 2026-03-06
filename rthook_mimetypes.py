# PyInstaller runtime hook: patch mimetypes to work in macOS App Sandbox.
# The sandbox blocks reading /etc/apache2/mime.types (PermissionError EPERM).
import mimetypes
mimetypes.knownfiles = []
