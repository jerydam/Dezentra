// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../lib/chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import "../lib/chainlink/contracts-ccip/src/v0.8/interfaces/IRouterClient.sol";
import "../lib/chainlink/contracts-ccip/src/v0.8/libraries/Client.sol";
import "../lib/chainlink/contracts-ccip/src/v0.8/CCIPReceiver.sol";
import "../lib/chainlink/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract DezentraLogistics is CCIPReceiver, OwnerIsCreator {
    using SafeERC20 for IERC20;

    uint256 public constant ESCROW_FEE_PERCENT = 250;
    uint256 public constant BASIS_POINTS = 10000;

    enum PayFeesIn { Native, LINK }
    
    address immutable i_link;
    address immutable i_usdt;
    mapping(uint64 => bool) public allowlistedSourceChains;
    uint64[] public allowlistedChains; // New array for all allowlisted chains

    mapping(address => bool) public logisticsProviders;
    mapping(address => bool) public sellers;
    mapping(address => bool) public buyers;
    address[] public registeredProviders;

    mapping(bytes32 => bool) public processedMessages;
    mapping(uint256 => uint64) public purchaseSourceChain;

    struct Purchase {
        uint256 purchaseId;
        uint256 tradeId;
        address buyer;
        uint256 quantity;
        uint256 totalAmount;
        address buyerToken;
        uint256 buyerTokenAmount;
        bool delivered;
        bool confirmed;
        bool disputed;
        address chosenLogisticsProvider;
        uint256 logisticsCost;
        uint64 sourceChain;
    }

    struct Trade {
        address seller;
        address[] logisticsProviders;
        uint256[] logisticsCosts;
        uint256 productCost;
        uint256 escrowFee;
        uint256 totalQuantity;
        uint256 remainingQuantity;
        bool active;
        uint256[] purchaseIds;
    }

    struct BuyTradeParams {
        address buyer;
        uint256 tradeId;
        uint256 quantity;
        address logisticsProvider;
        uint256 totalAmountInUSDT;
        address buyerToken;
        uint256 buyerTokenAmount;
        uint64 sourceChain;
    }

    enum MessageType {
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

    mapping(uint256 => Trade) public trades;
    mapping(uint256 => Purchase) public purchases;
    uint256 public tradeCounter;
    uint256 public purchaseCounter;
    mapping(uint256 => bool) public disputesResolved;
    mapping(address => uint256[]) public buyerPurchaseIds;
    mapping(address => uint256[]) public sellerTradeIds;
    mapping(address => uint256[]) public providerTradeIds;

    event MessageSent(bytes32 indexed messageId, uint64 indexed destinationChainSelector, address receiver, MessageType messageType, uint256 fees);
    event MessageReceived(bytes32 indexed messageId, uint64 indexed sourceChainSelector, address sender, MessageType messageType);
    event TradeCreated(uint256 indexed tradeId, address indexed seller, uint256 productCost, uint256 totalQuantity);
    event PurchaseCreated(uint256 indexed purchaseId, uint256 indexed tradeId, address indexed buyer, uint256 quantity, address buyerToken, uint256 buyerTokenAmount, uint64 sourceChain);
    event LogisticsSelected(uint256 indexed purchaseId, address logisticsProvider, uint256 logisticsCost);
    event PaymentHeld(uint256 indexed purchaseId, uint256 totalAmount, address buyerToken, uint256 buyerTokenAmount);
    event DeliveryConfirmed(uint256 indexed purchaseId);
    event PurchaseConfirmed(uint256 indexed purchaseId);
    event PaymentSettled(uint256 indexed purchaseId, uint256 sellerAmount, uint256 logisticsAmount);
    event DisputeRaised(uint256 indexed purchaseId, address initiator);
    event DisputeResolved(uint256 indexed purchaseId, address winner);
    event LogisticsProviderRegistered(address indexed provider);
    event PurchaseCancelled(uint256 indexed purchaseId);
    event SourceChainAllowlisted(uint64 indexed chainSelector, bool allowed);

    error InsufficientTokenAllowance(uint256 needed, uint256 allowance);
    error InsufficientTokenBalance(uint256 needed, uint256 balance);
    error InvalidTradeId(uint256 tradeId);
    error InvalidPurchaseId(uint256 purchaseId);
    error BuyerIsSeller();
    error InsufficientQuantity(uint256 requested, uint256 available);
    error InvalidQuantity(uint256 quantity);
    error InvalidLogisticsProvider(address provider);
    error MismatchedArrays(uint256 providersLength, uint256 costsLength);
    error NoLogisticsProviders();
    error TradeNotFound(uint256 tradeId);
    error PurchaseNotFound(uint256 purchaseId);
    error NotAuthorized(address caller, string role);
    error InvalidTradeState(uint256 tradeId, string expectedState);
    error InvalidPurchaseState(uint256 purchaseId, string expectedState);
    error SourceChainNotAllowlisted(uint64 sourceChainSelector);
    error MessageAlreadyProcessed(bytes32 messageId);
    error InsufficientFeeTokenAmount();
    error InvalidToken(address token);

    modifier onlyPurchaseParticipant(uint256 purchaseId) {
        Purchase memory purchase = purchases[purchaseId];
        Trade memory trade = trades[purchase.tradeId];
        bool isParticipant = msg.sender == purchase.buyer || msg.sender == trade.seller;
        isParticipant = isParticipant || msg.sender == purchase.chosenLogisticsProvider;
        require(isParticipant, "Not a purchase participant");
        _;
    }

    modifier onlyAllowlistedSourceChain(uint64 _sourceChainSelector) {
        if (!allowlistedSourceChains[_sourceChainSelector])
            revert SourceChainNotAllowlisted(_sourceChainSelector);
        _;
    }

    constructor(address _router, address _link, address _usdtAddress) CCIPReceiver(_router) OwnerIsCreator() {
        if (_router == address(0)) revert InvalidRouter(_router);
        require(_usdtAddress != address(0), "Invalid USDT address");
        require(_link != address(0), "Invalid LINK address");
        
        i_link = _link;
        i_usdt = _usdtAddress;
    }

    receive() external payable {}

    function allowlistSourceChain(uint64 _sourceChainSelector, bool allowed) external onlyOwner {
        if (allowlistedSourceChains[_sourceChainSelector] != allowed) {
            allowlistedSourceChains[_sourceChainSelector] = allowed;
            if (allowed) {
                allowlistedChains.push(_sourceChainSelector);
            } else {
                for (uint256 i = 0; i < allowlistedChains.length; i++) {
                    if (allowlistedChains[i] == _sourceChainSelector) {
                        allowlistedChains[i] = allowlistedChains[allowlistedChains.length - 1];
                        allowlistedChains.pop();
                        break;
                    }
                }
            }
            emit SourceChainAllowlisted(_sourceChainSelector, allowed);
        }
    }

    function getAllowlistedChains() external view returns (uint64[] memory) {
        return allowlistedChains;
    }

    function buyCrossChainTrade(
        uint64 destinationChainSelector,
        address destinationContract,
        uint256 tradeId,
        uint256 quantity,
        address logisticsProvider,
        address buyerToken,
        uint256 buyerTokenAmount,
        uint256 totalAmountInUSDT,
        PayFeesIn payFeesIn
    ) external returns (bytes32 messageId) {
        if (buyerToken == address(0)) revert InvalidToken(buyerToken);
        _validateAndTransferToken(buyerToken, buyerTokenAmount);

        bytes memory data = abi.encode(
            tradeId,
            quantity,
            logisticsProvider,
            buyerToken,
            buyerTokenAmount,
            totalAmountInUSDT
        );
        return _sendCCIPMessage(destinationChainSelector, destinationContract, MessageType.BUY_TRADE, data, buyerToken, buyerTokenAmount, payFeesIn);
    }

    function buyTrade(
        uint256 tradeId,
        uint256 quantity,
        address logisticsProvider,
        address buyerToken,
        uint256 buyerTokenAmount,
        uint256 totalAmountInUSDT
    ) external returns (uint256) {
        registerBuyer();
        Trade storage trade = trades[tradeId];
        uint256 chosenLogisticsCost = _findLogisticsCost(trade, logisticsProvider);
        (, uint256 totalAmount) = _calculateTradeCosts(trade, quantity, chosenLogisticsCost);
        require(totalAmountInUSDT >= totalAmount, "Insufficient payment amount");

        _validateAndTransferToken(buyerToken, buyerTokenAmount);

        BuyTradeParams memory params = BuyTradeParams({
            buyer: msg.sender,
            tradeId: tradeId,
            quantity: quantity,
            logisticsProvider: logisticsProvider,
            totalAmountInUSDT: totalAmountInUSDT,
            buyerToken: buyerToken,
            buyerTokenAmount: buyerTokenAmount,
            sourceChain: 0
        });

        uint256 purchaseId = _buyTradeInternal(params);
        emit PurchaseCreated(purchaseId, tradeId, msg.sender, quantity, buyerToken, buyerTokenAmount, 0);
        emit PaymentHeld(purchaseId, totalAmountInUSDT, buyerToken, buyerTokenAmount);
        return purchaseId;
    }

    function _processCrossChainPurchase(
        bytes memory data,
        address sender,
        uint64 sourceChainSelector,
        Client.EVMTokenAmount[] memory tokenAmounts
    ) internal {
        (
            uint256 tradeId,
            uint256 quantity,
            address logisticsProvider,
            address buyerToken,
            uint256 buyerTokenAmount,
            uint256 totalAmountInUSDT
        ) = abi.decode(data, (uint256, uint256, address, address, uint256, uint256));
        
        uint256 receivedAmount = tokenAmounts.length > 0 ? tokenAmounts[0].amount : 0;
        if (receivedAmount != buyerTokenAmount || tokenAmounts[0].token != buyerToken) revert("Token amount mismatch");

        BuyTradeParams memory params = BuyTradeParams({
            buyer: sender,
            tradeId: tradeId,
            quantity: quantity,
            logisticsProvider: logisticsProvider,
            totalAmountInUSDT: totalAmountInUSDT,
            buyerToken: buyerToken,
            buyerTokenAmount: buyerTokenAmount,
            sourceChain: sourceChainSelector
        });

        uint256 purchaseId = _buyTradeInternal(params);
        emit PurchaseCreated(purchaseId, tradeId, sender, quantity, buyerToken, buyerTokenAmount, sourceChainSelector);
        emit PaymentHeld(purchaseId, totalAmountInUSDT, buyerToken, buyerTokenAmount);
    }

    function _initializePurchase(
        uint256 purchaseId,
        BuyTradeParams memory params,
        uint256 chosenLogisticsCost
    ) internal {
        Purchase storage purchase = purchases[purchaseId];
        purchase.purchaseId = purchaseId;
        purchase.tradeId = params.tradeId;
        purchase.buyer = params.buyer;
        purchase.quantity = params.quantity;
        purchase.totalAmount = params.totalAmountInUSDT;
        purchase.buyerToken = params.buyerToken;
        purchase.buyerTokenAmount = params.buyerTokenAmount;
        purchase.delivered = false;
        purchase.confirmed = false;
        purchase.disputed = false;
        purchase.chosenLogisticsProvider = params.logisticsProvider;
        purchase.logisticsCost = chosenLogisticsCost * params.quantity;
        purchase.sourceChain = params.sourceChain;
    }

    function _buyTradeInternal(BuyTradeParams memory params) internal returns (uint256) {
        Trade storage trade = trades[params.tradeId];
        if (!trade.active) revert InvalidTradeId(params.tradeId);
        if (trade.remainingQuantity < params.quantity) revert InsufficientQuantity(params.quantity, trade.remainingQuantity);
        if (params.quantity == 0) revert InvalidQuantity(params.quantity);

        uint256 chosenLogisticsCost = _findLogisticsCost(trade, params.logisticsProvider);
        (, uint256 expectedTotalAmount) = _calculateTradeCosts(trade, params.quantity, chosenLogisticsCost);
        require(params.totalAmountInUSDT >= expectedTotalAmount, "Insufficient payment amount");

        purchaseCounter++;
        uint256 purchaseId = purchaseCounter;

        _initializePurchase(purchaseId, params, chosenLogisticsCost);

        trade.purchaseIds.push(purchaseId);
        trade.remainingQuantity -= params.quantity;
        buyerPurchaseIds[params.buyer].push(purchaseId);
        providerTradeIds[params.logisticsProvider].push(purchaseId);
        purchaseSourceChain[purchaseId] = params.sourceChain;
        buyers[params.buyer] = true;

        return purchaseId;
    }

    function _sendCCIPMessage(
        uint64 destinationChainSelector,
        address receiver,
        MessageType messageType,
        bytes memory data,
        address tokenToSend,
        uint256 tokenAmount,
        PayFeesIn payFeesIn
    ) internal returns (bytes32 messageId) {
        CrossChainMessage memory message = CrossChainMessage({
            messageType: messageType,
            data: data,
            sender: msg.sender
        });

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](0);
        if (tokenToSend != address(0) && tokenAmount > 0) {
            tokenAmounts = new Client.EVMTokenAmount[](1);
            tokenAmounts[0] = Client.EVMTokenAmount({token: tokenToSend, amount: tokenAmount});
            IERC20(tokenToSend).safeTransferFrom(msg.sender, address(this), tokenAmount);
            IERC20(tokenToSend).approve(this.getRouter(), tokenAmount);
        }

        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: abi.encode(message),
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(Client.GenericExtraArgsV2({gasLimit: 200_000, allowOutOfOrderExecution: true})),
            feeToken: payFeesIn == PayFeesIn.LINK ? i_link : address(0)
        });

        IRouterClient router = IRouterClient(this.getRouter());
        uint256 fees = router.getFee(destinationChainSelector, evm2AnyMessage);

        if (payFeesIn == PayFeesIn.LINK) {
            if (IERC20(i_link).balanceOf(address(this)) < fees) revert InsufficientFeeTokenAmount();
            IERC20(i_link).approve(address(router), fees);
            messageId = router.ccipSend(destinationChainSelector, evm2AnyMessage);
        } else {
            if (address(this).balance < fees) revert InsufficientFeeTokenAmount();
            messageId = router.ccipSend{value: fees}(destinationChainSelector, evm2AnyMessage);
        }

        emit MessageSent(messageId, destinationChainSelector, receiver, messageType, fees);
        return messageId;
    }

    function _ccipReceive(Client.Any2EVMMessage memory any2EvmMessage) internal override onlyAllowlistedSourceChain(any2EvmMessage.sourceChainSelector) {
        bytes32 messageId = any2EvmMessage.messageId;
        if (processedMessages[messageId]) revert MessageAlreadyProcessed(messageId);
        processedMessages[messageId] = true;

        CrossChainMessage memory message = abi.decode(any2EvmMessage.data, (CrossChainMessage));
        
        emit MessageReceived(messageId, any2EvmMessage.sourceChainSelector, message.sender, message.messageType);

        if (message.messageType == MessageType.BUY_TRADE) {
            _processCrossChainPurchase(message.data, message.sender, any2EvmMessage.sourceChainSelector, any2EvmMessage.destTokenAmounts);
        } else if (message.messageType == MessageType.CONFIRM_DELIVERY) {
            _processCrossChainDeliveryConfirmation(message.data, message.sender);
        } else if (message.messageType == MessageType.CONFIRM_PURCHASE) {
            _processCrossChainPurchaseConfirmation(message.data, message.sender);
        } else if (message.messageType == MessageType.RAISE_DISPUTE) {
            _processCrossChainDispute(message.data, message.sender);
        } else if (message.messageType == MessageType.CANCEL_PURCHASE) {
            _processCrossChainCancellation(message.data, message.sender);
        } else if (message.messageType == MessageType.SETTLE_PAYMENT) {
            _processCrossChainPayment(message.data, any2EvmMessage.destTokenAmounts);
        }
    }

    function _sendCrossChainPayment(
        uint64 destinationChainSelector,
        address receiver,
        uint256 amount,
        uint256 purchaseId,
        PayFeesIn payFeesIn
    ) internal returns (bytes32 messageId) {
        bytes memory data = abi.encode(purchaseId, amount);
        return _sendCCIPMessage(destinationChainSelector, receiver, MessageType.SETTLE_PAYMENT, data, i_usdt, amount, payFeesIn);
    }

    function _processCrossChainPayment(bytes memory data, Client.EVMTokenAmount[] memory tokenAmounts) internal view {
        ( , uint256 amount) = abi.decode(data, (uint256, uint256));
        if (tokenAmounts.length > 0 && tokenAmounts[0].amount == amount && tokenAmounts[0].token == i_usdt) {
            // USDT received
        }
    }

    function createTrade(
        uint256 productCost,
        address[] memory logisticsProvidersList,
        uint256[] memory logisticsCosts,
        uint256 totalQuantity
    ) external returns (uint256) {
        registerSeller();
        if (totalQuantity == 0) revert InvalidQuantity(totalQuantity);
        if (logisticsProvidersList.length != logisticsCosts.length) 
            revert MismatchedArrays(logisticsProvidersList.length, logisticsCosts.length);
        if (logisticsProvidersList.length == 0) revert NoLogisticsProviders();

        uint256 productEscrowFee = (productCost * ESCROW_FEE_PERCENT) / BASIS_POINTS;

        tradeCounter++;
        uint256 tradeId = tradeCounter;

        trades[tradeId] = Trade({
            seller: msg.sender,
            logisticsProviders: logisticsProvidersList,
            logisticsCosts: logisticsCosts,
            productCost: productCost,
            escrowFee: productEscrowFee,
            totalQuantity: totalQuantity,
            remainingQuantity: totalQuantity,
            active: true,
            purchaseIds: new uint256[](0)
        });

        sellerTradeIds[msg.sender].push(tradeId);
        sellers[msg.sender] = true;

        emit TradeCreated(tradeId, msg.sender, productCost, totalQuantity);
        return tradeId;
    }

    function _settlePayments(uint256 purchaseId) internal {
        Purchase storage purchase = purchases[purchaseId];
        Trade storage trade = trades[purchase.tradeId];
        if (!purchase.confirmed) revert InvalidPurchaseState(purchaseId, "confirmed");

        uint256 productEscrowFee = (trade.productCost * ESCROW_FEE_PERCENT * purchase.quantity) / BASIS_POINTS;
        uint256 sellerAmount = (trade.productCost * purchase.quantity) - productEscrowFee;

        require(IERC20(i_usdt).transfer(trade.seller, sellerAmount), "USDT transfer to seller failed");

        uint256 logisticsAmount = 0;
        if (purchase.chosenLogisticsProvider != address(0)) {
            uint256 logisticsEscrowFee = (purchase.logisticsCost * ESCROW_FEE_PERCENT) / BASIS_POINTS;
            logisticsAmount = purchase.logisticsCost - logisticsEscrowFee;
            require(IERC20(i_usdt).transfer(purchase.chosenLogisticsProvider, logisticsAmount), "USDT transfer to logistics failed");
        }

        emit PaymentSettled(purchaseId, sellerAmount, logisticsAmount);
    }

    function _validateAndTransferToken(address token, uint256 amount) internal {
        if (token == address(0)) revert InvalidToken(token);
        uint256 allowance = IERC20(token).allowance(msg.sender, address(this));
        if (allowance < amount) revert InsufficientTokenAllowance(amount, allowance);
        uint256 balance = IERC20(token).balanceOf(msg.sender);
        if (balance < amount) revert InsufficientTokenBalance(amount, balance);
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    }

    function _findLogisticsCost(Trade storage trade, address logisticsProvider) internal view returns (uint256) {
        for (uint256 i = 0; i < trade.logisticsProviders.length; i++) {
            if (trade.logisticsProviders[i] == logisticsProvider) {
                return trade.logisticsCosts[i];
            }
        }
        revert InvalidLogisticsProvider(logisticsProvider);
    }

    function _calculateTradeCosts(Trade storage trade, uint256 quantity, uint256 chosenLogisticsCost)
        internal view returns (uint256 totalLogisticsCost, uint256 totalAmount) {
        uint256 totalProductCost = trade.productCost * quantity;
        totalLogisticsCost = chosenLogisticsCost * quantity;
        totalAmount = totalProductCost + totalLogisticsCost;
    }

    function registerLogisticsProvider(address provider) external {
        require(provider != address(0), "Invalid provider address");
        require(!logisticsProviders[provider], "Provider already registered");
        logisticsProviders[provider] = true;
        registeredProviders.push(provider);
        emit LogisticsProviderRegistered(provider);
    }

    function registerBuyer() public {
        buyers[msg.sender] = true;
    }

    function registerSeller() public {
        sellers[msg.sender] = true;
    }

    function confirmDelivery(uint256 purchaseId) external {
        _confirmDeliveryInternal(purchaseId, msg.sender);
    }

    function confirmPurchase(uint256 purchaseId) external {
        _confirmPurchaseInternal(purchaseId, msg.sender);
    }

    function _confirmDeliveryInternal(uint256 purchaseId, address sender) internal {
        Purchase storage purchase = purchases[purchaseId];
        if (purchase.tradeId == 0) revert PurchaseNotFound(purchaseId);
        if (sender != purchase.buyer) revert NotAuthorized(sender, "buyer");
        if (purchase.delivered) revert InvalidPurchaseState(purchaseId, "not delivered");
        if (purchase.disputed) revert InvalidPurchaseState(purchaseId, "not disputed");
        if (purchase.confirmed) revert InvalidPurchaseState(purchaseId, "not confirmed");

        purchase.delivered = true;
        emit DeliveryConfirmed(purchaseId);
    }

    function _confirmPurchaseInternal(uint256 purchaseId, address sender) internal {
        Purchase storage purchase = purchases[purchaseId];
        if (purchase.tradeId == 0) revert PurchaseNotFound(purchaseId);
        if (sender != purchase.buyer) revert NotAuthorized(sender, "buyer");
        if (!purchase.delivered) revert InvalidPurchaseState(purchaseId, "delivered");
        if (purchase.disputed) revert InvalidPurchaseState(purchaseId, "not disputed");
        if (purchase.confirmed) revert InvalidPurchaseState(purchaseId, "not confirmed");

        purchase.confirmed = true;
        emit PurchaseConfirmed(purchaseId);
        _settlePayments(purchaseId);
    }

    function raiseCrossChainDispute(uint64 destinationChainSelector, address destinationContract, uint256 purchaseId, PayFeesIn payFeesIn) external returns (bytes32 messageId) {
        bytes memory data = abi.encode(purchaseId);
        return _sendCCIPMessage(destinationChainSelector, destinationContract, MessageType.RAISE_DISPUTE, data, address(0), 0, payFeesIn);
    }

    function _processCrossChainDispute(bytes memory data, address sender) internal {
        uint256 purchaseId = abi.decode(data, (uint256));
        Purchase storage purchase = purchases[purchaseId];
        Trade storage trade = trades[purchase.tradeId];
        bool isParticipant = sender == purchase.buyer || sender == trade.seller || sender == purchase.chosenLogisticsProvider;
        require(isParticipant, "Not a purchase participant");
        if (purchase.tradeId == 0) revert PurchaseNotFound(purchaseId);
        if (purchase.confirmed) revert InvalidPurchaseState(purchaseId, "not confirmed");
        if (purchase.disputed) revert InvalidPurchaseState(purchaseId, "not disputed");

        purchase.disputed = true;
        emit DisputeRaised(purchaseId, sender);
    }

    function cancelCrossChainPurchase(uint64 destinationChainSelector, address destinationContract, uint256 purchaseId, PayFeesIn payFeesIn) external returns (bytes32 messageId) {
        bytes memory data = abi.encode(purchaseId);
        return _sendCCIPMessage(destinationChainSelector, destinationContract, MessageType.CANCEL_PURCHASE, data, address(0), 0, payFeesIn);
    }

    function _processCrossChainCancellation(bytes memory data, address sender) internal {
        uint256 purchaseId = abi.decode(data, (uint256));
        Purchase storage purchase = purchases[purchaseId];
        Trade storage trade = trades[purchase.tradeId];
        if (purchase.tradeId == 0) revert PurchaseNotFound(purchaseId);
        if (sender != purchase.buyer) revert NotAuthorized(sender, "buyer");
        if (purchase.delivered) revert InvalidPurchaseState(purchaseId, "not delivered");
        if (purchase.disputed) revert InvalidPurchaseState(purchaseId, "not disputed");
        if (purchase.confirmed) revert InvalidPurchaseState(purchaseId, "not confirmed");

        purchase.confirmed = true;
        trade.remainingQuantity += purchase.quantity;
        if (purchase.sourceChain != 0) {
            _sendCCIPMessage(purchase.sourceChain, purchase.buyer, MessageType.SETTLE_PAYMENT, abi.encode(purchaseId, purchase.buyerTokenAmount), purchase.buyerToken, purchase.buyerTokenAmount, PayFeesIn.LINK);
        } else {
            require(IERC20(purchase.buyerToken).transfer(purchase.buyer, purchase.buyerTokenAmount), "Token refund failed");
        }
        emit PurchaseCancelled(purchaseId);
    }

    function resolveDispute(uint256 purchaseId, address winner) external onlyOwner {
        Purchase storage purchase = purchases[purchaseId];
        Trade storage trade = trades[purchase.tradeId];
        if (purchase.tradeId == 0) revert PurchaseNotFound(purchaseId);
        if (!purchase.disputed) revert InvalidPurchaseState(purchaseId, "disputed");
        if (disputesResolved[purchaseId]) revert InvalidPurchaseState(purchaseId, "not resolved");

        bool validWinner = winner == purchase.buyer || winner == trade.seller || winner == purchase.chosenLogisticsProvider;
        if (!validWinner) revert NotAuthorized(winner, "trade participant");

        disputesResolved[purchaseId] = true;
        purchase.confirmed = true;

        if (winner == purchase.buyer) {
            if (purchase.sourceChain != 0) {
                _sendCCIPMessage(purchase.sourceChain, purchase.buyer, MessageType.SETTLE_PAYMENT, abi.encode(purchaseId, purchase.buyerTokenAmount), purchase.buyerToken, purchase.buyerTokenAmount, PayFeesIn.LINK);
            } else {
                require(IERC20(purchase.buyerToken).transfer(purchase.buyer, purchase.buyerTokenAmount), "Token refund failed");
            }
        } else {
            uint256 productEscrowFee = (trade.productCost * ESCROW_FEE_PERCENT * purchase.quantity) / BASIS_POINTS;
            uint256 sellerAmount = (trade.productCost * purchase.quantity) - productEscrowFee;
            require(IERC20(i_usdt).transfer(trade.seller, sellerAmount), "USDT transfer to seller failed");

            if (purchase.chosenLogisticsProvider != address(0)) {
                uint256 logisticsEscrowFee = (purchase.logisticsCost * ESCROW_FEE_PERCENT) / BASIS_POINTS;
                uint256 logisticsPayout = purchase.logisticsCost - logisticsEscrowFee;
                require(IERC20(i_usdt).transfer(purchase.chosenLogisticsProvider, logisticsPayout), "USDT transfer to logistics failed");
            }
        }

        emit DisputeResolved(purchaseId, winner);
    }

    function withdrawEscrowFees() external onlyOwner {
        uint256 balance = IERC20(i_usdt).balanceOf(address(this));
        if (balance == 0) revert("No USDT fees to withdraw");
        require(IERC20(i_usdt).transfer(owner(), balance), "USDT withdrawal failed");
    }

    function confirmCrossChainDelivery(uint64 destinationChainSelector, address destinationContract, uint256 purchaseId, PayFeesIn payFeesIn) external returns (bytes32 messageId) {
        bytes memory data = abi.encode(purchaseId);
        return _sendCCIPMessage(destinationChainSelector, destinationContract, MessageType.CONFIRM_DELIVERY, data, address(0), 0, payFeesIn);
    }

    function _processCrossChainDeliveryConfirmation(bytes memory data, address sender) internal {
        uint256 purchaseId = abi.decode(data, (uint256));
        _confirmDeliveryInternal(purchaseId, sender);
    }

    function confirmCrossChainPurchase(uint64 destinationChainSelector, address destinationContract, uint256 purchaseId, PayFeesIn payFeesIn) external returns (bytes32 messageId) {
        bytes memory data = abi.encode(purchaseId);
        return _sendCCIPMessage(destinationChainSelector, destinationContract, MessageType.CONFIRM_PURCHASE, data, address(0), 0, payFeesIn);
    }

    function _processCrossChainPurchaseConfirmation(bytes memory data, address sender) internal {
        uint256 purchaseId = abi.decode(data, (uint256));
        _confirmPurchaseInternal(purchaseId, sender);
    }
}