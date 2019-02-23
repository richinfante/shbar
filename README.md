# shbar
Shell Scripting + Jobs in your macOS Menu Bar!

_warning: this is alpha quality software. Use at your own risk._

![example screenshot](screenshots/demo.png)

## Known Issues
- Killing the shbar app does not kill child procesess, on restart new ones are created.

## Install
1. Grab the latest release [here](https://github.com/richinfante/shbar/releases)
2. Download and place unzipped `.app` file into `/Applications`

## Setup
In a file named `~/.config/shbar/shbar.json`, add a file using the following structure:

```json
[
  {
    "titleRefreshInterval" : 120,
    "title" : "IP Address",
    "mode" : "RefreshingItem",
    "titleScript" : {
      "bin" : "/bin/sh",
      "args" : [
        "-c",
        "echo IP: $(curl https://api.ipify.org)"
      ],
      "env" : {
        "PATH" : "/usr/bin:/usr/local/bin:/sbin:/bin"
      }
    }
  }, {
    "autostartJob" : true,
    "jobScript" : {
      "bin" : "/bin/bash",
      "args" : [
        "-c",
        "ssh user@example.com -nNT -L 8080:localhost:8080"
      ],
      "env" : {
        "PATH" : "/usr/bin:/usr/local/bin:/sbin:/bin"
      }
    },
    "title" : "SSH Tunnel",
    "mode" : "JobStatus",
    "reloadJob" : false
  }, {
    "mode" : "ApplicationQuit",
    "title" : "Quit",
    "shortcutKey" : "q"
  }
]

```


## Logging
Shbar places logfiles for each process here: `~/Library/Logs/shbar/`. It does not automatically remove the logfiles, but will in a future release.
