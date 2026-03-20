# Automated module options documentation

*2026-03-20T15:45:16Z by Showboat 0.6.1*
<!-- showboat-id: 4afaedff-a944-4b6d-aefd-b54dbbd25da7 -->

Using nixosOptionsDoc to auto-generate markdown documentation for our devenv module options. The approach uses lib.evalModules with a minimal devenvStub module that provides just enough of the devenv option structure (devenv.state, packages, env, processes, tasks, scripts) for our modules to evaluate. The stub's /tmp/devenv-state path is replaced with ${devenv.state} in the output via transformOptions.

```bash
cat docs/options.nix
```

```output
{ pkgs ? import <nixpkgs> { }
}:
let
  lib = pkgs.lib;

  # Minimal stubs for devenv options that our modules reference.
  devenvStub = { config, ... }: {
    options = {
      devenv.state = lib.mkOption {
        type = lib.types.str;
        default = "/tmp/devenv-state";
      };

      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
      };

      env = lib.mkOption {
        type = lib.types.submodule {
          freeformType = lib.types.lazyAttrsOf lib.types.anything;
        };
        default = { };
      };

      processes = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          freeformType = lib.types.lazyAttrsOf lib.types.anything;
          options = {
            exec = lib.mkOption {
              type = lib.types.str;
              description = "Bash code to run the process.";
            };
            after = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Processes that must be ready before this one starts.";
            };
            ready = lib.mkOption {
              type = lib.types.submodule {
                freeformType = lib.types.lazyAttrsOf lib.types.anything;
              };
              default = { };
              description = "Readiness probe configuration.";
            };
            process-compose = lib.mkOption {
              type = lib.types.submodule {
                freeformType = lib.types.lazyAttrsOf lib.types.anything;
              };
              default = { };
              description = "Process-compose specific configuration.";
            };
          };
        });
        default = { };
      };

      tasks = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
      };

      scripts = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
      };
    };
  };

  eval = lib.evalModules {
    modules = [
      { _module.args = { inherit pkgs; }; }
      devenvStub
      ../src/modules/bitcoind.nix
      ../src/modules/lnd.nix
      ../src/modules/nostr-rs-relay.nix
      ../src/modules/podman.nix
    ];
  };

  filteredOptions = lib.filterAttrs (name: _: name == "services") eval.options;

  doc = pkgs.nixosOptionsDoc {
    options = filteredOptions;
    documentType = "none";
    warningsAreErrors = false;
    transformOptions = opt: opt // {
      declarations = [ ];
      default = if opt ? default && opt.default ? text then
        opt.default // {
          text = builtins.replaceStrings
            [ "/tmp/devenv-state" ]
            [ "\${devenv.state}" ]
            opt.default.text;
        }
      else
        opt.default or { };
    };
  };
in
doc.optionsCommonMark
```

```bash
nix build -f docs/options.nix --no-link --print-out-paths 2>&1 | tail -1 | xargs cat
```

````output
## services\.bitcoind\.enable



Whether to enable Bitcoin daemon\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```



## services\.bitcoind\.package



The bitcoind package to use\.



*Type:*
package



*Default:*

```nix
<derivation bitcoind-30.2>
```



## services\.bitcoind\.dataDir

Data directory for bitcoind\.



*Type:*
string



*Default:*

```nix
"${devenv.state}/bitcoind"
```



## services\.bitcoind\.extraConfig



Extra lines appended to bitcoin\.conf\.



*Type:*
strings concatenated with “\\n”



*Default:*

```nix
""
```



## services\.bitcoind\.regtest



Enable regtest mode\.



*Type:*
boolean



*Default:*

```nix
false
```



## services\.bitcoind\.rpcAddress



Address for the RPC server to bind to\.



*Type:*
string



*Default:*

```nix
"127.0.0.1"
```



## services\.bitcoind\.rpcPassword



RPC password\.



*Type:*
string



*Default:*

```nix
"devenv"
```



## services\.bitcoind\.rpcPort



Port for the RPC server\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
8332
```



## services\.bitcoind\.rpcUser



RPC username\.



*Type:*
string



*Default:*

```nix
"devenv"
```



## services\.bitcoind\.zmq\.enable



Whether to enable ZMQ pub/sub endpoints\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```



## services\.bitcoind\.zmq\.pubrawblock



ZMQ endpoint for publishing raw blocks\.



*Type:*
string



*Default:*

```nix
"tcp://127.0.0.1:28332"
```



## services\.bitcoind\.zmq\.pubrawtx



ZMQ endpoint for publishing raw transactions\.



*Type:*
string



*Default:*

```nix
"tcp://127.0.0.1:28333"
```



## services\.lnd\.enable



Whether to enable Lightning Network daemon\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```



## services\.lnd\.package



The lnd package to use\.



*Type:*
package



*Default:*

```nix
<derivation lnd-0.20.1-beta>
```



## services\.lnd\.dataDir



Data directory for lnd\.



*Type:*
string



*Default:*

```nix
"${devenv.state}/lnd"
```



## services\.lnd\.extraConfig



Extra lines appended to lnd\.conf\.



*Type:*
strings concatenated with “\\n”



*Default:*

```nix
""
```



## services\.lnd\.listenAddress



Address to listen for peer connections\.



*Type:*
string



*Default:*

```nix
"127.0.0.1"
```



## services\.lnd\.listenPort



Port to listen for peer connections\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
9735
```



## services\.lnd\.restAddress



Address to listen for REST connections\.



*Type:*
string



*Default:*

```nix
"127.0.0.1"
```



## services\.lnd\.restPort



Port to listen for REST connections\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
8080
```



## services\.lnd\.rpcAddress



Address to listen for gRPC connections\.



*Type:*
string



*Default:*

```nix
"127.0.0.1"
```



## services\.lnd\.rpcPort



Port to listen for gRPC connections\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
10009
```



## services\.nostr-rs-relay\.enable



Whether to enable nostr-rs-relay Nostr relay\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```



## services\.nostr-rs-relay\.package



The nostr-rs-relay package to use\.



*Type:*
package



*Default:*

```nix
<derivation nostr-rs-relay-0.9.0>
```



## services\.nostr-rs-relay\.address



Address to listen on\.



*Type:*
string



*Default:*

```nix
"127.0.0.1"
```



## services\.nostr-rs-relay\.dataDir



Directory for SQLite database files\.



*Type:*
string



*Default:*

```nix
"${devenv.state}/nostr-rs-relay"
```



## services\.nostr-rs-relay\.port



Port to listen on\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
8080
```



## services\.nostr-rs-relay\.settings



Structured settings merged into config\.toml\. See https://git\.sr\.ht/~gheartsfield/nostr-rs-relay/\#configuration for documentation\.



*Type:*
TOML value



*Default:*

```nix
{ }
```



## services\.podman-machine\.enable



Whether to enable Podman Machine\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```



## services\.podman-machine\.machineName



Name of the machine to start\.



*Type:*
string



*Default:*

```nix
"devenv"
```


````
