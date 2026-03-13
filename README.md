# Mytecor homelab

## Чистая установка

```bash
nix run github:nix-community/nixos-anywhere -- --flake .#byurik root@byurik
```

> nixos-anywhere перезагружает систему в kexec (in-memory), Wi-Fi при этом отваливается.
> Если машина подключена только по Wi-Fi — использовать NixOS live USB + Ethernet или wpa_cli.

## Обновление конфигов

```bash
nix run nixpkgs#nixos-rebuild -- switch --flake .#byurik --target-host byurik --build-host byurik --sudo
```

## Секреты (sops)

Age-ключ хранится в `~/.config/sops/age/keys.txt`.
На macOS sops по умолчанию ищет в `~/Library/Application Support/sops/age/keys.txt`, поэтому нужно задавать переменную:

```bash
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
```

### Редактирование секретов

```bash
nix run nixpkgs#sops nodes/byurik/secrets.yaml
```

### Создание секретов для новой ноды

Правила шифрования должны быть добавлены в `.sops.yaml`.

```bash
nix run nixpkgs#sops nodes/<нода>/secrets.yaml
```

### Смена пароля root

Сгенерировать хэш нового пароля:

```bash
nix run nixpkgs#mkpasswd -c mkpasswd -m sha-512
```

Обновить секрет `root_password_hash` в файле секретов ноды:

```bash
nix run nixpkgs#sops nodes/byurik/secrets.yaml
```

Раскатить конфиг — пароль применится автоматически.

## Справочник

### Подключение к Wi-Fi из live USB

```bash
sudo systemctl start wpa_supplicant
wpa_cli
> add_network
> set_network 0 ssid "SSID"
> set_network 0 psk "password"
> enable_network 0
> quit
sudo dhcpcd wlp2s0
```

### Прокинуть SSH-ключ с хоста

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@byurik
```
