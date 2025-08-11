with (import <nixpkgs> {});
mkShell {
  buildInputs = [ ruby ];
  shellHook = ''
    bundle install
    #ruby main.rb
  '';
}
