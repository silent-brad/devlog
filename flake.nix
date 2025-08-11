{
  description = "Minimal Static Markdown Blog Generator";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      packages.${system}.default = pkgs.stdenv.mkDerivation {
        name = "minblog";
        src = self;
        buildInputs = with pkgs; [ ruby ];
        nativeBuildInputs = with pkgs; [ makeWrapper ];
        installPhase = ''
          bundle install
          mkdir -p $out/bin
          cp ${self}/serve.sh $out/bin/serve
          chmod +x $out/bin/serve
          wrapProgram $out/bin/serve \
            --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.ruby ]}
        '';
      };

      defaultPackage.${system} = self.packages.${system}.default;
    };
}
