// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "ERC721/ERC721.sol";

contract HeartNFT is ERC721 {
    event data(uint256 a);
    bytes32 public constant EIP712DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 public constant CLAIM_TYPEHASH = keccak256("Claim(byte32 infoHash,uint256 tokenId)");
    bytes32 public immutable DOMAIN_SEPARATOR;

    string public constant name = "the Unbreakable Heart";
    string public constant version = "1";
    string public constant symbol = "HEART";
    string public constant baseURI = "ipfs://";
    uint256 public constant price = 0.1 ether;
    address public immutable owner;
    uint256 public isLocked = 1; // 1이라면 전송 가능 2라면 전송 불가
    mapping(uint256 => uint256) public locked;

    constructor(address _owner) {
        owner = _owner;
        DOMAIN_SEPARATOR = hashDomainSeperator(name, version);
    }

    function mint() external payable {
        if (isLocked != 1) revert();

        uint256 current;
        assembly {
            current := sload(Slot_TokenIndex)
        }

        // 총 갯수 체크
        if (current + 1 >= 31) revert();

        // 갯수에 따른 가격 체크
        if (msg.value < price) revert();

        _mint(msg.sender);

        owner.call{value: msg.value}("");
    }

    function mint(uint256 quantity) external payable {
        if (isLocked != 1) revert();

        uint256 current;
        assembly {
            current := sload(Slot_TokenIndex)
        }

        if (current + quantity >= 31) revert();

        if (msg.value < price * quantity) revert();

        _mint(msg.sender, quantity);

        owner.call{value: msg.value}("");
    }

    function claim(bytes32 infoHash, uint256 tokenId, bytes calldata signature) external {
        // 소유자가 아니면 클레임 불가
        if (msg.sender != owner) revert();

        if (signature.length != 65) revert();

        uint8 v;
        bytes32 r;
        bytes32 s;
        address tokenOwner;

        bytes32 Hash = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, keccak256(abi.encode(CLAIM_TYPEHASH, infoHash, tokenId)))
        );

        assembly {
            mstore(0x00, tokenId)
            mstore(0x20, Slot_TokenInfo)
            tokenOwner := and(sload(keccak256(0x00, 0x40)), 0xffffffffffffffffffffffffffffffffffffffff)

            calldatacopy(mload(0x40), signature.offset, 0x20)
            calldatacopy(add(mload(0x40), 0x20), add(signature.offset, 0x20), 0x20)
            calldatacopy(add(mload(0x40), 0x5f), add(signature.offset, 0x40), 0x2)

            // check malleability
            if gt(mload(add(mload(0x40), 0x20)), Signature_s_malleability) {
                mstore(0x0, Error_InvalidSignature_Signature)
                revert(0x0, 0x4)
            }

            r := mload(mload(0x40))
            s := mload(add(mload(0x40), 0x20))
            v := mload(add(mload(0x40), 0x40))
        }

        address recovered = ecrecover(Hash, v, r, s);

        if(recovered != tokenOwner) revert();
        locked[tokenId] = 1;
    }

    function globalLock() external {
        // 소유자가 아니면 글로벌 락 불가
        if (msg.sender != owner) revert();

        // TODO: 최소 기한 보장 KST 기준 시간
        if (block.timestamp < block.timestamp - 1) revert();

        isLocked = 2;
    }

    /**
     * @notice  토큰을 가지고 있는 from 주소로 부터, to 주소에게 토큰을 전송합니다.
     * @param   from    토큰 소유자 주소
     * @param   to      토큰 수신자 주소
     * @param   tokenId 전송할 토큰의 ID
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data)
        external
        payable
        override
    {
        if (isLocked != 1) revert();
        if (locked[tokenId] > 0) revert();
        _safeTransferFrom(from, to, tokenId, data);
    }

    /**
     * @notice  토큰을 가지고 있는 from 주소로 부터, to 주소에게 토큰을 전송합니다.
     * @param   from    토큰 소유자 주소
     * @param   to      토큰 수신자 주소
     * @param   tokenId 전송할 토큰의 ID
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external payable override {
        if (isLocked != 1) revert();
        if (locked[tokenId] > 0) revert();
        _safeTransferFrom(from, to, tokenId);
    }

    /**
     * @notice  토큰을 가지고 있는 from 주소로 부터, to 주소에게 토큰을 전송합니다.
     * @param   from    토큰 소유자 주소
     * @param   to      토큰 수신자 주소
     * @param   tokenId 전송할 토큰의 ID
     */
    function transferFrom(address from, address to, uint256 tokenId) external payable override {
        if (isLocked != 1) revert();
        if (locked[tokenId] > 0) revert();
        _transferFrom(from, to, tokenId);
    }

    function tokenURI(uint256 tokenId) external pure override returns (string memory) {
        return string(abi.encodePacked(baseURI, tokenId, ".json"));
    }

    function totalSupply() external view returns(uint256) {
        assembly {
            mstore(0x0, sload(Slot_TokenIndex))
            return(0x0, 0x20)
        }
    }

    /**
     * @dev     Calculates a EIP712 domain separator.
     * @param   name                EIP712 domain name.
     * @param   version             EIP712 domain version.
     * @return  result              EIP712 domain separator.
     */
    function hashDomainSeperator(string memory name, string memory version) internal view returns (bytes32 result) {
        bytes32 typehash = EIP712DOMAIN_TYPEHASH;

        assembly {
            let nameHash := keccak256(add(name, 0x20), mload(name))
            let versionHash := keccak256(add(version, 0x20), mload(version))

            let memPtr := mload(0x40)

            mstore(memPtr, typehash)
            mstore(add(memPtr, 0x20), nameHash)
            mstore(add(memPtr, 0x40), versionHash)
            mstore(add(memPtr, 0x60), chainid())
            mstore(add(memPtr, 0x80), address())

            result := keccak256(memPtr, 0xa0)
        }
    }
}
