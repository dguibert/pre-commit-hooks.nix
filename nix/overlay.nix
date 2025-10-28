{ isFlakes, gitignore-nix-src }:
final: prev:
let
  tools = import ./call-tools.nix prev;
  run = prev.callPackage ./run.nix { pkgs = prev; inherit tools isFlakes gitignore-nix-src; };
in
{
  pre-commit-nix = { inherit tools run; };
  # Flake style attributes
  packages = tools // {
    inherit (prev) pre-commit;
  };
  checks = final.packages // {
    # A pre-commit-check for nix-pre-commit itself
    pre-commit-check = run {
      src = ../.;
      hooks = {
        shellcheck.enable = true;
        nixpkgs-fmt.enable = true;
      };
    };
    all-tools-eval =
      let
        config = prev.lib.evalModules {
          modules = [
            ../modules/all-modules.nix
            {
              inherit tools;
              settings.treefmt.package = prev.treefmt;
            }
          ];
          specialArgs = { pkgs = prev; };
        };
        allHooks = config.config.hooks;
        allEntryPoints = prev.lib.mapAttrsToList (_: v: v.entry) allHooks;
      in
      prev.runCommand "all-tools-eval"
        {
          inherit allEntryPoints;
        } ''
        touch $out
      '';
    doc-check =
      let
        inherit (prev) lib;
        # We might add that it keeps rendering fast and robust,
        # and we want to teach `defaultText` which is more broadly applicable,
        # but the message is long enough.
        failPkgAttr = name: _v:
          throw ''
            While generating documentation, we found that `pkgs` was used. To avoid rendering store paths in the documentation, this is forbidden.

            Usually when this happens, you need to add `defaultText` to an option declaration, or escape an example with `lib.literalExpression`.

            The `pkgs` attribute that was accessed is

                pkgs.${lib.strings.escapeNixIdentifier name}

            If necessary, you can also find the offending option by evaluating with `--show-trace` and then look for occurrences of `option`.
          '';
        pkgsStub = lib.mapAttrs failPkgAttr prev;
        configuration = prev.lib.evalModules {
          modules = [
            ../modules/all-modules.nix
            {
              _file = "doc-check";
              config = {
                _module.args.pkgs = pkgsStub // {
                  _type = "pkgs";
                  inherit lib;
                  formats = lib.mapAttrs
                    (formatName: formatFn:
                      formatArgs:
                      let
                        result = formatFn formatArgs;
                        stubs =
                          lib.mapAttrs
                            (name: _:
                              throw "The attribute `(pkgs.formats.${lib.strings.escapeNixIdentifier formatName} x).${lib.strings.escapeNixIdentifier name}` is not supported during documentation generation. Please check with `--show-trace` to see which option leads to this `${lib.strings.escapeNixIdentifier name}` reference. Often it can be cut short with a `defaultText` argument to `lib.mkOption`, or by escaping an option `example` using `lib.literalExpression`."
                            )
                            result;
                      in
                      stubs // {
                        inherit (result) type;
                      }
                    )
                    prev.formats;
                };
              };
            }
          ];
        };
        doc = prev.nixosOptionsDoc {
          inherit (configuration) options;
        };
      in
      doc.optionsCommonMark;
  };
}
