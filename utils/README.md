# Util Scripts
This is a collection of helper scripts that are used in the main scripts. They are not guaranteed to work as standalone scripts but can still be called directly from the terminal if needed.

## Usage
> NOTE: Call scripts from the root directory. If called from any other subdirectory, the relative paths used by scripts will not work.

### [check-connection.sh](./check-connection.sh)
Runs a periodic, finite loop to check if a server is live at the given url.

#### Args:
- _--url=server-url:port_ (REQUIRED)
- _--interval=5_ (OPTIONAL. Wait time between requests in seconds. Defaults to 5)
- _--max_retries=20_ (OPTIONAL. Maximum number of requests to send. Defaults to 20)

```shell
sh ./utils/check-connection.sh --url=localhost:8080 --interval=5 --max_retries=20
```

### [parse-args.sh](./parse-args.sh)
Importable script that can be added to the top of other scripts to parse command line arguments, like so:
```shell
#!/bin/sh

# Get named arguments
. utils/parse-args.sh "$@"
...
```
Command line arguments can then be accessed by their name. For example, if the argument is passed as `--arg=value`, it can be accessed in your script by referencing it: `echo "arg value: $arg"`.

### [gen-keycloak-config.sh](./parse-args.sh)
Script to add given list of studies to the given keycloak config template. This script is still experimental and intended for a specific localdb tests use case.
```shell
sh ./scripts/gen-keycloak-config.sh --studies='study_1 study_2 study_3' --template=/path/to/keycloak-config-template.json --out=/path/to/generated-keycloak-config.json
```
