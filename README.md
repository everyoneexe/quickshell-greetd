# quickshell-greetd

Use your existing Quickshell lockscreen as system login screen.

## Purpose

You have a Quickshell lockscreen. This makes it your greetd greeter without changes.

## Installation

### Arch Linux
```bash
yay -S quickshell-greetd
```

### Manual (Other Distros)
```bash
git clone https://github.com/user/quickshell-greetd
cd quickshell-greetd
sudo cp launcher/quickshell-greetd-launcher /usr/local/bin/
sudo chmod +x /usr/local/bin/quickshell-greetd-launcher
```

## Setup

1. **Configure greetd** (`/etc/greetd/config.toml`):
```toml
[default_session]
command = "/usr/local/bin/quickshell-greetd-launcher"
user = "greeter"
```

2. **Create greeter config** (`~/.config/quickshell/greeter.qml`):
```qml
import Quickshell.Services.Greetd
// Your existing lockscreen QML with Greetd instead of Pam
```

3. **Enable greetd**:
```bash
sudo systemctl enable greetd
```

## Architecture
```
greetd → cage → quickshell → Quickshell.Services.Greetd
```

Dependencies: `quickshell`, `greetd`, `cage`
