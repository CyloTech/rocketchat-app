Rocket.Chat 8.9.0 LTS

The image extends the exact published Appbox 8.8.0 image so MongoDB 8.0, volume paths and lifecycle behavior remain compatible. Rocket.Chat and Node.js are updated to 8.9.0 and 24.15.0. Deno is removed because 8.9.0 uses Node.js for Marketplace apps. Startup tracing is disabled to keep expanded credentials out of logs.

Release gate: fresh installation, restart, upgrade from 8.8.0 with persistent MongoDB data, and an authenticated registry check before publication.

Inherited Node build caches are removed from the image so first startup does not recursively change ownership of obsolete headers and npm cache files.

On upgrade, the existing MongoDB data is detected before initialization. Workspace identity and cloud registration settings are preserved even though the old setup marker is outside the persistent mounts. The upgrade test checks both a database record and workspace identity.
