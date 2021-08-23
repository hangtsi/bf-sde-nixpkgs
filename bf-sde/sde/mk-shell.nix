{ bf-sde, pkgs }:

{ inputFn ? { pkgs, pythonPkgs }: {}, kernelRelease, platform ? "model" }:

let
  sde = bf-sde.override {
    baseboard = bf-sde.baseboardForPlatform platform;
  };
  bf-drivers = sde.pkgs.bf-drivers;
  python = bf-drivers.pythonModule;
  defaultInputs = {
    pkgs = [];
    cpModules = [];
    ptfModules = [];
  };
  inputs = defaultInputs // (builtins.tryEval inputFn).value {
    inherit pkgs;
    pythonPkgs = python.pkgs;
  };
  pythonEnv = python.withPackages (ps: [ bf-drivers ]
                                       ++ inputs.cpModules);
in pkgs.mkShell {
  ## kmod provides insmod, procps provides sysctl
  buildInputs = [ sde (sde.modulesForKernel kernelRelease) pythonEnv ]
                  ++ inputs.pkgs;
  shellHook = ''
    export P4_INSTALL=~/.bf-sde/${sde.version}
    export SDE=${sde}
    export SDE_INSTALL=${sde}
    export SDE_BUILD=$P4_INSTALL/build
    export SDE_LOGS=$P4_INSTALL/logs
    export PTF_PYTHONPATH=${python.pkgs.makePythonPath inputs.ptfModules}
    mkdir -p $P4_INSTALL $SDE_BUILD $SDE_LOGS

    cat <<EOF

    Barefoot SDE ${sde.version} on platform "${platform}"

    Load/unload kernel modules: $ sudo \$(type -p bf_{kdrv,kpkt,knet}_mod_{load,unload})

    Compile: $ p4_build.sh <p4name>.p4
    Run:     $ run_switchd -p <p4name>
    Run Tofino model:
             $ sudo \$(type -p veth_setup.sh)
             $ run_tofino_model -p <p4name>
             $ run_switchd -p <p4name> -- --model
             $ sudo \$(type -p veth_teardown.sh)
    Run PTF tests: run the Tofino model, then
             $ run_p4_tests.sh -p <p4name> -t <path-to-dir-with-test-scripts>

    Build artifacts and logs are stored in $P4_INSTALL

    Use "exit" or CTRL-D to exit this shell.

    EOF
    PS1="\n\[\033[1;32m\][nix-shell(\033[31mSDE-${sde.version}\033[1;32m):\w]\$\[\033[0m\] "
  '';
}