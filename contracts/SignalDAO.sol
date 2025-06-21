// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SignalDAO
 * @dev A decentralized autonomous organization for signal intelligence and data verification
 * @author SignalDAO Team
 */
contract SignalDAO {
    
    // State variables
    address public owner;
    uint256 public totalMembers;
    uint256 public proposalCount;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MIN_QUORUM = 51; // 51% quorum required
    
    // Structs
    struct Member {
        address memberAddress;
        uint256 reputation;
        uint256 joinedAt;
        bool isActive;
    }
    
    struct Signal {
        uint256 id;
        address submitter;
        string dataHash;
        string description;
        uint256 timestamp;
        uint256 verificationCount;
        bool isVerified;
        mapping(address => bool) verifiers;
    }
    
    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 deadline;
        bool executed;
        mapping(address => bool) hasVoted;
    }
    
    // Mappings
    mapping(address => Member) public members;
    mapping(uint256 => Signal) public signals;
    mapping(uint256 => Proposal) public proposals;
    mapping(address => bool) public isMember;
    
    // Arrays for iteration
    address[] public memberList;
    uint256[] public signalList;
    
    // Events
    event MemberJoined(address indexed member, uint256 timestamp);
    event SignalSubmitted(uint256 indexed signalId, address indexed submitter, string dataHash);
    event SignalVerified(uint256 indexed signalId, address indexed verifier);
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string title);
    event ProposalVoted(uint256 indexed proposalId, address indexed voter, bool support);
    event ProposalExecuted(uint256 indexed proposalId);
    event ReputationUpdated(address indexed member, uint256 newReputation);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyMember() {
        require(isMember[msg.sender], "Only members can call this function");
        _;
    }
    
    modifier validSignal(uint256 _signalId) {
        require(_signalId < signalList.length, "Invalid signal ID");
        _;
    }
    
    modifier validProposal(uint256 _proposalId) {
        require(_proposalId < proposalCount, "Invalid proposal ID");
        require(proposals[_proposalId].deadline > block.timestamp, "Proposal voting period ended");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        totalMembers = 0;
        proposalCount = 0;
    }
    
    /**
     * @dev Core Function 1: Join the DAO as a member
     * @notice Allows users to become members of SignalDAO
     */
    function joinDAO() external {
        require(!isMember[msg.sender], "Already a member");
        require(msg.sender != address(0), "Invalid address");
        
        members[msg.sender] = Member({
            memberAddress: msg.sender,
            reputation: 100, // Starting reputation
            joinedAt: block.timestamp,
            isActive: true
        });
        
        isMember[msg.sender] = true;
        memberList.push(msg.sender);
        totalMembers++;
        
        emit MemberJoined(msg.sender, block.timestamp);
    }
    
    /**
     * @dev Core Function 2: Submit and verify signals (data intelligence)
     * @param _dataHash IPFS hash or other identifier for the signal data
     * @param _description Description of the signal
     */
    function submitSignal(string memory _dataHash, string memory _description) external onlyMember {
        require(bytes(_dataHash).length > 0, "Data hash cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        
        uint256 signalId = signalList.length;
        
        Signal storage newSignal = signals[signalId];
        newSignal.id = signalId;
        newSignal.submitter = msg.sender;
        newSignal.dataHash = _dataHash;
        newSignal.description = _description;
        newSignal.timestamp = block.timestamp;
        newSignal.verificationCount = 0;
        newSignal.isVerified = false;
        
        signalList.push(signalId);
        
        // Award reputation for signal submission
        members[msg.sender].reputation += 10;
        
        emit SignalSubmitted(signalId, msg.sender, _dataHash);
        emit ReputationUpdated(msg.sender, members[msg.sender].reputation);
    }
    
    /**
     * @dev Verify a submitted signal
     * @param _signalId ID of the signal to verify
     */
    function verifySignal(uint256 _signalId) external onlyMember validSignal(_signalId) {
        Signal storage signal = signals[_signalId];
        
        require(signal.submitter != msg.sender, "Cannot verify own signal");
        require(!signal.verifiers[msg.sender], "Already verified this signal");
        require(members[msg.sender].reputation >= 50, "Insufficient reputation to verify");
        
        signal.verifiers[msg.sender] = true;
        signal.verificationCount++;
        
        // Signal is verified if at least 3 members with good reputation verify it
        if (signal.verificationCount >= 3 && !signal.isVerified) {
            signal.isVerified = true;
            // Award reputation to submitter for verified signal
            members[signal.submitter].reputation += 25;
            emit ReputationUpdated(signal.submitter, members[signal.submitter].reputation);
        }
        
        // Award reputation to verifier
        members[msg.sender].reputation += 5;
        
        emit SignalVerified(_signalId, msg.sender);
        emit ReputationUpdated(msg.sender, members[msg.sender].reputation);
    }
    
    /**
     * @dev Core Function 3: Create and vote on governance proposals
     * @param _title Title of the proposal
     * @param _description Detailed description of the proposal
     */
    function createProposal(string memory _title, string memory _description) external onlyMember {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(members[msg.sender].reputation >= 100, "Insufficient reputation to create proposal");
        
        uint256 proposalId = proposalCount;
        
        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.title = _title;
        newProposal.description = _description;
        newProposal.votesFor = 0;
        newProposal.votesAgainst = 0;
        newProposal.deadline = block.timestamp + VOTING_PERIOD;
        newProposal.executed = false;
        
        proposalCount++;
        
        emit ProposalCreated(proposalId, msg.sender, _title);
    }
    
    /**
     * @dev Vote on a proposal
     * @param _proposalId ID of the proposal to vote on
     * @param _support True for yes, false for no
     */
    function voteOnProposal(uint256 _proposalId, bool _support) external onlyMember validProposal(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];
        
        require(!proposal.hasVoted[msg.sender], "Already voted on this proposal");
        require(members[msg.sender].reputation >= 50, "Insufficient reputation to vote");
        
        proposal.hasVoted[msg.sender] = true;
        
        // Reputation-weighted voting
        uint256 votingPower = members[msg.sender].reputation / 10;
        
        if (_support) {
            proposal.votesFor += votingPower;
        } else {
            proposal.votesAgainst += votingPower;
        }
        
        emit ProposalVoted(_proposalId, msg.sender, _support);
    }
    
    /**
     * @dev Execute a proposal if it passes
     * @param _proposalId ID of the proposal to execute
     */
    function executeProposal(uint256 _proposalId) external {
        require(_proposalId < proposalCount, "Invalid proposal ID");
        
        Proposal storage proposal = proposals[_proposalId];
        
        require(block.timestamp > proposal.deadline, "Voting period not ended");
        require(!proposal.executed, "Proposal already executed");
        
        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;
        uint256 totalPossibleVotes = getTotalReputationPower();
        uint256 quorumReached = (totalVotes * 100) / totalPossibleVotes;
        
        require(quorumReached >= MIN_QUORUM, "Quorum not reached");
        require(proposal.votesFor > proposal.votesAgainst, "Proposal rejected");
        
        proposal.executed = true;
        
        emit ProposalExecuted(_proposalId);
    }
    
    // View functions
    function getMemberInfo(address _member) external view returns (
        uint256 reputation,
        uint256 joinedAt,
        bool isActive
    ) {
        Member memory member = members[_member];
        return (member.reputation, member.joinedAt, member.isActive);
    }
    
    function getSignalInfo(uint256 _signalId) external view validSignal(_signalId) returns (
        address submitter,
        string memory dataHash,
        string memory description,
        uint256 timestamp,
        uint256 verificationCount,
        bool isVerified
    ) {
        Signal storage signal = signals[_signalId];
        return (
            signal.submitter,
            signal.dataHash,
            signal.description,
            signal.timestamp,
            signal.verificationCount,
            signal.isVerified
        );
    }
    
    function getProposalInfo(uint256 _proposalId) external view returns (
        address proposer,
        string memory title,
        string memory description,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 deadline,
        bool executed
    ) {
        require(_proposalId < proposalCount, "Invalid proposal ID");
        
        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.proposer,
            proposal.title,
            proposal.description,
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.deadline,
            proposal.executed
        );
    }
    
    function getTotalReputationPower() public view returns (uint256) {
        uint256 totalReputation = 0;
        for (uint256 i = 0; i < memberList.length; i++) {
            if (members[memberList[i]].isActive) {
                totalReputation += members[memberList[i]].reputation;
            }
        }
        return totalReputation;
    }
    
    function getSignalCount() external view returns (uint256) {
        return signalList.length;
    }
    
    function getAllMembers() external view returns (address[] memory) {
        return memberList;
    }
}
