// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.23 <0.9.0;

import "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import "./CommonTest.t.sol";

contract OwnableDocumentStore_init_Test is OwnableDocumentStoreCommonTest {
  function testDocumentStoreName() public {
    assertEq(documentStore.name(), storeName);
  }

  function testDocumentStoreSymbol() public {
    assertEq(documentStore.symbol(), storeSymbol);
  }

  function testOwnerIsAdmin() public view {
    assert(documentStore.hasRole(documentStore.DEFAULT_ADMIN_ROLE(), owner));
  }

  function testOwnerIsIssuer() public view {
    assert(documentStore.hasRole(documentStore.ISSUER_ROLE(), owner));
  }

  function testOwnerIsRevoker() public view {
    assert(documentStore.hasRole(documentStore.REVOKER_ROLE(), owner));
  }

  function testFailZeroOwner() public {
    documentStore = new OwnableDocumentStore(storeName, storeSymbol, vm.addr(0));
  }
}

contract OwnableDocumentStore_issue_Test is OwnableDocumentStoreCommonTest {
  address public recipient;

  function setUp() public override {
    super.setUp();

    recipient = vm.addr(1234);
  }

  function testIssueAsIssuer(bytes32 document) public {
    vm.assume(document != bytes32(0));

    vm.prank(issuer);
    documentStore.issue(recipient, document, false);
  }

  function testIssueAsNonIssuerRevert(bytes32 document) public {
    vm.assume(document != bytes32(0));

    address nonIssuer = vm.addr(69);

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        nonIssuer,
        documentStore.ISSUER_ROLE()
      )
    );

    vm.prank(nonIssuer);
    documentStore.issue(recipient, document, false);
  }

  function testIssueAsRevokerRevert(bytes32 document) public {
    vm.assume(document != bytes32(0));

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        revoker,
        documentStore.ISSUER_ROLE()
      )
    );

    vm.prank(revoker);
    documentStore.issue(recipient, document, false);
  }

  function testIssueToRecipient(bytes32 document) public {
    vm.assume(document != bytes32(0));

    vm.prank(issuer);
    documentStore.issue(recipient, document, false);

    address docOwner = documentStore.ownerOf(uint256(document));

    assertTrue(docOwner == recipient, "Document owner is not the recipient");
  }

  function testIssueUnlockedDocument(bytes32 document) public {
    vm.assume(document != bytes32(0));
    vm.expectEmit(true, false, false, true);

    emit IERC5192.Unlocked(uint256(document));

    vm.prank(issuer);
    documentStore.issue(recipient, document, false);

    bool isLocked = documentStore.locked(uint256(document));
    assertFalse(isLocked, "Document should not be locked");
  }

  function testIssueLockedDocument(bytes32 document) public {
    vm.assume(document != bytes32(0));
    vm.expectEmit(true, false, false, true);

    emit IERC5192.Locked(uint256(document));

    vm.prank(issuer);
    documentStore.issue(recipient, document, true);

    bool isLocked = documentStore.locked(uint256(document));
    assertTrue(isLocked, "Document should be locked");
  }

  function testIssueToZeroRecipientRevert(bytes32 document) public {
    vm.assume(document != bytes32(0));

    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, address(0)));

    vm.prank(issuer);
    documentStore.issue(address(0), document, false);
  }

  function testIssueToZeroDocumentRevert() public {
    vm.expectRevert(abi.encodeWithSelector(IOwnableDocumentStoreErrors.ZeroDocument.selector));

    vm.prank(issuer);
    documentStore.issue(recipient, bytes32(0), false);
  }

  function testIssueAlreadyIssuedDocumentToSameRecipientRevert(bytes32 document) public {
    vm.assume(document != bytes32(0));
    vm.prank(issuer);
    documentStore.issue(recipient, document, false);

    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidSender.selector, address(0)));

    vm.prank(issuer);
    documentStore.issue(recipient, document, false);
  }

  function testIssueAlreadyIssuedDocumentToDifferentRecipientRevert(bytes32 document) public {
    vm.assume(document != bytes32(0));
    vm.prank(issuer);
    documentStore.issue(recipient, document, false);

    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidSender.selector, address(0)));

    vm.prank(issuer);
    documentStore.issue(vm.addr(69), document, false);
  }

  function testIssueRevokedDocumentToSameRecipientRevert(bytes32 document) public {
    vm.assume(document != bytes32(0));
    vm.startPrank(owner);
    documentStore.issue(recipient, document, false);
    documentStore.revoke(document);
    vm.stopPrank();

    vm.expectRevert(abi.encodeWithSelector(IOwnableDocumentStoreErrors.DocumentIsRevoked.selector, document));

    vm.prank(issuer);
    documentStore.issue(recipient, document, false);
  }

  function testIssueRevokedDocumentToDifferentRecipientRevert(bytes32 document) public {
    vm.assume(document != bytes32(0));
    vm.startPrank(owner);
    documentStore.issue(recipient, document, false);
    documentStore.revoke(document);
    vm.stopPrank();

    vm.expectRevert(abi.encodeWithSelector(IOwnableDocumentStoreErrors.DocumentIsRevoked.selector, document));

    vm.prank(issuer);
    documentStore.issue(vm.addr(69), document, false);
  }
}

