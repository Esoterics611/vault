// Ethereum Bridge — wraps window.ethereum (MetaMask / injected provider) for Flutter web.
// Loaded before flutter_bootstrap.js. Flutter calls these via dart:js_util.

window.ethereumBridge = {
  isAvailable: function () {
    return typeof window.ethereum !== 'undefined';
  },

  requestAccounts: async function () {
    const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
    return accounts[0];
  },

  getChainId: async function () {
    const chainId = await window.ethereum.request({ method: 'eth_chainId' });
    return parseInt(chainId, 16);
  },

  // Ask the wallet to add/switch to Base Sepolia (84532).
  // Uses window.ethereum.chainId (a property, not an RPC call) to skip the
  // popup entirely when already on the right chain.
  switchToBaseSepolia: async function () {
    const BASE_SEPOLIA = '0x14a34'; // 84532

    // window.ethereum.chainId is a sync property — no RPC request needed.
    // If already on Base Sepolia, do nothing (avoids unwanted popup on refresh).
    const current = window.ethereum.chainId;
    if (current && current.toLowerCase() === BASE_SEPOLIA) return;

    try {
      await window.ethereum.request({
        method: 'wallet_addEthereumChain',
        params: [{
          chainId: BASE_SEPOLIA,
          chainName: 'Base Sepolia',
          nativeCurrency: { name: 'ETH', symbol: 'ETH', decimals: 18 },
          rpcUrls: ['https://sepolia.base.org'],
          blockExplorerUrls: ['https://sepolia.basescan.org'],
        }],
      });
    } catch (err) {
      if (err.code === 4001) throw err; // user explicitly rejected — surface it
      console.warn('wallet_addEthereumChain (may be harmless):', err);
    }
  },

  // Send a contract call or plain ETH transfer through MetaMask.
  // dataHex: ABI-encoded calldata (0x-prefixed), or '0x' for plain transfers.
  // valueHex: wei amount as 0x-prefixed hex, or '0x0'.
  sendTransaction: async function (to, dataHex, valueHex, from) {
    const params = { from: from, to: to, data: dataHex };
    if (valueHex && valueHex !== '0x0') params.value = valueHex;
    return await window.ethereum.request({
      method: 'eth_sendTransaction',
      params: [params],
    });
  },

  // Register account-change listener; calls window[callbackName](newAddress).
  onAccountsChanged: function (callbackName) {
    window.ethereum.on('accountsChanged', function (accounts) {
      if (typeof window[callbackName] === 'function') {
        window[callbackName](accounts[0] || '');
      }
    });
  },
};
