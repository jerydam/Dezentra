/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_URL: string;
  readonly VITE_THIRDWEB_CLIENT_ID: string;
  // readonly VITE_ESCROW_CONTRACT_TESTNET: string;
  // readonly VITE_ESCROW_CONTRACT_MAINNET: string;
  // readonly VITE_USDT_CONTRACT_ADDRESS_TESTNET: string;
  // readonly VITE_USDT_CONTRACT_ADDRESS_MAINNET: string;
  readonly VITE_USDT_CONTRACT_ADDRESS_AVALANCHE_FUJI: string;
  readonly VITE_ESCROW_CONTRACT_AVALANCHE_FUJI: string;
  readonly VITE_USDT_CONTRACT_ADDRESS_BASE_SEPOLIA: string;
  readonly VITE_ESCROW_CONTRACT_BASE_SEPOLIA: string;
  readonly VITE_USDT_CONTRACT_ADDRESS_SEPOLIA: string;
  readonly VITE_ESCROW_CONTRACT_SEPOLIA: string;
  readonly VITE_USDT_CONTRACT_ADDRESS_ARB_SEPOLIA: string;
  readonly VITE_ESCROW_CONTRACT_ARB_SEPOLIA: string;
  readonly VITE_WALLETCONNECT_PROJECT_ID: string;
  readonly VITE_INFURA_KEY: string;
  readonly VITE_APP_NAME: string;
  readonly VITE_APP_VERSION: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
