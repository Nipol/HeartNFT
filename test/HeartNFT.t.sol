// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/HeartNFT.sol";

contract HeartNFTTest is Test {
    HeartNFT nft;
    address public alice = Address("alice");
    address public bob = Address("bob");
    address public charlie = Address("charlie");

    function setUp() public {
        nft = new HeartNFT(alice);
        bob.call{value: 3 ether}("");
        address(0x22310Bf73bC88ae2D2c9a29Bd87bC38FBAc9e6b0).call{value: 3 ether}("");
        charlie.call{value: 3 ether}("");
    }

    function testOwner() public {
        assertEq(nft.owner(), alice);
    }

    function testMint() public {
        vm.prank(bob);
        nft.mint{value: 0.1 ether}();
        assertEq(nft.ownerOf(0), bob);
        assertEq(alice.balance, 0.1 ether);
    }

    function testMintWithLeastEther() public {
        vm.expectRevert();
        vm.prank(bob);
        nft.mint{value: 0.099 ether}();
        assertEq(nft.ownerOf(0), address(0));
        assertEq(alice.balance, 0);
    }

    function testBulkMint() public {
        vm.prank(bob);
        nft.mint{value: 1 ether}(10);
        for (uint i; i < 10; i++) {
            assertEq(nft.ownerOf(i), bob);
        }
        assertEq(nft.ownerOf(10), address(0));
        assertEq(alice.balance, 1 ether);
    }

    function testOverMint() public {
        vm.prank(bob);
        nft.mint{value: 3 ether}(30);
        assertEq(nft.ownerOf(30), address(0));
        assertEq(nft.balanceOf(bob), 30);
        assertEq(alice.balance, 3 ether);

        vm.expectRevert();
        vm.prank(charlie);
        nft.mint{value: 0.1 ether}();

        vm.expectRevert();
        vm.prank(charlie);
        nft.mint{value: 0.1 ether}(1);

        vm.expectRevert();
        vm.prank(charlie);
        nft.mint{value: 0.2 ether}(2);
    }

    function testBulkMintWithLeastEther() public {
        vm.expectRevert();
        vm.prank(bob);
        nft.mint{value: 0.9999 ether}(10);
        for (uint i; i < 10; i++) {
            assertEq(nft.ownerOf(i), address(0));
        }
        assertEq(alice.balance, 0);
    }

    function testClaim() public {
        bytes32 domain = nft.DOMAIN_SEPARATOR();
        bytes32 claimtype = nft.CLAIM_TYPEHASH();
        uint256 tokenId = 0;

        vm.prank(0x22310Bf73bC88ae2D2c9a29Bd87bC38FBAc9e6b0);
        nft.mint{value: 0.1 ether}();

        assertEq(alice.balance, 0.1 ether);

        bytes32 infoHash = keccak256(abi.encode("PeRSonAl InFORmAtIOn"));

        bytes32 Hash = keccak256(
            abi.encodePacked("\x19\x01", domain, keccak256(abi.encode(claimtype, infoHash, tokenId)))
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0x7c299dda7c704f9d474b6ca5d7fee0b490c8decca493b5764541fe5ec6b65114, Hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(alice);
        nft.claim(infoHash, 0, signature);

        assertEq(nft.locked(tokenId), 1);

        vm.expectRevert();
        vm.prank(0x22310Bf73bC88ae2D2c9a29Bd87bC38FBAc9e6b0);
        nft.safeTransferFrom(0x22310Bf73bC88ae2D2c9a29Bd87bC38FBAc9e6b0, alice, tokenId, "");

        vm.expectRevert();
        vm.prank(0x22310Bf73bC88ae2D2c9a29Bd87bC38FBAc9e6b0);
        nft.safeTransferFrom(0x22310Bf73bC88ae2D2c9a29Bd87bC38FBAc9e6b0, alice, tokenId);

        vm.expectRevert();
        vm.prank(0x22310Bf73bC88ae2D2c9a29Bd87bC38FBAc9e6b0);
        nft.transferFrom(0x22310Bf73bC88ae2D2c9a29Bd87bC38FBAc9e6b0, alice, tokenId);
    }

    function testGlobalLock() public {
        vm.prank(bob);
        nft.mint{value: 0.1 ether}();
        assertEq(alice.balance, 0.1 ether);

        vm.prank(alice);
        nft.globalLock();

        vm.expectRevert();
        vm.prank(bob);
        nft.safeTransferFrom(bob, alice, 0, "");

        vm.expectRevert();
        vm.prank(bob);
        nft.safeTransferFrom(bob, alice, 0);

        vm.expectRevert();
        vm.prank(bob);
        nft.transferFrom(bob, alice, 0);
    }

    function testGlobalLockNotFromOwner() public {
        vm.prank(bob);
        nft.mint{value: 0.1 ether}();
        assertEq(alice.balance, 0.1 ether);

        vm.expectRevert();
        vm.prank(bob);
        nft.globalLock();

        vm.prank(bob);
        nft.transferFrom(bob, alice, 0);
    }

    function Address(string memory name) internal returns (address ret) {
        ret = address(uint160(uint256(keccak256(abi.encode(name)))));
        vm.label(ret, name);
    }
}
