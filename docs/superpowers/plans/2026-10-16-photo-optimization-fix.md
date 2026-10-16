# Photo upload repair and automatic optimization

Reproduced the reported error through the actual browser file chooser using a valid 800x600 PNG. Root cause: Flutter Web's encoded ImageDescriptor.width/height getters throw UnsupportedError (installed Flutter web SDK ui/painting.dart); the original processing path used those getters on every photo.

Use instantiateImageCodec directly at a thumbnail width and read the decoded frame dimensions, which work on web. Fit proportionally within 512px without upscaling and encode the thumbnail. Preserve alpha with PNG. For opaque photos choose the smaller of PNG and JPEG quality 92 with full chroma. Offload pure encoding via compute on native platforms. Remove the arbitrary 10 MB and 40MP rejection. Originals remain untouched. Invalid formats, decoder resource failures and storage failures still require honest, stage-specific errors.

Regression checks: portrait/landscape dimensions; valid input padded beyond 10 MB; decode/resize and persistence tests; analysis; compiled localhost picker upload, refresh and removal verification. Browser test-runner startup stalled, so use the actual in-app browser for web verification instead of claiming that runner passed.

Normal uploads now open a crop route before saving: drag, pinch/slider zoom, circular preview, Reset, Save photo and Cancel. Source rectangle is clamped to image bounds and rendered to a maximum 512px square before optimization. Crop geometry is regression-tested. Reference: https://faq.whatsapp.com/812276063311533/?cms_platform=web .

Actual browser verification exposed a second failure: CanvasKit reported CPU-only rendering and lazy browser-backed image textures painted transparent, affecting both canvas resizing and avatars. Materialize decoded raw RGBA into a pixel-backed ui.Image on web before drawing, and use the same decoder in the avatar ImageProvider. Keep pixel alpha/color regression assertions so dimensions alone cannot pass a blank output. Previously saved transparent thumbnails cannot recover discarded source pixels; the original needs to be selected again.

Verified final web build with actual file chooser on isolated 127.0.0.1 origin: nonblank crop preview, drag, slider zoom to 1.9x, Save photo, visible avatar, and avatar still visible after reload. Existing localhost profile left untouched. Full suite passed 38 tests before software-renderer fix; 7 targeted tests and clean analyzer passed after it, plus 3 pixel regression tests. Release web build passed. Evidence: build/photo-crop.png and build/photo-saved-check.png (generated test pattern).
