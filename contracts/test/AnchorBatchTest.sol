// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../interfaces/IAnchor.sol";

/**
 * @title AnchorBatchTest
 * @notice Test contract to show separate gas costs for different batch sizes
 * @dev Only for testing - wraps anchor calls with specific batch sizes
 */
contract AnchorBatchTest {
    IAnchor public immutable anchor;
    
    constructor(address _anchor) {
        anchor = IAnchor(_anchor);
    }
    
    function anchor001() external {
        IAnchor.Anchor[] memory anchors = new IAnchor.Anchor[](1);
        anchors[0] = IAnchor.Anchor({
            key: bytes32(uint256(1)),
            value: bytes32(uint256(2))
        });
        anchor.anchor(anchors);
    }
    
    function anchor010() external {
        IAnchor.Anchor[] memory anchors = new IAnchor.Anchor[](10);
        for (uint i = 0; i < 10; i++) {
            anchors[i] = IAnchor.Anchor({
                key: bytes32(uint256(i)),
                value: bytes32(uint256(i + 100))
            });
        }
        anchor.anchor(anchors);
    }
    
    function anchor050() external {
        IAnchor.Anchor[] memory anchors = new IAnchor.Anchor[](50);
        for (uint i = 0; i < 50; i++) {
            anchors[i] = IAnchor.Anchor({
                key: bytes32(uint256(i)),
                value: bytes32(uint256(i + 1000))
            });
        }
        anchor.anchor(anchors);
    }
    
    function anchor100() external {
        IAnchor.Anchor[] memory anchors = new IAnchor.Anchor[](100);
        for (uint i = 0; i < 100; i++) {
            anchors[i] = IAnchor.Anchor({
                key: bytes32(uint256(i)),
                value: bytes32(uint256(i + 10000))
            });
        }
        anchor.anchor(anchors);
    }
}