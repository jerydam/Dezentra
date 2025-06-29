
# 🚚 DezentraLogistics

**Buy With Trust. Pay From Any Chain.**

DezentraLogistics is a decentralized, multichain e-commerce logistics platform that empowers buyers, sellers, and logistics providers to transact with trust, across chains, using smart contracts, Chainlink CCIP, and stablecoin-based escrow. Built with Solidity, Vite, Node.js, and AWS, it enables seamless product purchases, dispute resolution, and payment settlement — locally or cross-chain.

---

## 🔍 Use Case

- 🛍️ **Sellers** can list physical goods with delivery options.
- 🧍‍♂️ **Buyers** can purchase locally or cross-chain with any token.
- 🚚 **Logistics providers** manage delivery and are paid in USDT.
- 🔒 **Escrow** ensures funds are only released after confirmed delivery.
- 🌉 **CCIP (Chainlink)** handles cross-chain purchases and confirmations.

---

## 💡 Problem It Solves

> Traditional e-commerce lacks **trust**, **cross-border compatibility**, and **buyer protection** — especially for small-scale sellers using platforms like WhatsApp or Instagram.

DezentraLogistics solves this by:

- Enabling **trustless escrow** via smart contracts.
- Supporting **cross-chain purchases** using **Chainlink CCIP**.
- Offering **decentralized dispute resolution**.
- Automating **fee distribution** and **settlements** in **USDT**.
- Using **AWS** for backend operations (e.g., metadata, logistics records).
- Ensuring delivery is **verified by logistics providers**, not centralized third parties.

---

## ⚙️ Tech Stack

| Layer       | Stack                                  |
|------------|-----------------------------------------|
| Smart Contract | Solidity, Chainlink CCIP, LINK, USDT |
| Frontend    | Vite, React, Ethers.js                  |
| Backend     | Node.js, Express, AWS (S3, Lambda)      |
| Dev Tools   | Hardhat, OpenZeppelin, IPFS             |
| Messaging   | Chainlink CCIP                          |

---

## 📦 Features

### ✅ Core Functionality

- **Trade Listing**: Sellers list goods with delivery costs and available logistics providers.
- **Local Purchase**: Buyers purchase on the same chain; tokens are escrowed.
- **Cross-Chain Purchase**: CCIP handles interchain messaging and token movement.
- **Delivery Confirmation**: Buyer confirms delivery, triggering payment release.
- **Dispute Resolution**: Disputes can be raised and resolved fairly by the owner.
- **Fee Handling**: Platform collects a 2.5% fee on total cost.
- **Token Flexibility**: Buyers can pay with any token (assumed off-chain swap to USDT).
- **Chain Allowlisting**: Only approved source chains can initiate CCIP messages.

### 🔄 Workflow Summary

1. **Seller creates a trade** →  specifies price, logistics cost, providers, quantity.
2. **Buyer makes purchase** →  local (`buyTrade`) or cross-chain (`buyCrossChainTrade`).
3. **Escrow holds funds** →  in USDT, fee deducted automatically.
4. **Delivery and confirmation** →  Buyer confirms delivery, seller and logistics get paid.
5. **Dispute/Cancellation** → Buyer or seller can dispute or cancel if needed.



## 🧪 Challenges We Solved

- **Integrating Chainlink CCIP**: CCIP is powerful but complex. We ensured safe, cross-chain message handling and token transfers.
- **Token Compatibility**: We built support for LINK/native token fee payments and USDT-based escrow, while handling off-chain token logic.
- **Frontend Sync**: Syncing on-chain state with the frontend across chains in real time was tough. We used Ethers.js events and polling.
- **AWS Integration**: Deployed backend logic on AWS Lambda and used S3 for handling logistics proof files or metadata.

## 🧩 Hackathon Track Relevance

### 🔗 **Cross-Chain Solutions**

DezentraLogistics integrates Chainlink CCIP for **cross-chain purchase settlement**, message routing, and payment distribution across Avalanche, Sepolia, and Base.

### ☁️ **AWS Track**

We utilize AWS Lambda and S3 for off-chain metadata and logic, creating a hybrid decentralized app that scales while maintaining Web3 integrity.

### 🧠 **Build the Future of Web3 x AI with Amazon Bedrock**

Future plans include using **AI for fraud detection** (fake listings or repeated disputes), **auto-selection of optimal logistics providers**, and **AI-powered buyer verification workflows** using Amazon Bedrock.

### ❄️ **Avalanche Track**

Contracts are deployed on Avalanche Fuji, enabling low-cost, fast transaction settlement and logistics payment routing in a decentralized manner.

---

## 📹 Demo

* 🎥 [Demo Video](https://www.loom.com/share/c1e546b631b5431ba1919aa20f40046a)
* 🧩 [Logistic Contract address](https://testnet.snowtrace.io/0xF2dEd23F5C2Aded789D28EFb62154832E913A22E)
* 🧩 [token Contract address](https://testnet.snowtrace.io/0xC67383553f36DF0305C52E9eEafBd903c47039c5)
---

## 📎 Key Contracts

* `logistics.sol` — Core logic for trade, purchase, CCIP, and escrow.
* `token.sol` — Test token contracts for local testing.

---

## 🔐 Security Considerations

* Reentrancy guards around external calls
* Input validation on all trade and purchase logic
* CCIP message replay protection
* Custom errors for gas efficiency

---


🌐 [Project Link](https://dezentra.netlify.app)

---

**DezentraLogistics** — Redefining e-commerce. One chain at a time.
