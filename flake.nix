{
  description = "Trim Playlist desktop player";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      each = f: nixpkgs.lib.genAttrs systems (system:
        f (import nixpkgs { inherit system; }));
    in {
      devShells = each (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.python3
            pkgs.ffmpeg
          ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
            pkgs.gtk3
            pkgs.webkitgtk_4_1
            pkgs.gobject-introspection
          ];
          shellHook = ''
            python -m venv .venv
            source .venv/bin/activate
            pip install -r requirements.txt
            echo "Start Trim Playlist with: python trim_playlist_app.py"
          '';
        };
      });
    };
}
