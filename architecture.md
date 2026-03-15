# Architecture

## Project type

Nix Flake — multi-host NixOS deployment for a homelab. Provisioning via nixos-anywhere, updates via nixos-rebuild over SSH, secrets via sops-nix (age), disk layout via disko.

## Flake inputs

- `nixpkgs` — nixos-unstable-small (primary)
- `nixpkgs-stable` — nixos-24.11 (stateVersion, stable packages via `pkgs-stable`)
- `nixos-hardware` — hardware quirk modules
- `disko` — declarative disk partitioning
- `sops-nix` — secrets management

## Directory structure

```
flake.nix          # Entry point, mkNixosSystems helper
flake.lock         # Pinned inputs
.sops.yaml         # SOPS encryption rules (age keys)

hardware/          # Platform-specific config (kernel modules, CPU, firmware)
modules/           # Reusable NixOS modules, one capability per file
profiles/          # Role definitions that bundle modules into a coherent set
nodes/<name>/      # Per-host entry point: config.nix + optional secrets.yaml
```

## Layering

```
nodes/<name>/config.nix
  → imports a hardware file    (hardware/)
  → imports a profile          (profiles/)
  → imports extra modules      (modules/)
  → sets host-specific values  (disk device, sops secrets, …)
```

Profiles compose modules. Nodes compose profiles, hardware and extra modules. This gives three levels of reuse: module → profile → node.

## Conventions

- One `config.nix` per node; hostname is set automatically by `mkNixosSystems`.
- `system.stateVersion` is derived from `nixpkgs-stable` release version.
- Secrets live in `nodes/<name>/secrets.yaml`, encrypted with age keys listed in `.sops.yaml`.
- Disk layout is assembled from composable partition fragments via `myDisko.partitions` option merging.
