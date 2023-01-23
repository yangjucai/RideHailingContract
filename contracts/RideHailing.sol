// SPDX-License-Identifier: MIT
pragma solidity >=0.4.2 <0.8.0;

contract InfoManage {
    struct Rider {
        address addr;
        string username;
        string teleNumber;
        string profile;
        uint registerTime;
    }

    struct Driver {
        address addr;
        string username;
        string teleNumber;
        string profile;
        uint registerTime;
        uint finishedTaskNum;
        uint reputation;        
    }

    struct Task {
        uint index;//start from 0
        address rider;
        uint pickupLocation;
        uint pickoffLocation;
        uint minReputation;
        uint reward;
        uint deposit;
        address driver;
        Status status;
    }

    enum Status {
        Unclaimed,
        Claimed,
        ReachedPickupLocation,
        ReachedpickoffLocation,
        Completed
    }

    Task[] public taskList;
    mapping(address => Rider) riderList;
    mapping(address => Driver) driverList;

    //addr has been registered => false
    function checkRegister(string memory userType, address addr) public view returns (bool) {
        if(keccak256(abi.encodePacked(userType)) == keccak256(abi.encodePacked("rider")))
            return riderList[addr].addr > address(0x0) ? false : true ;
        else 
            return driverList[addr].addr > address(0x0) ? false : true ;
    }

    function riderRegister(address addr, string memory username, string memory teleNumber, string memory profile) public {
        require(checkRegister("rider", addr));
        riderList[addr] = Rider(addr, username, teleNumber, profile, block.timestamp);
    }


    function driverRegister(address addr, string memory username, string memory teleNumber, string memory profile) public {
        require(checkRegister("driver", addr));
        //driver's initial reputation: 60
        driverList[addr] = Driver(addr, username, teleNumber, profile, block.timestamp, 0, 60);
    }

    function getRiderInfo(address addr) public view returns (address, string memory, string memory, string memory, uint) {
        require(!checkRegister("rider", addr));
        return (riderList[addr].addr, riderList[addr].username, riderList[addr].teleNumber, riderList[addr].profile, riderList[addr].registerTime);
    }

    function getDriverInfo(address addr) public view returns (address, string memory, string memory, string memory, uint, uint, uint) {
        require(!checkRegister("driver", addr));
        return (driverList[addr].addr, driverList[addr].username, driverList[addr].teleNumber, driverList[addr].profile, driverList[addr].registerTime, driverList[addr].finishedTaskNum, driverList[addr].reputation);
    }

    function updateProfile(string memory userType, address addr, string memory newProfile) public {
        require(addr == msg.sender);
        require(!checkRegister(userType, addr));
        if(keccak256(abi.encodePacked(userType)) == keccak256(abi.encodePacked("rider")))
            riderList[addr].profile = newProfile;
        else 
            driverList[addr].profile = newProfile;
    }

    function getReputation(address addr) public view returns (uint) {
        require(!checkRegister("driver", addr));
        return driverList[addr].reputation;
    }

    function updateReputation(address addr, uint newReputation) public {
        require(!checkRegister("driver", addr));
        driverList[addr].reputation = newReputation;
    }

}


contract RideHailing is InfoManage{

    int public blockUint = 1000000;
    int public initLongitude = 311000000;
    int public initLatitude = 121000000;
    int public rowSize = 1000;
    uint public rewardPerBlock = 10;
                                
    
    function getLocation(int _longitude, int _latitude) public view returns(uint){
        return uint(((_longitude - initLongitude) / blockUint) * rowSize + ((_latitude - initLatitude) / blockUint)); 
    }

    function calculateReward(uint _pickupLocation, uint _pickoffLocation) public view returns(uint) {
        uint distance = _pickupLocation - _pickoffLocation > 0 ? _pickupLocation - _pickoffLocation : _pickoffLocation - _pickupLocation;
        return distance * rewardPerBlock;
    }

    function calculateDeposit(uint _pickupLocation, uint _pickoffLocation) public view returns(uint) {
        uint distance = _pickupLocation - _pickoffLocation > 0 ? _pickupLocation - _pickoffLocation : _pickoffLocation - _pickupLocation;
        return distance * rewardPerBlock;
    }

    function publishTask(int _startLongitude, int _startLatitude, int _endLongitude, int _endLatitude, uint _minReputation) public payable returns (uint _index){
        uint pickupLocation = getLocation(_startLongitude, _startLatitude);
        uint dropoffLocation = getLocation(_endLongitude, _endLatitude);
        uint _reward = calculateReward(pickupLocation, dropoffLocation);
        uint _deposit = calculateDeposit(pickupLocation, dropoffLocation);

        //rider pays the _reward
        require(msg.value >= _reward);

        taskList.push(Task(taskList.length, msg.sender, pickupLocation, dropoffLocation, _minReputation, _reward, _deposit,  address(0x0), Status.Unclaimed));

        return taskList.length - 1;
    }

    function getTaskInfo(uint taskId) public view returns (uint, address, uint, uint, uint, uint, uint, address, Status) {
        Task memory _task = taskList[taskId];
        return (_task.index, _task.rider, _task.pickupLocation, _task.pickoffLocation, _task.minReputation, _task.reward, _task.deposit, _task.driver, _task.status);
    }

    function receiveTask(uint taskId) public payable {
        require(msg.value >= taskList[taskId].deposit);
        require(taskList[taskId].status == Status.Unclaimed);
        require(driverList[msg.sender].reputation >= taskList[taskId].minReputation);

        //update task's driver
        taskList[taskId].driver = msg.sender;

        //update task's status
        taskList[taskId].status = Status.Claimed;
    }

    function proofReachPickupLocation(uint taskId) public pure returns (bool) {

        return true;
    }

    function pickupRider(uint taskId) public {
        require(proofReachPickupLocation(taskId));

        //update task's status
        taskList[taskId].status = Status.ReachedPickupLocation;

        //return deposit
        msg.sender.transfer(taskList[taskId].deposit);
    }

    function proofReachpickoffLocation(uint taskId) public pure returns (bool) {

        return true;
    }

    function reachpickoffLocation(uint taskId) public {
        require(proofReachpickoffLocation(taskId));

        //update task's status
        taskList[taskId].status = Status.ReachedpickoffLocation;
    }

    function calculateReputation(uint taskId) public view returns (uint) {
        if(proofReachpickoffLocation(taskId))
            return driverList[msg.sender].reputation + 1;
        else
            return driverList[msg.sender].reputation > 0 ? driverList[msg.sender].reputation - 5 : 0; 
    }

    function getReward(uint taskId) public {
        //update reputation
        driverList[msg.sender].reputation = calculateReputation(taskId);

        require(proofReachpickoffLocation(taskId));
        msg.sender.transfer(taskList[taskId].reward);

        //update task's status
        taskList[taskId].status = Status.Completed;
    }

}