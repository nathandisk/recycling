1. State Variables

These are the variables that store the state of the contract, including user balances, reward rates, and roles.

    ERC-20 Variables:
        name: The name of the ERC-20 token ("Recycling Voucher").
        symbol: The symbol for the ERC-20 token ("RV").
        decimals: Number of decimal places for token precision (18).
        totalSupply: Total supply of the Recycling Vouchers (ERC-20 tokens).
        balanceOf: Mapping that tracks the balance of Recycling Vouchers for each address (follows the ERC-20 balanceOf standard).
        allowance: Mapping for allowances, allowing third-party spending on behalf of the token holder (follows the ERC-20 allowance standard).

    Admin & Role Management:
        adminPool: Address holding the pool of vouchers for the contract (admin pool).
        isAdmin: Mapping to check if an address is an admin.
        isVendor: Mapping to check if an address is a vendor.
        isRecyclingPersonnel: Mapping to check if an address is recycling personnel.

    Reward Rates:
        rewardRates: A mapping that associates each material type (Plastic, Glass, Metal, Paper) with a specific reward rate (in ether units).

2. Enums

    MaterialType: An enum to define the types of materials (Plastic, Glass, Metal, Paper) for which rewards are calculated.

3. Events

These events notify external systems (e.g., front-end interfaces, logging systems) of important contract actions.

    Transfer: Standard ERC-20 event, triggered when tokens are transferred between users.
    Approval: Standard ERC-20 event, triggered when an allowance is granted for third-party spending.
    TrashDeposited: Emitted when a user deposits recyclable materials and receives vouchers.
    TrashProcessed: Emitted when trash is processed and vouchers are transferred to a recycler.
    VendorDeposit: Emitted when a vendor deposits vouchers into the admin pool.
    PayoutWithdrawn: Emitted when an admin withdraws Ether or vouchers to an investor.
    AdminAdded, VendorAdded, RecyclingPersonnelAdded: Emitted when roles are added to the system.
    VouchersAdded: Emitted when vouchers are added to a user's balance (usually after a trash deposit).
    VendorCheck: Emitted to verify if an account is marked as a vendor.

Core Functions
1. Constructor

The constructor initializes the contract when it is deployed. It sets the adminPool address (which holds the vouchers), assigns the contract deployer as the first admin, and defines initial reward rates for different material types.

constructor(address _adminPool) {
    require(_adminPool != address(0), "Invalid admin pool address");
    adminPool = _adminPool;
    isAdmin[msg.sender] = true; // Contract deployer is the first admin
    rewardRates[MaterialType.Plastic] = 1 ether;
    rewardRates[MaterialType.Glass] = 2 ether;
    rewardRates[MaterialType.Metal] = 3 ether;
    rewardRates[MaterialType.Paper] = 1.5 ether;
}

2. Modifiers

These are custom access control mechanisms that ensure only certain users (admins, vendors, recycling personnel) can call specific functions.

    onlyAdmin: Ensures that only an admin can execute the function.
    onlyVendor: Ensures that only a vendor can execute the function.
    onlyRecyclingPersonnel: Ensures that only recycling personnel can execute the function.

Example:

modifier onlyAdmin() {
    require(isAdmin[msg.sender], "Not an admin");
    _;
}

3. ERC-20 Functions

These functions implement the ERC-20 standard for the Recycling Vouchers (RV tokens).

    _mint: Creates new vouchers (ERC-20 tokens) and assigns them to an address. It is used by the contract to mint tokens to the adminPool when vendors deposit vouchers.

function _mint(address account, uint256 amount) internal {
    require(account != address(0), "ERC20: mint to the zero address");
    totalSupply += amount;
    balanceOf[account] += amount;
    emit Transfer(address(0), account, amount);
}

_burn: Destroys vouchers (ERC-20 tokens) from an address.

function _burn(address account, uint256 amount) internal {
    require(account != address(0), "ERC20: burn from the zero address");
    require(balanceOf[account] >= amount, "ERC20: burn amount exceeds balance");
    totalSupply -= amount;
    balanceOf[account] -= amount;
    emit Transfer(account, address(0), amount);
}

transfer: Transfers vouchers (ERC-20 tokens) from the sender to a recipient.

function transfer(address recipient, uint256 amount) external returns (bool) {
    _transfer(msg.sender, recipient, amount);
    return true;
}

approve: Grants approval for a spender to transfer a specific amount of vouchers from the caller's account.

function approve(address spender, uint256 amount) external returns (bool) {
    allowance[msg.sender][spender] = amount;
    emit Approval(msg.sender, spender, amount);
    return true;
}

transferFrom: Allows a spender (who has been approved) to transfer vouchers on behalf of the owner.

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        require(amount <= allowance[sender][msg.sender], "ERC20: transfer amount exceeds allowance");
        allowance[sender][msg.sender] -= amount;
        _transfer(sender, recipient, amount);
        return true;
    }

4. Vendor Deposit

Vendors deposit vouchers (ERC-20 tokens) into the adminPool, where new vouchers are minted and added to the pool.

function vendorDeposit(uint256 voucherAmount) external onlyVendor {
    require(voucherAmount > 0, "Voucher amount must be positive");
    _mint(adminPool, voucherAmount); // Mint the vouchers as ERC-20 tokens to the admin pool
    emit VendorDeposit(msg.sender, voucherAmount);
}

5. Trash Deposit

Users can deposit recyclable materials and receive vouchers based on the material type and amount of trash deposited. The system calculates the reward based on the rewardRates.

function depositTrash(MaterialType material, uint256 trashWeight) external {
    uint256 voucherReward = calculateReward(material, trashWeight);
    require(balanceOf[adminPool] >= voucherReward, "Insufficient vouchers in admin pool");
    _transfer(adminPool, msg.sender, voucherReward); // Transfer ERC-20 tokens from the admin pool to the user
    emit TrashDeposited(msg.sender, material, trashWeight, voucherReward);
}

6. Set Reward Rate

Admins can modify the reward rates for each material type.

function setRewardRate(MaterialType material, uint256 rate) external onlyAdmin {
    require(rate > 0, "Reward rate must be positive");
    rewardRates[material] = rate;
}

7. Process Trash

Recyclers can process trash and receive vouchers. This function transfers vouchers to the recycler from the admin pool.

function processTrash(uint256 trashValue) external {
    require(trashValue > 0, "Trash value must be positive");
    require(balanceOf[adminPool] >= trashValue, "Insufficient vouchers for payout");
    _transfer(adminPool, msg.sender, trashValue); // Transfer ERC-20 tokens from admin pool
    emit TrashProcessed(msg.sender, trashValue);
}

8. Withdraw Payout

Admins can withdraw payouts in Ether and ERC-20 vouchers to investors.

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
        (bool sent, ) = investor.call{value: ethAmount}("");
        require(sent, "Failed to send Ether to investor");
    }

    // Handle ERC-20 Voucher payout
    if (voucherAmount > 0) {
        require(balanceOf[adminPool] >= voucherAmount, "Insufficient vouchers in admin pool");
        _transfer(adminPool, investor, voucherAmount); // Transfer vouchers (ERC-20 tokens) to the investor
    }

    // Emit a withdrawal event
    emit PayoutWithdrawn(msg.sender, investor, ethAmount + voucherAmount);
}