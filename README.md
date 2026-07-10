# stUSDS Value Registry

On-chain key/value registry for the stUSDS rate calculation meta-parameters, structurally similar to the [Chainlog](https://github.com/makerdao/dss-chain-log) but storing **signed integer values** (`int256`) instead of addresses.

## Roles

- **wards** (`rely`/`deny`) — manage wards and buds;
- **buds** (`kiss`/`diss`) — manage key/value pairs;

## Methods

Write (buds only):

- **`setValue(bytes32 key, int256 val)`** — set or overwrite a value.
- **`removeValue(bytes32 key)`** — remove a key, reverts if unset.

There are deliberately no batch methods: updating multiple values atomically in one transaction is handled by the calling multisig (e.g. a Safe MultiSend batch of `setValue` calls).

Read:

- **`getValue(bytes32 key)`** — returns the value, reverts if the key is unset so an unset parameter can never be silently read as `0`.
- **`has(bytes32 key)`**, **`count()`**, **`get(uint256 index)`**, **`list()`** — enumeration helpers.

Every mutation emits `SetValue(key, val)` or `RemoveValue(key)`.

## Value convention

All values are stored **WAD-scaled** (multiplied by `1e18`), uniformly — including plain counts. Keys carry a `_WAD` suffix and are `bytes32`-encoded strings, e.g. `cast format-bytes32-string "OPT_UTIL_WAD"`.

| Key | Human value | Stored value |
|---|---|---|
| `ACCESSIBILITY_REWARD_WAD` | 0.002 | 0.002e18 |
| `OPT_UTIL_WAD` | 0.9 | 0.9e18 |
| `BASE_SPREAD_WAD` | 0.001 | 0.001e18 |
| `SPREAD_PCT_WAD` | 0.1 | 0.1e18 |
| `TIME_DRIFT_SPEED_WAD` | 0.03 | 0.03e18 |
| `ABOVE_KINK_MULTIPLIER_WAD` | 0.77 | 0.77e18 |
| `CAP_FACTOR_WAD` | 1.35 | 1.35e18 |
| `LINE_FACTOR_WAD` | 1.20 | 1.2e18 |
| `AVERAGE_UTILIZATION_HOURS_WAD` | 24 | 24e18 |
| `UPDATE_THRESHOLD_WAD` | 2 bps | 0.0002e18 |

## Development

```shell
forge build      # compile
forge test       # run tests
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
