# Value Registry

On-chain key/value registry for numeric parameters, structurally similar to the [Chainlog](https://github.com/makerdao/dss-chain-log) but storing **signed integer values** (`int256`) instead of addresses. 

## Intended use-case

Offchain bots and frontends that need a central place to store shared meta-parameters and require access to the history of the meta-parameter changes.

## Roles

- **wards** (`rely`/`deny`) — manage wards and buds;
- **buds** (`kiss`/`diss`) — manage key/value pairs;

## Methods

Write (buds only):

- **`setValues(KeyValue[] items)`** — set or overwrite values. `KeyValue` is `{bytes32 key; int256 val;}`. If the same key appears twice in one call, the last item wins. Emits `SetValue(key, val)` for every updated value.
- **`removeValues(bytes32[] keys)`** — remove keys, reverts if any is unset. Emits `RemoveValue(key)` for every removed key.

Both methods are batch-only; pass a one-element array for a single update. A batch is atomic - if `removeValues` hits an unset key partway through, the whole call reverts and no keys are removed.

Read:

- **`getValue(bytes32 key)`** — returns the value, reverts if the key is unset so an unset parameter can never be silently read as `0`.
- **`count()`**, **`get(uint256 index)`**, **`list()`** — enumeration helpers. Note that as `removeValues` uses swap-and-pop logic, `get(index)` and `list()` ordering changes on removal – therefore avoid fetching values using their index.


## Value convention

The registry itself is agnostic about keys and values. However, the proposed convention is to use `bytes32`-encoded strings for keys, with a suffix to indicate decimal count of the value. For example, use `_WAD` suffix for WAD-scaled values (18 decimal points) or `_BPS` for basis points (4 decimal points) or no suffix for plain numbers.

## Development

```shell
forge build      # compile
forge test       # run tests
forge fmt        # format
```

Clone with submodules:

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
        --rpc-url mainnet \
        --account <ACCOUNT_NAME> \
        --sender "$(cast wallet address --account <ACCOUNT_NAME>)" \
        --verify \
        --broadcast
    ```

The script deploys the registry (the deployer becomes a ward via the constructor), relies each admin, kisses each bud, and finally denies the deployer (unless it is included in the admin list).

## Contract usage

To set values on a deployed registry, run the `SetValues` script with the registry address, the keys (as plain strings, encoded to `bytes32` by the script) and the values. The account to run the script must be a bud. For example:

```shell
forge script script/SetValues.s.sol:SetValues \
    --sig "run(address,string[],int256[])" <REGISTRY> '["EXAMPLE_WAD","EXAMPLE_BPS"]' '[900000000000000000,50]' \
    --rpc-url mainnet \
    --account <ACCOUNT_NAME> \
    --broadcast
```

Keys and values are matched by index, so the example sets `EXAMPLE_WAD = 0.9e18` and `EXAMPLE_BPS = 50` in a single `setValues` batch.