contract OwnableDocumentStore_revoke_Test is OwnableDocumentStore_Initializer {
  bytes32 public unlockedDocument;
  bytes32 public lockedDocument;

  function setUp() public override {
    super.setUp();

    unlockedDocument = documents[0];
    lockedDocument = documents[1];
  }

  function testRevokeUnlockedDocumentAsRevokerSuccess() public {
    vm.prank(revoker);
    documentStore.revoke(unlockedDocument);

    assertTrue(documentStore.isRevoked(unlockedDocument), "Document is should be revoked");
    assertEq(documentStore.balanceOf(recipients[0]), 0);
  }

  function testRevokeLockedDocumentAsRevokerSuccess() public {
    vm.prank(revoker);
    documentStore.revoke(lockedDocument);

    assertTrue(documentStore.isRevoked(lockedDocument), "Document is should be revoked");
    assertEq(documentStore.balanceOf(recipients[1]), 0);
  }

  function testRevokeAsIssuerRevert() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        issuer,
        documentStore.REVOKER_ROLE()
      )
    );

    vm.prank(issuer);
    documentStore.revoke(unlockedDocument);
  }

  function testRevokeAsNonRevokerRevert() public {
    address nonRevoker = vm.addr(69);

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        nonRevoker,
        documentStore.REVOKER_ROLE()
      )
    );

    vm.prank(nonRevoker);
    documentStore.revoke(unlockedDocument);
  }

  function testRevokeZeroDocumentRevert() public {
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 0x0));

    vm.prank(revoker);
    documentStore.revoke(bytes32(0));
  }

  function testRevokeNotIssuedDocumentRevert() public {
    bytes32 notIssuedDoc = "0x1234";

    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, notIssuedDoc));

    vm.prank(revoker);
    documentStore.revoke(notIssuedDoc);
  }

  function testRevokeAlreadyRevokedDocumentRevert() public {
    vm.prank(revoker);
    documentStore.revoke(unlockedDocument);

    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, unlockedDocument));

    vm.prank(revoker);
    documentStore.revoke(unlockedDocument);
  }

  function testRevokeDocumentOwnerIsZeroRevert() public {
    vm.prank(revoker);
    documentStore.revoke(unlockedDocument);

    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, unlockedDocument));

    documentStore.ownerOf(uint256(unlockedDocument));
  }
}

contract OwnableDocumentStore_isIssued_Test is OwnableDocumentStore_Initializer {
  function testIsIssued() public {
    assertTrue(documentStore.isIssued(documents[0]), "Document should be issued");
  }

  function testIsIssuedNotIssuedDocument() public {
    bytes32 notIssuedDoc = "0x1234";

    assertFalse(documentStore.isIssued(notIssuedDoc), "Document should not be issued");
  }

  function testIsIssuedRevokedDocument() public {
    vm.prank(revoker);
    documentStore.revoke(documents[0]);

    assertTrue(documentStore.isIssued(documents[0]), "Document should be issued");
  }

  function testIsIssuedZeroDocumentRevert() public {
    vm.expectRevert(abi.encodeWithSelector(IOwnableDocumentStoreErrors.ZeroDocument.selector));

    documentStore.isIssued(bytes32(0));
  }
}

contract OwnableDocumentStore_isRevoked_Test is OwnableDocumentStore_Initializer {
  function setUp() public override {
    super.setUp();

    vm.prank(revoker);
    documentStore.revoke(documents[0]);
  }

  function testIsRevoked() public {
    assertTrue(documentStore.isRevoked(documents[0]), "Document should be revoked");
  }

  function testIsRevokedNotRevokedDocument() public {
    assertFalse(documentStore.isRevoked(documents[1]), "Document should not be revoked");
  }

  function testIsRevokedNotIssuedDocumentRevert() public {
    bytes32 notIssuedDoc = "0x1234";

    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, notIssuedDoc));

    documentStore.isRevoked(notIssuedDoc);
  }

  function testIsRevokedZeroDocumentRevert() public {
    vm.expectRevert(abi.encodeWithSelector(IOwnableDocumentStoreErrors.ZeroDocument.selector));

    documentStore.isRevoked(bytes32(0));
  }
}

