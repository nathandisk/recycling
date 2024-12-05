// SPDX-License-Identifier: Public Domain
pragma solidity ^0.8.0;

contract RecyclingIncentiveSystem {
    // ERC-20 state variables
    string public name = "Recycling Voucher";
    string public symbol = "RV";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf; // Automatically creates the getter function
    mapping(address => mapping(address => uint256)) public allowance;

    address public adminPool; // Common pool for admin vouchers
    mapping(address => bool) public isAdmin;
    mapping(address => bool) public isVendor;
    mapping(address => bool) public isRecyclingPersonnel;

    enum MaterialType { Plastic, Glass, Metal, Paper }
    mapping(MaterialType => uint256) public rewardRates;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event TrashDeposited(address indexed user, MaterialType material, uint256 trashAmount, uint256 voucherReward);
    event TrashProcessed(address indexed recycler, uint256 trashValue);
    event VendorDeposit(address indexed vendor, uint256 voucherAmount);
    event PayoutWithdrawn(address indexed admin, address indexed investor, uint256 amount);
    event AdminAdded(address indexed admin);
    event VendorAdded(address indexed vendor);
    event RecyclingPersonnelAdded(address indexed personnel);
    event VouchersAdded(address indexed account, uint256 amount);
    event VendorCheck(address indexed account, bool isVendor);

    constructor(address _adminPool) {
        require(_adminPool != address(0), "Invalid admin pool address");
        adminPool = _adminPool;
        isAdmin[msg.sender] = true; // Contract deployer is the first admin
        rewardRates[MaterialType.Plastic] = 1 ether;
        rewardRates[MaterialType.Glass] = 2 ether;
        rewardRates[MaterialType.Metal] = 3 ether;
        rewardRates[MaterialType.Paper] = 1.5 ether;
    }

    modifier onlyAdmin() {
        require(isAdmin[msg.sender], "Not an admin");
        _;
    }

    modifier onlyVendor() {
        require(isVendor[msg.sender], "Not a vendor");
        _;
    }

    modifier onlyRecyclingPersonnel() {
        require(isRecyclingPersonnel[msg.sender], "Not recycling personnel");
        _;
    }

    // ERC-20 implementation
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");
        totalSupply += amount;
        balanceOf[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");
        require(balanceOf[account] >= amount, "ERC20: burn amount exceeds balance");
        totalSupply -= amount;
        balanceOf[account] -= amount;
        emit Transfer(account, address(0), amount);
    }

    function transfer(address recipient, uint256 amount) external returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(balanceOf[sender] >= amount, "ERC20: transfer amount exceeds balance");

        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;
        emit Transfer(sender, recipient, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        require(amount <= allowance[sender][msg.sender], "ERC20: transfer amount exceeds allowance");
        allowance[sender][msg.sender] -= amount;
        _transfer(sender, recipient, amount);
        return true;
    }

    // Vendor Deposit (ERC-20 Deposit)
    function vendorDeposit(uint256 voucherAmount) external onlyVendor {
        require(voucherAmount > 0, "Voucher amount must be positive");
        _mint(adminPool, voucherAmount); // Mint the vouchers as ERC-20 tokens to the admin pool
        emit VendorDeposit(msg.sender, voucherAmount);
    }

    // Deposit Trash (Receive Vouchers as ERC-20)
    function depositTrash(MaterialType material, uint256 trashWeight) external {
        uint256 voucherReward = calculateReward(material, trashWeight);

        require(balanceOf[adminPool] >= voucherReward, "Insufficient vouchers in admin pool");

        _transfer(adminPool, msg.sender, voucherReward); // Transfer ERC-20 tokens from the admin pool to the user
        emit TrashDeposited(msg.sender, material, trashWeight, voucherReward);
    }

    // Set Reward Rate
    function setRewardRate(MaterialType material, uint256 rate) external onlyAdmin {
        require(rate > 0, "Reward rate must be positive");
        rewardRates[material] = rate;
    }

    // Calculate Reward (Based on Material Type and Trash Weight)
    function calculateReward(MaterialType material, uint256 trashWeight) internal view returns (uint256) {
        return trashWeight * rewardRates[material];
    }

    // Process Trash (Transfer from Admin Pool to Recycler as ERC-20 tokens)
    function processTrash(uint256 trashValue) external {
        require(trashValue > 0, "Trash value must be positive");
        require(balanceOf[adminPool] >= trashValue, "Insufficient vouchers for payout");

        _transfer(adminPool, msg.sender, trashValue); // Transfer ERC-20 tokens from admin pool
        emit TrashProcessed(msg.sender, trashValue);
    }

    // Withdraw Payout (Both Ether and ERC-20 tokens)
    function withdrawPayout(
        address payable investor,
        uint256 ethAmount,
        uint256 voucherAmount
    ) external onlyAdmin {
        require(investor != address(0), "Invalid investor address");
        require(ethAmount > 0 || voucherAmount > 0, "Invalid withdrawal amounts");

        // Handle Ether payout
        if (ethAmount > 0) {
            require(address(this).balance >= ethAmount, "Insufficient contract balance");

            // Transfer Ether to the investor
            (bool sent, ) = investor.call{value: ethAmount}("");
            require(sent, "Failed to send Ether to investor");
        }

        // Handle ERC-20 Voucher payout
        if (voucherAmount > 0) {
            require(balanceOf[adminPool] >= voucherAmount, "Insufficient vouchers in admin pool");

            // Transfer vouchers (ERC-20 tokens) to the investor
            _transfer(adminPool, investor, voucherAmount);
        }

        // Emit a withdrawal event
        emit PayoutWithdrawn(msg.sender, investor, ethAmount + voucherAmount);
    }

    // Admin Operations
    function addAdmin(address _admin) external onlyAdmin {
        require(_admin != address(0), "Invalid address");
        require(!isAdmin[_admin], "Already an admin");
        isAdmin[_admin] = true;
        emit AdminAdded(_admin);
    }

    function addVendor(address _vendor) external onlyAdmin {
        require(_vendor != address(0), "Invalid address");
        require(!isVendor[_vendor], "Already a vendor");
        isVendor[_vendor] = true;
        emit VendorAdded(_vendor);
    }

    function addRecyclingPersonnel(address _personnel) external onlyAdmin {
        require(_personnel != address(0), "Invalid address");
        require(!isRecyclingPersonnel[_personnel], "Already recycling personnel");
        isRecyclingPersonnel[_personnel] = true;
        emit RecyclingPersonnelAdded(_personnel);
    }

    // Receive Ether function
    receive() external payable {}
}