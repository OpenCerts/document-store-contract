// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.23 <0.9.0;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../upgradeables/DocumentStoreUpgradeable.sol";
import "../upgradeables/OwnableDocumentStoreUpgradeable.sol";

library DeployUtils {
  function deployDocumentStoreUpgradeable(string memory name, address initAdmin) internal returns (address, address) {
    bytes memory initData = abi.encodeCall(DocumentStoreUpgradeable.initialize, (name, initAdmin));

    DocumentStoreUpgradeable documentStore = new DocumentStoreUpgradeable(name, initAdmin);
    address dsAddr = address(documentStore);

    ERC1967Proxy proxy = new ERC1967Proxy(dsAddr, initData);

    return (address(proxy), dsAddr);
  }

  function deployOwnableDocumentStoreUpgradeable(
    string memory name,
    string memory symbol,
    address initAdmin
  ) internal returns (address, address) {
    bytes memory initData = abi.encodeCall(OwnableDocumentStoreUpgradeable.initialize, (name, symbol, initAdmin));

    OwnableDocumentStoreUpgradeable documentStore = new OwnableDocumentStoreUpgradeable(name, symbol, initAdmin);
    address dsAddr = address(documentStore);

    ERC1967Proxy proxy = new ERC1967Proxy(dsAddr, initData);

    return (address(proxy), dsAddr);
  }
}
