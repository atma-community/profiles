<p align="center">
  <img src="https://github.com/user-attachments/assets/d93aef5a-69c5-4dac-bd82-8f51480c97d5" alt="logo" width="150"/>
</p>

# Stoa Profiles

Stoa Profiles is a smart contract/decentralized application (dapp) that allows users to create and manage their own unique pages on the Cardano blockchain. Think of it as a personal, on-chain profile that users can update and control. These unique NFTs can serve as a launchpad for diverse applications, including digital identity, real-world assets (RWA), and more.

---

## How it Works (User Perspective)

1. **Account Creation:** A user creates an account and acquires a unique username.  
2. **Initial Page Data:** The user uploads their initial profile data onto the blockchain.  
3. **Page Modification:** Users can update their page data at any time, writing new information on-chain that replaces the old.  
4. **Account Decommission:** Users can remove their data from the blockchain if they wish to decommission their account.  

---

## Technical Overview

On-chain, Stoa Profiles data is structured as a sorted linked list. Each user’s page is associated with a **validity token** that confirms its legitimacy and references the next item in the list.

### Interoperability with CIP-68

Stoa Profiles are designed for interoperability and follows the [CIP-68](https://cips.cardano.org/cips/cip68/) standard. When a user creates an account, **two specific tokens are minted**:

- **User Token (label 222):** Held by the user, representing their ownership of the page.  
- **Script Token (Reference NFT, label 100):** Locked at the validator address and stores the page’s data.  

The encoding of these token labels follows [CIP-67](https://cips.cardano.org/cips/cip67/).

---

## License

This project is released under the [Apache 2.0 License](./LICENSE). You are free to use and adapt this code with proper attribution. No warranties are provided.  

---

## Community and Credits

- Funded in part by [Project Catalyst](https://projectcatalyst.io/).
- Funded, and co-developed in part by [Atrium Lab Inc](https://atriumlab.io).
- Developed by Kompact.

---
