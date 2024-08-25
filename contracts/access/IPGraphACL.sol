// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

contract IPGraphACL {
    uint256 public length = 0;

    function addWhitelistAddress(address addr) external {
        length++;
        uint256 slot = length;
        assembly {
            sstore(slot, addr)
        }
    }

    function revokeWhitelistAddress(uint256 index) external {
        require(index > 0 && index <= length, "IPGraphACL: index out of bounds");
        uint256 slot = index;
        assembly {
            sstore(slot, 0)
        }
    }

    function getWhitelistAddress(uint256 index) external view returns (address) {
        require(index <= length, "IPGraphACL: index out of bounds");
        address addr;
        uint256 slot = index + 1;
        assembly {
            addr := sload(slot)
        }
        return addr;
    }

    function getWhitelistLength() external view returns (uint256) {
        return length;
    }

    function isWhitelisted(address addr) external view returns (bool) {
        for (uint256 i = 1; i <= length; i++) {
            address whitelistAddr;
            assembly {
                whitelistAddr := sload(i)
            }
            if (whitelistAddr == addr) {
                return true;
            }
        }
        return false;
    }
}
