// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../lib/chainlink/contracts-ccip/src/v0.8/CCIPReceiver.sol";
import "../lib/chainlink/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";
import "../lib/chainlink/contracts-ccip/src/v0.8/libraries/Client.sol";
contract CCIPMessageReceiver is CCIPReceiver, OwnerIsCreator {
    // Enums and structs matching DezenMartLogistics
    enum MessageType {
        CREATE_TRADE,
        BUY_TRADE,
        CONFIRM_DELIVERY,
        CONFIRM_PURCHASE,
        RAISE_DISPUTE,
        CANCEL_PURCHASE,
        SETTLE_PAYMENT
    }

    struct CrossChainMessage {
        MessageType messageType;
        bytes data;
        address sender;
    }

    struct Trade {
        address seller;
        address[] logisticsProviders;
        uint64[] logisticsChainSelectors;
        uint256[] logisticsCosts;
        uint256 productCost;
        uint256 escrowFee;
        uint256 totalQuantity;
        uint256 remainingQuantity;
        bool active;
        uint64 sourceChain;
        uint64 sellerChainSelector;
    }

    // Constants
    uint256 public constant ESCROW_FEE_PERCENT = 250; // 2.5% (in basis points)
    uint256 public constant BASIS_POINTS = 10000;

    // State
    mapping(bytes32 => CrossChainMessage) public receivedMessages;
    mapping(uint64 => bool) public allowlistedSourceChains;
    mapping(uint256 => Trade) public trades;
    uint256 public tradeCounter;
    mapping(address => uint256[]) public sellerTradeIds;
    mapping(uint256 => uint64) public tradeSourceChain;

    // Events
    event MessageReceived(
        bytes32 indexed messageId,
        uint64 indexed sourceChainSelector,
        address sender,
        MessageType messageType,
        bytes data
    );
    event TradeCreated(
        uint256 indexed tradeId,
        address indexed seller,
        uint256 productCost,
        uint256 totalQuantity,
        uint64 sourceChain
    );

    // Errors
    error SourceChainNotAllowlisted(uint64 sourceChainSelector);
    error MessageAlreadyProcessed(bytes32 messageId);
    error InvalidQuantity(uint256 quantity);
    error MismatchedArrays(uint256 providersLength, uint256 costsLength);
    error NoLogisticsProviders();

    constructor(address _router) CCIPReceiver(_router) {
        if (_router == address(0)) revert InvalidRouter(_router);
    }

    // Allowlist management
    function allowlistSourceChain(uint64 sourceChainSelector, bool allowed) external onlyOwner {
        allowlistedSourceChains[sourceChainSelector] = allowed;
    }

    // Receive CCIP messages
    function _ccipReceive(Client.Any2EVMMessage memory any2EvmMessage) internal override {
        bytes32 messageId = any2EvmMessage.messageId;
        uint64 sourceChainSelector = any2EvmMessage.sourceChainSelector;

        // Check allowlist and message uniqueness
        if (!allowlistedSourceChains[sourceChainSelector]) {
            revert SourceChainNotAllowlisted(sourceChainSelector);
        }
        if (receivedMessages[messageId].sender != address(0)) {
            revert MessageAlreadyProcessed(messageId);
        }

        // Decode message
        CrossChainMessage memory message = abi.decode(any2EvmMessage.data, (CrossChainMessage));

        // Store message
        receivedMessages[messageId] = message;

        // Process message
        if (message.messageType == MessageType.CREATE_TRADE) {
            _processCrossChainTradeCreation(message.data, message.sender, sourceChainSelector);
        }
        // Add other message types (e.g., BUY_TRADE) as needed

        // Emit event
        emit MessageReceived(
            messageId,
            sourceChainSelector,
            message.sender,
            message.messageType,
            message.data
        );
    }

    // Process CREATE_TRADE message
    function _processCrossChainTradeCreation(
        bytes memory data,
        address sender,
        uint64 sourceChainSelector
    ) internal {
        (
            uint256 productCost,
            address[] memory logisticsProvidersList,
            uint64[] memory logisticsChainSelectors,
            uint256[] memory logisticsCosts,
            uint256 totalQuantity,
            uint64 sellerChainSelector
        ) = abi.decode(data, (uint256, address[], uint64[], uint256[], uint256, uint64));

        // Validate inputs
        if (totalQuantity == 0) revert InvalidQuantity(totalQuantity);
        if (
            logisticsProvidersList.length != logisticsCosts.length ||
            logisticsProvidersList.length != logisticsChainSelectors.length
        ) {
            revert MismatchedArrays(logisticsProvidersList.length, logisticsCosts.length);
        }
        if (logisticsProvidersList.length == 0) revert NoLogisticsProviders();

        // Create trade
        uint256 productEscrowFee = (productCost * ESCROW_FEE_PERCENT) / BASIS_POINTS;
        tradeCounter++;
        uint256 tradeId = tradeCounter;

        trades[tradeId] = Trade({
            seller: sender,
            logisticsProviders: logisticsProvidersList,
            logisticsChainSelectors: logisticsChainSelectors,
            logisticsCosts: logisticsCosts,
            productCost: productCost,
            escrowFee: productEscrowFee,
            totalQuantity: totalQuantity,
            remainingQuantity: totalQuantity,
            active: true,
            sourceChain: sourceChainSelector,
            sellerChainSelector: sellerChainSelector
        });

        tradeSourceChain[tradeId] = sourceChainSelector;
        sellerTradeIds[sender].push(tradeId);

        emit TradeCreated(tradeId, sender, productCost, totalQuantity, sourceChainSelector);
    }

    // View function to retrieve message details
    function getMessage(bytes32 messageId)
        external
        view
        returns (MessageType messageType, bytes memory data, address sender)
    {
        CrossChainMessage memory message = receivedMessages[messageId];
        return (message.messageType, message.data, message.sender);
    }

    // View function to retrieve trade details
    function getTrade(uint256 tradeId)
        external
        view
        returns (
            address seller,
            uint256 productCost,
            uint256 totalQuantity,
            uint64 sourceChain
        )
    {
        Trade memory trade = trades[tradeId];
        return (trade.seller, trade.productCost, trade.totalQuantity, trade.sourceChain);
    }
}