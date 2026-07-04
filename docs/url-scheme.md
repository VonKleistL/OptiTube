# URL Scheme

OptiTube supports a custom URL scheme for opening content directly from other apps, scripts, or the command line.

## Play a Track

Play a track by its YouTube video ID:

```bash
open "optitube://play?v=dQw4w9WgXcQ"
```

## Usage Examples

### From Terminal

```bash
# Play a specific track
open "optitube://play?v=VIDEO_ID"
```

### From AppleScript

```applescript
do shell script "open 'optitube://play?v=VIDEO_ID'"
```

### From Shortcuts

Use the "Open URLs" action with `optitube://play?v=VIDEO_ID`.

## See Also

- [AppleScript Support](applescript.md) — Automate playback with scripts, Raycast, Alfred, and Shortcuts
