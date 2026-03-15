{ lib, buildGoModule, fetchgit }:

buildGoModule rec {
  pname = "reticulum-go";
  version = "0.6.0";

  src = fetchgit {
    url = "https://git.quad4.io/Networks/Reticulum-Go.git";
    rev = "v${version}";
    hash = "sha256-djm4YKv7Y94dGpZ2fJuDpb96df6qtWNVAOzNCHdLKug=";
  };

  vendorHash = "sha256-UZYniNhKC3hb5dtwbdfg3Dc3bP2wlwfmlKgu7xDKA8E=";

  subPackages = [ "cmd/reticulum-go" ];

  ldflags = [
    "-s"
    "-w"
  ];

  meta = {
    description = "High-performance Go implementation of the Reticulum Network Stack";
    homepage = "https://git.quad4.io/Networks/Reticulum-Go";
    license = lib.licenses.free;
    mainProgram = "reticulum-go";
  };
}
