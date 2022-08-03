// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract VRFv2Consumer is Ownable, VRFConsumerBaseV2{
    VRFCoordinatorV2Interface COORDINATOR;
    uint64 s_subscriptionId;
    address private vrfCoordinator = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;
    bytes32 private keyHash;
    uint16  private requestConfirmations ;
    uint32  public selectTotalWinners ;
    uint32  public callbackGasLimit;
    mapping(uint256 => uint256[]) public randomWordsByVRF;
    uint256 private requestCounter;
    uint256 private s_requestId;
    mapping(uint256 => address[]) public winnerAddres;
    struct Participant {
        address walletAddress;
        uint    guessNumberCounter;
        uint    guessEteryCount;
        string  participantType;
        bool    exists;
        uint[]  guess;
    }
    mapping(uint => mapping(address => Participant)) public participants;
    mapping(uint => address[]) private userAddresses;
    mapping(uint256 => uint256) public randomAssigner;

    uint32 public publicTeirEnteriesAllowed ;
    uint32 public commonTeirEnteriesAllowed ;
    uint32 public uncommonTeirEnteriesAllowed ;

    struct LotteryDetails{
        uint32 lotteryNumber; 
        uint256 participants; 
        bool  status;
        uint32 numberOfWinner;
        string LotteryStatus;
    } 
    mapping(uint => LotteryDetails) public lotteryStatus;
    uint32 private lotteryNumberForRandomString;
    // 7345 subscriptionId
    constructor(uint64 subscriptionId) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR         =   VRFCoordinatorV2Interface(vrfCoordinator);
        keyHash             =   0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;
        callbackGasLimit    =   100000;
        requestConfirmations=   3;
        s_subscriptionId    =   subscriptionId;
        publicTeirEnteriesAllowed  = 1;
        commonTeirEnteriesAllowed  = 3;
        uncommonTeirEnteriesAllowed = 5;
    }
    function registerForParticipant(string memory memberType, uint32 _lotteryNumber) external{
        require(msg.sender != address(0), "Mint to the zero address");
        require(lotteryStatus[_lotteryNumber].status == true, "Lottery Not Exists try Again");
        require(keccak256(abi.encodePacked(lotteryStatus[_lotteryNumber].LotteryStatus)) == keccak256(abi.encodePacked("start")) , "You can't make requrest again because this lottery have stop or completed mode");
        require(keccak256(abi.encodePacked(memberType)) == keccak256(abi.encodePacked("publicMember")) || keccak256(abi.encodePacked(memberType)) == keccak256(abi.encodePacked("commonMember")) || keccak256(abi.encodePacked(memberType)) == keccak256(abi.encodePacked("uncommonMember")), "Participants type not correct!");
        require(participants[_lotteryNumber][msg.sender].exists == false, "Already exists");
        require(lotteryStatus[_lotteryNumber].participants >= userAddresses[_lotteryNumber].length +1 , "Particiipent limit is finished!");
        participants[_lotteryNumber][msg.sender].participantType = memberType;
        participants[_lotteryNumber][msg.sender].exists = true;
        participants[_lotteryNumber][msg.sender].walletAddress = msg.sender;
        userAddresses[_lotteryNumber].push(msg.sender);
        if(keccak256(abi.encodePacked(memberType)) == keccak256(abi.encodePacked("publicMember"))){
            participants[_lotteryNumber][msg.sender].guessNumberCounter = publicTeirEnteriesAllowed;
        }else if(keccak256(abi.encodePacked(memberType)) == keccak256(abi.encodePacked("commonMember"))){
            participants[_lotteryNumber][msg.sender].guessNumberCounter = commonTeirEnteriesAllowed;
        }else{
            participants[_lotteryNumber][msg.sender].guessNumberCounter = uncommonTeirEnteriesAllowed;
        }
        assignRandomWords(_lotteryNumber);
    }

    function assignRandomWords(uint32 _lotteryNumber) internal{
        require(lotteryStatus[_lotteryNumber].status == true, "Lottery Not Exists try Again");
        require(keccak256(abi.encodePacked(lotteryStatus[_lotteryNumber].LotteryStatus)) == keccak256(abi.encodePacked("start")) , "You can't make requrest again because this lottery have stop or completed mode");
        require(participants[_lotteryNumber][msg.sender].guessNumberCounter >= participants[_lotteryNumber][msg.sender].guessEteryCount + 1, "Your limit is finished");
        for(uint guessCount = 1; guessCount <= participants[_lotteryNumber][msg.sender].guessNumberCounter ; guessCount++){

            randomAssigner[_lotteryNumber] += 1;
            participants[_lotteryNumber][msg.sender].guess.push(randomAssigner[_lotteryNumber]);
            participants[_lotteryNumber][msg.sender].guessEteryCount +=1;
        }
    }

    function userGuessesReturn(uint32 _lotteryNumber) view public returns(uint[] memory) {
        return participants[_lotteryNumber][msg.sender].guess;
    }

    function requestRandomWords(uint32 _lotteryNumber) external onlyOwner {
        require(lotteryStatus[_lotteryNumber].status == true, "Lottery Not Exists try Again");
        require(keccak256(abi.encodePacked(lotteryStatus[_lotteryNumber].LotteryStatus)) == keccak256(abi.encodePacked("start")) , "You can't make requrest again because this lottery have stop or completed mode");
        require(userAddresses[_lotteryNumber].length >= lotteryStatus[_lotteryNumber].numberOfWinner, "Number of participants should be greater then or eqal to number of winners");
        lotteryNumberForRandomString = _lotteryNumber;
        s_requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            lotteryStatus[_lotteryNumber].numberOfWinner
        );
    }

    function fulfillRandomWords(uint256, uint256[] memory randomWords) internal override {
        randomWordsByVRF[lotteryNumberForRandomString] = randomWords; 
    }

    function endLottery(uint32 _lotteryNumber) public onlyOwner returns(address[] memory){
        require(lotteryStatus[_lotteryNumber].status == true, "Lottery Not Exists try Again");
        require(keccak256(abi.encodePacked(lotteryStatus[_lotteryNumber].LotteryStatus)) == keccak256(abi.encodePacked("start")) , "You can't end this lottory because this is already in stop or compeleted mode");
        require(randomWordsByVRF[_lotteryNumber].length > 0, "First call random number generator VRF!");
        require(userAddresses[_lotteryNumber].length >= lotteryStatus[_lotteryNumber].numberOfWinner, "Number of participants should be greater then or eqal to number of winners");
        console.log("userAddresses => ",userAddresses[_lotteryNumber].length);
        for(uint users = 0; users < userAddresses[_lotteryNumber].length; users++) { 
            console.log("guessNumber => ",randomWordsByVRF[_lotteryNumber].length);
            for(uint guessNumber = 0; guessNumber < randomWordsByVRF[_lotteryNumber].length; guessNumber++) { 
                console.log("userGuess => ", participants[_lotteryNumber][userAddresses[_lotteryNumber][users]].guess.length );
                for(uint userGuess = 0; userGuess < participants[_lotteryNumber][userAddresses[_lotteryNumber][users]].guess.length; userGuess++) { 
                    if( participants[_lotteryNumber][userAddresses[_lotteryNumber][users]].guess[userGuess] == (randomWordsByVRF[_lotteryNumber][guessNumber] % (userAddresses[_lotteryNumber].length)+1)) {
                        winnerAddres[_lotteryNumber].push(userAddresses[_lotteryNumber][users]);
                    }
                } 
            }
        }
        lotteryStatus[_lotteryNumber].LotteryStatus  =   "completed"; 
        return winnerAddres[_lotteryNumber];
    }

    //new functionality 
    function updateTierCount(string memory teirType, uint32 newLimit) public onlyOwner {
        require(keccak256(abi.encodePacked(teirType)) == keccak256(abi.encodePacked("publicMember")) || keccak256(abi.encodePacked(teirType)) == keccak256(abi.encodePacked("commonMember")) || keccak256(abi.encodePacked(teirType)) == keccak256(abi.encodePacked("uncommonMember")), "Participants type not correct!");
        if(keccak256(abi.encodePacked(teirType)) == keccak256(abi.encodePacked("publicMember"))){
            publicTeirEnteriesAllowed = newLimit;
        }else if(keccak256(abi.encodePacked(teirType)) == keccak256(abi.encodePacked("commonMember"))){
            commonTeirEnteriesAllowed = newLimit;
        }else{
            uncommonTeirEnteriesAllowed = newLimit;
        }
    }

    function startLottery(uint32 _lotteryNumber, uint256 _participants, uint32 _numberOfWinner) external onlyOwner{
        require(lotteryStatus[_lotteryNumber].status == false, "Lottery Already Exists try Again");
        require(_participants > 0, "Participends Should be greater then 0");
        require(_numberOfWinner > 0, "Number of winner should be greater then 0");
        lotteryStatus[_lotteryNumber].participants   =   _participants;
        lotteryStatus[_lotteryNumber].lotteryNumber  =   _lotteryNumber;
        lotteryStatus[_lotteryNumber].numberOfWinner =   _numberOfWinner;
        lotteryStatus[_lotteryNumber].LotteryStatus  =   "start"; //should be 3 type of status like stop start and complete
        lotteryStatus[_lotteryNumber].status         =   true;
        randomAssigner[_lotteryNumber] = 0;
    }

    function getTotalParticipents(uint32 _lotteryNumber) public view onlyOwner returns(uint256){
        require(lotteryStatus[_lotteryNumber].status == true, "Lottery Not Exists check your Lottery number and try Again");
        return userAddresses[_lotteryNumber].length;
    } 

    function getWinnerAddresses(uint32 _lotteryNumber) public view onlyOwner returns( address[] memory){
        return winnerAddres[_lotteryNumber];
    }
}
