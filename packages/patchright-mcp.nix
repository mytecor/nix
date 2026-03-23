{ lib, buildNpmPackage, fetchFromGitHub, nodejs, makeWrapper }:

buildNpmPackage rec {
  pname = "patchright-mcp";
  version = "0.0.68";

  src = fetchFromGitHub {
    owner = "Ikaleio";
    repo = "patchright-mcp";
    rev = "6526f1ef151f2614d14e6a92e3e617bc9a1ccf99";
    hash = "sha256-SP2jxLaL037XEaYclv9fdcLDu8phjfAH3vq3M1Zf6FI=";
  };

  npmDepsHash = "sha256-VYkm1pbZXiZZCYxmrLIEsqM/n+s+z3PzcDQBXoIJHRQ=";

  # The published package lives in the workspace at packages/playwright-mcp.
  # npm workspaces hoist dependencies to the root node_modules, so we build
  # from the repo root and then install only the relevant workspace package.
  npmBuildScript = "build";

  nativeBuildInputs = [ makeWrapper ];

  # Skip browser download — we connect to an existing CDP endpoint at runtime.
  env.PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";

  installPhase = ''
    runHook preInstall

    # Install the workspace package and its hoisted node_modules
    mkdir -p $out/lib/patchright-mcp
    cp -r node_modules $out/lib/patchright-mcp/

    # Copy workspace packages so that npm workspace symlinks remain valid.
    # node_modules contains symlinks like patchright-mcp -> ../../packages/playwright-mcp,
    # so the packages directory must exist relative to node_modules.
    cp -r packages $out/lib/patchright-mcp/

    # Also copy the top-level entry points from the main workspace package
    cp -r packages/playwright-mcp/{cli.js,index.js,index.d.ts,config.d.ts,playwright-extra-setup.js,package.json} \
      $out/lib/patchright-mcp/

    # Create the binary wrapper
    mkdir -p $out/bin
    makeWrapper ${nodejs}/bin/node $out/bin/mcp-server-patchright \
      --add-flags "$out/lib/patchright-mcp/cli.js"

    runHook postInstall
  '';

  meta = {
    description = "MCP server for browser automation using Patchright (stealth Playwright fork)";
    homepage = "https://github.com/Ikaleio/patchright-mcp";
    license = lib.licenses.asl20;
    mainProgram = "mcp-server-patchright";
  };
}
