# Sky Value Registry

On-chain key/value registry for numeric parameters, structurally similar to the [Chainlog](https://github.com/makerdao/dss-chain-log) but storing **signed integer values** (`int256`) instead of addresses.

## Roles

- **wards** (`rely`/`deny`) — manage wards and buds;
- **buds** (`kiss`/`diss`) — manage key/value pairs;

## Methods

Write (buds only):

- **`setValues(KeyValue[] items)`** — set or overwrite values. `KeyValue` is `{bytes32 key; int256 val;}`. If the same key appears twice in one call, the last item wins.
- **`removeValues(bytes32[] keys)`** — remove keys, reverts if any is unset.

Both methods are batch-only; pass a one-element array for a single update. A batch is atomic - if `removeValues` hits an unset key partway through, the whole call reverts and no keys are removed.

Read:

- **`getValue(bytes32 key)`** — returns the value, reverts if the key is unset so an unset parameter can never be silently read as `0`.
- **`has(bytes32 key)`**, **`count()`**, **`get(uint256 index)`**, **`list()`** — enumeration helpers.

Every mutation emits `SetValue(key, val)` or `RemoveValue(key)`.

## Value convention

The registry itself is agnostic about keys and scaling; by convention values are stored **WAD-scaled** (multiplied by `1e18`), uniformly — including plain counts. Keys carry a `_WAD` suffix and are `bytes32`-encoded strings, e.g. `cast format-bytes32-string "PARAM_WAD"`.

**Examples**

| Key | Human value | Stored value |
|---|---|---|
| `PARAM_WAD` | 0.9 | 0.9e18 |
| `NEGATIVE_PARAM_WAD` | -0.5 | -0.5e18 |
| `HOURS_WAD` | 24 | 24e18 |
| `THRESHOLD_WAD` | 2 bps | 0.0002e18 |

## Development

```shell
forge build      # compile
forge test       # run tests (requires `ETH_RPC_URL` to run test on ethereum mainnet fork)
forge fmt        # format
```

Clone with submodule (`forge-std`):

```shell
git clone --recurse-submodules <repo-url>
# or, after a plain clone:
git submodule update --init --recursive
```

## Deployment

1. Set ENV variables
    - ETH_RPC_URL: ethereum mainnet rpc url
    - ETHERSCAN_API_KEY: etherscan api key to verify the contract
2. Run command to deploy, passing the admin and bud addresses to be set
    ```shell
    forge script script/Deploy.s.sol:DeployValueRegistry \
        --sig "run(address[],address[])" "[<ADMIN_1>,<ADMIN_2>]" "[<BUD_1>]" \
        --rpc-url "$ETH_RPC_URL" \
        --account <ACCOUNT_NAME> \
        --verify \
        --broadcast
    ```

The script deploys the registry (the deployer becomes a ward via the constructor), relies each admin, kisses each bud, and finally denies the deployer.
