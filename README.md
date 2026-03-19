# HW6 — Vega Voting System

4 контракта: ERC20 токен VV, стейкинг с VP формулой, голосование с auto-finalization, ERC721 NFT с результатами.

**VP = weeksRemaining² × (amount / 1e18)**

## Контракты на Sepolia

| Контракт | Адрес |
|----------|-------|
| VegaVotingToken (VV) | [0x5cB461D21F79755852a54248E54BdA63e02E3f50](https://sepolia.etherscan.io/address/0x5cB461D21F79755852a54248E54BdA63e02E3f50) |
| StakingVault | [0x989e6c3Fb6A07351679e9893e3A426d9Df2cA42A](https://sepolia.etherscan.io/address/0x989e6c3Fb6A07351679e9893e3A426d9Df2cA42A) |
| VoteResultNFT (VVR) | [0x24aC07C929dbebb24E4F52a6FAE6dDaA7047B32c](https://sepolia.etherscan.io/address/0x24aC07C929dbebb24E4F52a6FAE6dDaA7047B32c) |
| VotingSystem | [0x543C92112Db15796Da6bFa94186bc8065Cd7e4D2](https://sepolia.etherscan.io/address/0x543C92112Db15796Da6bFa94186bc8065Cd7e4D2) |

## Транзакции

| Действие | Tx |
|----------|----|
| Deploy | [0xcb5f170...](https://sepolia.etherscan.io/tx/0xcb5f17052b0368d2ca824d0d9897f3233bff1856a1bb3442395fc5389c32a333) |
| Stake 500 VV | [0xc1e8fb1...](https://sepolia.etherscan.io/tx/0xc1e8fb1688f7e629b4501df14ef74e8b1ca2e0ac840edcdb66087a9c9f3797ef) |
| Vote YES → auto-finalize → NFT mint | [0x5c2b959...](https://sepolia.etherscan.io/tx/0x5c2b959c9b7dc182de422c8cd638879bb91a93e278c4525a0177b0a3e54de5be) |

## Тесты

```bash
forge test
# 40 tests, 0 failed
```
