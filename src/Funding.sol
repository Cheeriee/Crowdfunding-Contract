//SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;


//A crowdfunding contract in solidity allows people to contribute towards a goal within a set deadline. If the goal is reached, the owner can withdraw the funds. If not, contributors can get refunds.
contract Launch{
    address public immutable owner;
    uint256 public immutable goal;
    uint256 public immutable deadline;
    uint256 public totalContributed;
    bool public goalReached;
    bool OwnerWithdrawn;

    struct Contributor { //stores amount and refund status per contributor
        uint256 amount;
        bool hasWithdrawn;
    }


    error InvalidGoal();
    error InvalidDeadline();
    error NotOwner();
    error CampaignEnded();
    error InsufficientAmount();
    error GoalAlreadyReached();
    error CampaignNotEnded();
    error GoalNotReached();
    error AlreadyWithdrawn();
    error WithdrawalFailed();
    error DeadlineNotPassed();
    error NoContribution();


    event Contributed(address indexed contributor, uint256 indexed amount);
    event CampaignStatus(uint256 totalContributed, bool goalReached, bool deadlinePassed);
    event Withdrawn(address indexed owner, uint256 indexed amount);
    event ContributorRefunded(address indexed contributor, uint256 indexed amount);

    mapping(address => Contributor) public contributors;

    constructor(uint256 _duration, uint256 _goal) {
        if(_goal == 0){
          revert InvalidGoal();
        }
        if(_duration == 0) {
            revert InvalidDeadline();
        }

        owner = msg.sender;
        goal = _goal;
        deadline = block.timestamp + _duration;
        goalReached = false;
        OwnerWithdrawn = false;
    }

    modifier onlyOwner(){ //to restrict access to owner
        if(msg.sender != owner) {
            revert NotOwner();
        }
        _;
    }

    modifier onlyActive(){ //to check if campaign is still active
        if(block.timestamp >= deadline) {
            revert CampaignEnded();
        }
        _;
    }

    //function to contribute funds
    function contribute() external payable onlyActive {
        if(msg.value == 0) {
            revert InsufficientAmount();
        }
        if(totalContributed >= goal) {
            revert GoalAlreadyReached();
        }
        
        Contributor storage contributor = contributors[msg.sender]; //fetch the contributor's storage slot to update it
        contributor.amount += msg.value; //add the sent amount to the contributor's record
        totalContributed += msg.value; //update the overall funds raised by the campain

        emit Contributed(msg.sender, msg.value); //emit event showing who contributed and how much
        emit CampaignStatus(totalContributed, totalContributed >= goal, block.timestamp >= deadline); //emit event showing the goal is now reached and deadline has passed. Emits the current status of the campaign after every contribution
    }

    //function for owner to withdraw funds if the goal is met
    function withdrawOwner() external onlyOwner {
        if(block.timestamp < deadline) {
            revert CampaignNotEnded();
        }
        if(totalContributed < goal) {
            revert GoalNotReached();
        }
        if(OwnerWithdrawn) { 
            revert AlreadyWithdrawn();
        }

        OwnerWithdrawn = true; //marks that the owner has withdrawn to block future withdrawals. Set this before transferring funds to defensively to prevent re-entrancy attacks. LOck it first
        uint256 amount = address(this).balance;  //gets the entire balance of the contract

        (bool success,) = owner.call{value: amount}(""); //sends the ETH to the owner's address using .call{value: ...} which is safer and more flexible than .transfer
        if(!success) {
            revert WithdrawalFailed();
        }

        emit Withdrawn(owner, amount);
    }

    //function for contributors to withdraw funds if goal is not reached
    function withdrawContributor() external {
        if(block.timestamp < deadline) {
            revert DeadlineNotPassed();
        }
        if(totalContributed >= goal) {
            revert GoalAlreadyReached();
        }
    

    Contributor storage contributor = contributors[msg.sender]; //making reference to the Constructor struct
        if(contributor.amount == 0) {
            revert NoContribution();
        }
        if(contributor.hasWithdrawn) {
            revert AlreadyWithdrawn();
        }

        contributor.hasWithdrawn = true;
        uint256 amount = contributor.amount;

        (bool success,) = msg.sender.call{value: amount}("");
        if(!success) {
            revert WithdrawalFailed();
        }

        emit ContributorRefunded(msg.sender, amount);
}

    //function to check campaign status
    function getCampaignStatus() external view returns(
        uint256 currentFunds, 
        uint256 goalAmount, 
        uint256 deadlineTimestamp,
        bool isGoalReached,
        bool isDeadlinePassed,
        bool hasOwnerWithdrawn
        ){
            return(totalContributed, goal, deadline, totalContributed >= goal, block.timestamp >= deadline, OwnerWithdrawn);
        }

    //funtion to get contributor's contribution
    function getContribution(address _contributor) external view returns(uint256 amount, bool hasWithdrawn) {
        Contributor memory contributor = contributors[_contributor];
            return (contributor.amount, contributor.hasWithdrawn);
    }

    //receive function to handle direct token transfers
    receive() external payable {
        // Accept ETH sent directly to the contract, but do not call contribute() to avoid modifier issues.
        // Optionally, you can emit an event or handle logic here if needed.
    }

    //fallback function
    fallback() external payable {
        
    }
}