# Dolorain Studio Custom

A lightweight **ComfyUI frontend extension** for Dolorain Studio. The original ComfyUI canvas, nodes, widgets, connections, workflow execution and ComfyUI Manager remain intact. This project does not build a separate renderer or manager.

## Initial preview

- Small fixed **DOLORAIN STUDIO** branded header (42 px)
- No core ComfyUI source patches
- No replacement node controls or installation backend
- **Experimental**: header might overlap ComfyUI controls, depending on frontend version; real Windows/Edge verification is still pending.

## Windows installation

1. Download this repository as ZIP and extract it.
2. Run `INSTALL-WINDOWS.bat`; it copies `custom_nodes/dolorain_studio` to the existing portable ComfyUI installation at `C:\ComfyUI_windows_portable_nvidia\ComfyUI_windows_portable\ComfyUI\custom_nodes`.
3. Restart ComfyUI and refresh Edge (Ctrl+Shift+R).

The installer refuses to overwrite an existing `dolorain_studio` directory. It never installs another manager and doesn't change the ComfyUI engine.

## Project scope

Add theme colors and selective UI simplification only **after verifying** the baseline extension. Do not modify the older `Dolorain-Studio-One` repository.

## Rollback

Delete the newly copied `ComfyUI\custom_nodes\dolorain_studio` directory, restart ComfyUI and refresh Edge. This removes the branding extension only.