contract OwnableDocumentStore_isActive_Test is OwnableDocumentStore_Initializer {
  function testIsActive() public {
    assertTrue(documentStore.isActive(documents[0]), "Document should be active");
    assertTrue(documentStore.isActive(documents[1]), "Document should be active");
  }

  function testIsActiveRevertedDocument() public {
    vm.startPrank(revoker);
    documentStore.revoke(documents[0]);
    documentStore.revoke(documents[1]);
    vm.stopPrank();

    assertFalse(documentStore.isActive(documents[0]), "Document should not be active");
    assertFalse(documentStore.isActive(documents[1]), "Document should not be active");
  }

  function testIsActiveNotIssuedDocumentRevert() public {
    bytes32 notIssuedDoc = "0x1234";

    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, notIssuedDoc));

    documentStore.isActive(notIssuedDoc);
  }

  function testIsActiveZeroDocumentRevert() public {
    vm.expectRevert(abi.encodeWithSelector(IOwnableDocumentStoreErrors.ZeroDocument.selector));

    documentStore.isActive(bytes32(0));
  }
}

contract OwnableDocumentStore_transfer_Test is OwnableDocumentStore_Initializer {
  bytes32 public unlockedDocument;
  bytes32 public lockedDocument;

  function setUp() public override {
    super.setUp();

    unlockedDocument = documents[0];
    lockedDocument = documents[1];
  }

  function testTransferFromUnlockedDocumentToNewRecipient() public {
    vm.prank(recipients[0]);
    documentStore.transferFrom(recipients[0], recipients[1], uint256(unlockedDocument));

    address docOwner = documentStore.ownerOf(uint256(unlockedDocument));
    uint256 balanceOfRecipient0 = documentStore.balanceOf(recipients[0]);
    uint256 balanceOfRecipient1 = documentStore.balanceOf(recipients[1]);

    assertTrue(docOwner == recipients[1], "Document owner is not the recipient");
    assertEq(balanceOfRecipient0, 0);
    assertEq(balanceOfRecipient1, 2);
  }

  function testTransferFromLockedDocumentToNewRecipientRevert() public {
    vm.expectRevert(abi.encodeWithSelector(IOwnableDocumentStoreErrors.DocumentLocked.selector, lockedDocument));

    vm.prank(recipients[1]);
    documentStore.transferFrom(recipients[1], recipients[0], uint256(lockedDocument));
  }

  function testTransferFromUnlockedDocumentToZeroRevert() public {
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, address(0)));

    vm.prank(recipients[0]);
    documentStore.transferFrom(recipients[0], address(0), uint256(unlockedDocument));
  }

  function testTransferFromLockedDocumentToZeroRevert() public {
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, address(0)));

    vm.prank(recipients[1]);
    documentStore.transferFrom(recipients[1], address(0), uint256(lockedDocument));
  }
}

contract OwnableDocumentStore_locked_Test is OwnableDocumentStoreCommonTest {
  address public recipient;

  function setUp() public override {
    super.setUp();

    recipient = vm.addr(6969);
  }

  function testLockedWithUnlockedDocument(bytes32 document) public {
    vm.assume(document != bytes32(0));

    vm.prank(issuer);
    documentStore.issue(recipient, document, false);

    bool isLocked = documentStore.locked(uint256(document));
    assertFalse(isLocked, "Document should not be locked");
  }

  function testLockedWithLockedDocument(bytes32 document) public {
    vm.assume(document != bytes32(0));

    vm.prank(issuer);
    documentStore.issue(recipient, document, true);

    bool isLocked = documentStore.locked(uint256(document));
    assertTrue(isLocked, "Document should be locked");
  }

  function testLockedWithZeroDocument() public {
    vm.expectRevert(abi.encodeWithSelector(IOwnableDocumentStoreErrors.ZeroDocument.selector));

    documentStore.locked(uint256(bytes32(0)));
  }
}

contract OwnableDocumentStore_supportsInterface_Test is OwnableDocumentStoreCommonTest {
  function testSupportsInterface() public {
    assertTrue(documentStore.supportsInterface(type(IOwnableDocumentStore).interfaceId));
    assertTrue(documentStore.supportsInterface(type(IDocumentStore).interfaceId));
    assertTrue(documentStore.supportsInterface(type(IERC5192).interfaceId));
    assertTrue(documentStore.supportsInterface(type(IERC721Metadata).interfaceId));
    assertTrue(documentStore.supportsInterface(type(IAccessControl).interfaceId));
  }
}
