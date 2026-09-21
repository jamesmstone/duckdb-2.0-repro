{
  description = "Minimal reproductions for three DuckDB 2.0 findings";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # The same two archives run.sh downloads, pinned by hash and patched so
        # they run on NixOS as well. Nothing here is required to reproduce the
        # findings — run.sh fetches these itself on any ordinary Linux.
        cli = { pname, version, url, sha256, archive }:
          pkgs.stdenv.mkDerivation {
            inherit pname version;
            src = pkgs.fetchurl { inherit url sha256; };
            dontUnpack = true;
            nativeBuildInputs = [ pkgs.autoPatchelfHook ];
            buildInputs = [ pkgs.stdenv.cc.cc.lib ];
            installPhase = ''
              mkdir -p $out/bin
              ${if archive == "gz"
                then "gunzip -c $src > $out/bin/${pname}"
                else "tar -xzOf $src duckdb > $out/bin/${pname}"}
              chmod +x $out/bin/${pname}
            '';
            meta.mainProgram = pname;
          };

        stable = cli {
          pname = "duckdb-stable";
          version = "1.5.5";
          url = "https://install.duckdb.org/v1.5.5/duckdb_cli-linux-amd64.gz";
          sha256 = "11f8ils68ddwg6aczd17yjf30il3l5791sccqahd6hbfbr4227y6";
          archive = "gz";
        };

        alpha = cli {
          pname = "duckdb-alpha";
          version = "2.0.0-alpha42839";
          url = "https://duckdb-staging.duckdb.org/31adc8b766/v2.0.0-alpha42839/duckdb/duckdb/github_release/duckdb-cli-linux-amd64.tar.gz";
          sha256 = "1q568mv60wrjg8kx0hwzgcvns5m376zcp63hb88l3wf8260v8676";
          archive = "tar.gz";
        };
      in
      {
        packages = { inherit stable alpha; };

        devShells.default = pkgs.mkShell {
          packages = [ stable alpha pkgs.curl pkgs.gnugrep ];
          DUCKDB_STABLE_BIN = pkgs.lib.getExe stable;
          DUCKDB_ALPHA_BIN = pkgs.lib.getExe alpha;
        };
      });
}
