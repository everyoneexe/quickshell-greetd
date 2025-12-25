# Test greetd setup

## 1. greetd config (/etc/greetd/config.toml):
```toml
[terminal]
vt = 1

[default_session]
command = "/usr/bin/quickshell-greetd-launcher"
user = "greeter"
```

## 2. Create greeter user:
```bash
sudo useradd -r -s /bin/false greeter
```

## 3. Enable greetd:
```bash
sudo systemctl enable greetd
sudo systemctl start greetd
```

## 4. Test without rebooting:
```bash
sudo systemctl stop display-manager  # stop current DM
sudo systemctl start greetd
```

Siyah ekran normal - greetd VT1'de çalışır, mevcut session'da görünmez.
