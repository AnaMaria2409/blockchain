// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "./Ownable.sol";
import "./MarketTypes.sol";
import "./Categories.sol";
import "./Actors.sol";
import "./Token.sol";


contract Marketplace is Ownable {

    Categories internal categories;
    ActorsContract internal actorsContract;
    Token internal token;
    uint256 internal indexTask;
    uint256 internal numberOfTasks;
    mapping(uint256 => MarketTypes.TaskInfoWrapper) internal tasks;

    //CONSTANTS
    uint internal constant TASK_DEFAULT_IMPLEMENT_TIME = 50;
    uint internal constant TK_AMOUNT = 1000;
    uint internal constant INITIAL_TOKENS_ACTOR_VALUE = 100;

    // events
    event TaskAdded(address owner, string description, uint256 id);
    event TaskFunded(uint256 taskId, address sponsor, uint256 amount);
    event TaskFundedTotal(uint256 taskId);
    event TaskRemoved(address owner, uint256 taskId);
    event fundsWithdrawn(uint taskId, address funder, uint amount);
    event evaluatorChoosed(uint taskId, address evaluator);
    event freelancerApplied(uint taskId, address freelancer);
    event taskCompleted(uint taskId);
    event evaluatorReviewed(uint taskId, bool accepted);
    event managerReviewed(uint taskId, bool accepted);
    event freelancerChoosed(uint taskId, address freelancer);

    //modifiers
    modifier restrictedTo(ActorsContract.ActorTypes actorType) {
        require(
            actorsContract.getActorType(msg.sender) == actorType,
            "Restricted to you!"
        );
        _;
    }

    modifier taskCurrentState(uint256 taskId, MarketTypes.TaskState state) {
        require(tasks[taskId].state == state, "Invalid task for action!");
        _;
    }

    modifier restrictedToManagerParent(uint256 taskId) {
        require(tasks[taskId].manager == msg.sender, "Not manager of this task!");
        _;
    }

    constructor(
        address __category_lib_addr,
        address _actors_contract_addr,
        address _token
    ) {
        categories = Categories(__category_lib_addr);
        actorsContract = ActorsContract(_actors_contract_addr);
        token = Token(_token);
        token.mint(TK_AMOUNT);
        indexTask = 0;
        numberOfTasks = 0;
    }

    function addCategory(string memory name) public restricted returns (uint256){
        return categories.addCategory(name);
    }

    function getCategoryName(uint256 id) public view returns (string memory) {
        return categories.getCategoryName(id);
    }

    function addManager(string calldata name) public {
        token.transfer(msg.sender, INITIAL_TOKENS_ACTOR_VALUE);
        return actorsContract.addManager(msg.sender, Actors.Manager(name));
    }

    function addFunder(string calldata name) public {
        token.transfer(msg.sender, INITIAL_TOKENS_ACTOR_VALUE);
        return actorsContract.addFunder(msg.sender, Actors.Funder(name));
    }

    function addFreelancer(string calldata name, uint categoryId) public {
        token.transfer(msg.sender, INITIAL_TOKENS_ACTOR_VALUE);
        return actorsContract.addFreelancer(msg.sender, Actors.Freelancer(name, 5, categoryId));
    }

    function addEvaluator(string calldata name, uint categoryId) public {
        token.transfer(msg.sender, INITIAL_TOKENS_ACTOR_VALUE);
        return actorsContract.addEvaluator(msg.sender, Actors.Evaluator(name, categoryId));
    }

    function getActorType(address _address) public view returns (ActorsContract.ActorTypes) {
        return actorsContract.getActorType(_address);
    }

    // MANAGER METHODS:
    /*------------------------------------------------------------------------------------------*/
    function addTask(string calldata description, uint rewardFreelancer, uint rewardEvaluator, uint category_id)
        public
        restrictedTo(ActorsContract.ActorTypes.Manager)
        returns (uint256)
    {
        require(bytes(description).length > 0, "Description is empty!");
        require(rewardFreelancer > 0, "Freelancer reward is 0!");
        require(rewardEvaluator > 0, "Evaluator reward is 0!");
        require(
            categories.isValidCategoryId(category_id),
            "Category is wrong!"
        );

        uint256 taskId = indexTask;
        MarketTypes.TaskInfoWrapper storage taskAdditinoalInfo = tasks[taskId];
        taskAdditinoalInfo.data = MarketTypes.TaskInfo(description, rewardFreelancer, rewardEvaluator, category_id);
        taskAdditinoalInfo.manager = msg.sender;
        taskAdditinoalInfo.state = MarketTypes.TaskState.NotFunded;
        taskAdditinoalInfo.endTimestamp = 0;
         
        indexTask += 1;
        numberOfTasks += 1;
        emit TaskAdded(msg.sender, description, taskId);

        return taskId;
    }

    function removeTask(uint256 taskId)
        public
        restrictedToManagerParent(taskId)
        taskCurrentState(taskId, MarketTypes.TaskState.NotFunded)
    {
        MarketTypes.TaskInfoWrapper storage task = tasks[taskId];

        for (uint256 i = 0; i < task.fundingsData.funders.length; i++) {
            address funderAddr = task.fundingsData.funders[i];
            token.transfer(funderAddr, task.fundingsData.fundings[funderAddr]);
            //token.transferFrom(address(this), funderAddr, task.fundingsData.fundings[funderAddr]);
        }
        delete tasks[taskId];
        numberOfTasks -= 1;

        emit TaskRemoved(msg.sender, taskId);
    }

    function chooseEvaluator(uint taskId, address evaluator) 
        public
        restrictedToManagerParent(taskId)
        taskCurrentState(taskId, MarketTypes.TaskState.Funded)
    {        
        require(tasks[taskId].evaluator == address(0), "This task is aleady assigned to an evaluator!");
        
        require(actorsContract.getActorType(evaluator) == ActorsContract.ActorTypes.Evaluator, "No evalator registred for that address");
        require(actorsContract.getEvaluatorDetails(evaluator).categoryId ==  tasks[taskId].data.category_id, "Evaluator dont have expertize for this task!");

        tasks[taskId].evaluator = evaluator;
        tasks[taskId].endTimestamp = block.timestamp + TASK_DEFAULT_IMPLEMENT_TIME;
        tasks[taskId].state = MarketTypes.TaskState.WaitingFreelancer;

        emit evaluatorChoosed(taskId, evaluator);
    }

    function chooseFreelancer(uint taskId, uint freelancerIdx) 
        public restrictedToManagerParent(taskId) 
        taskCurrentState(taskId, MarketTypes.TaskState.WaitingFreelancer)
    {
        require(freelancerIdx < tasks[taskId].freelancers.length, "Freelancer number doesn't exist!");

        for (uint i=0; i<tasks[taskId].freelancers.length; i++){
            if( i != freelancerIdx) {
                token.transfer(tasks[taskId].freelancers[i], tasks[taskId].data.rewardEvaluator);
            }
        }
        tasks[taskId].freelancerChoosed = tasks[taskId].freelancers[freelancerIdx];
        tasks[taskId].state = MarketTypes.TaskState.InProgres;

        emit freelancerChoosed(taskId, tasks[taskId].freelancerChoosed);
    }

    function getFreelancerForTask(uint taskId)
        public view restrictedToManagerParent(taskId) 
        taskCurrentState(taskId, MarketTypes.TaskState.WaitingFreelancer)
        returns(Actors.Freelancer[] memory)
    {
        Actors.Freelancer[] memory ret_array = new Actors.Freelancer[](tasks[taskId].freelancers.length);      
        for (uint i=0; i < tasks[taskId].freelancers.length; i++)
        {
            ret_array[i] = actorsContract.getFreelancerDetails(tasks[taskId].freelancers[i]);
        }

        return ret_array;
    }

    function managerReview(uint taskId, bool arbitration) 
        public  
        restrictedToManagerParent(taskId) 
        taskCurrentState(taskId, MarketTypes.TaskState.Completed)
    {
        if (arbitration)
        {
            tasks[taskId].state = MarketTypes.TaskState.Evaluating;
        }
        else {
            uint reward = tasks[taskId].data.rewardEvaluator * 2 + tasks[taskId].data.rewardFreelancer;
            address freelancer = tasks[taskId].freelancerChoosed;
                        
            actorsContract.updateFreelancer(freelancer, true);
            token.transfer(freelancer, reward);
            tasks[taskId].state = MarketTypes.TaskState.Accepted;
        }
        emit managerReviewed(taskId, arbitration);
    }

    function getMyTasks()
        public view 
        restrictedTo(ActorsContract.ActorTypes.Manager)
        returns (uint[] memory)
    {
        uint my_task_count = 0;
        for (uint i =0; i < numberOfTasks; i++)
        {
            if(bytes(tasks[i].data.description).length > 0 && 
                tasks[i].state == MarketTypes.TaskState.Evaluating &&
                tasks[i].manager == msg.sender )
            {
                my_task_count += 1;
            }
        }

        uint[] memory tasks_ids = new uint[](my_task_count);
        uint idx = 0;
        for (uint i =0; i < numberOfTasks; i++)
        {
            if(bytes(tasks[i].data.description).length > 0  &&
                tasks[i].state == MarketTypes.TaskState.Evaluating &&
                tasks[i].manager == msg.sender)
            {
                tasks_ids[idx] = i;
                i++;
            }
        }
        return tasks_ids;
    }

    // funder
    /*------------------------------------------------------------------------------------------*/
    function fundTask(uint256 taskId, uint256 amount)
        public
        restrictedTo(ActorsContract.ActorTypes.Funder)
        taskCurrentState(taskId, MarketTypes.TaskState.NotFunded)
    {
        require(amount > 0, "Amount invalid!");

        uint256 amountAllowed = token.allowance(msg.sender, address(this));
        uint256 senderBalance = token.balanceOf(msg.sender);
        require(amountAllowed <= senderBalance, "Your balance is lower than the amount you want to spend!");
        require(amount <= amountAllowed, "Please grant me allowence first!");

        MarketTypes.TaskInfoWrapper storage task = tasks[taskId];
        uint256 targetAmount = task.data.rewardFreelancer +
            task.data.rewardEvaluator;
        
        if (amount > targetAmount - task.fundingsData.total_amount)
        {
            amount = targetAmount - task.fundingsData.total_amount;
        }

        token.transferFrom(msg.sender, address(this), amount);

        task.fundingsData.total_amount += amount;
        if (task.fundingsData.fundings[msg.sender] == 0) {
            task.fundingsData.funders.push(msg.sender);
        }
        task.fundingsData.fundings[msg.sender] += amount;
        emit TaskFunded(taskId, msg.sender, amount);

        if (task.fundingsData.total_amount == targetAmount) {
            tasks[taskId].state = MarketTypes.TaskState.Funded;
            emit TaskFundedTotal(taskId);
        }
    }

    function withdrawSponsorship(uint taskId)
        public
        restrictedTo(ActorsContract.ActorTypes.Funder)
        taskCurrentState(taskId, MarketTypes.TaskState.NotFunded)
    {
        MarketTypes.TaskInfoWrapper storage task = tasks[taskId];
        uint amount = task.fundingsData.fundings[msg.sender];
        require(amount > 0, "There are no founding to be returned!");

        token.transfer(msg.sender, amount);
        delete task.fundingsData.fundings[msg.sender];
        task.fundingsData.total_amount -= amount;

        // also remove from list of sponsors;
        for(uint i = 0; i < task.fundingsData.funders.length; i++){
            if(task.fundingsData.funders[i] == msg.sender){
                // put last element on index i and delete last element
                task.fundingsData.funders[i] = task.fundingsData.funders[task.fundingsData.funders.length - 1];
                task.fundingsData.funders.pop();
                break;
            }
        }

        emit fundsWithdrawn(taskId, msg.sender, amount);
    }

    // Freelancers interest methods :
    /* ------------------------------------------*/
    function getTasksWaitingFreelancer()
        public view
        returns (uint[] memory) 
    {
        uint task_available = 0;
        for (uint i =0; i < numberOfTasks; i++)
        {
            if(bytes(tasks[i].data.description).length > 0 && tasks[i].state == MarketTypes.TaskState.WaitingFreelancer)
            {
                task_available+=1;
            }
        }

        uint[] memory tasks_ids = new uint[](task_available);
        uint idx = 0;
        for (uint i =0; i < numberOfTasks; i++)
        {
            if(bytes(tasks[i].data.description).length > 0  && tasks[i].state == MarketTypes.TaskState.WaitingFreelancer)
            {
                tasks_ids[idx] = i;
                i++;
            }
        }
        return tasks_ids;
    }
    
    function applyTask(uint taskId) 
        public 
        restrictedTo(ActorsContract.ActorTypes.Freelancer) 
        taskCurrentState(taskId, MarketTypes.TaskState.WaitingFreelancer)
    {
       require(actorsContract.getFreelancerDetails(msg.sender).categoryId == tasks[taskId].data.category_id, "Not same category!");
       require(tasks[taskId].freelancersMapping[msg.sender] == false, "Already Applied!");

        uint amountAllowed = token.allowance(msg.sender, address(this));
        uint senderBalance = token.balanceOf(msg.sender);
        require(amountAllowed <= senderBalance, "Not allowed!");
        require(tasks[taskId].data.rewardEvaluator <= amountAllowed, "More than allowed!");
        token.transferFrom(msg.sender, address(this), tasks[taskId].data.rewardEvaluator);

        tasks[taskId].freelancersMapping[msg.sender] == true;
        tasks[taskId].freelancers.push(msg.sender);
        
        emit freelancerApplied(taskId, msg.sender);
    }

    function notifyTaskFinished(uint taskId) public 
        restrictedTo(ActorsContract.ActorTypes.Freelancer) 
        taskCurrentState(taskId, MarketTypes.TaskState.InProgres)
    {
        require(tasks[taskId].freelancerChoosed == msg.sender, "You are not allowed to mark this task as finished");
        tasks[taskId].state = MarketTypes.TaskState.Completed;

        emit taskCompleted(taskId);
    }

    // evaluator
    /* ------------------------------------------*/
    function getMyPendingReviews()
        public view
        restrictedTo(ActorsContract.ActorTypes.Evaluator) 
        returns (uint[] memory)
    {
        uint my_task_count = 0;
        for (uint i =0; i < numberOfTasks; i++)
        {
            if(bytes(tasks[i].data.description).length > 0 && 
                tasks[i].state == MarketTypes.TaskState.Evaluating &&
                tasks[i].evaluator == msg.sender )
            {
                my_task_count += 1;
            }
        }

        uint[] memory tasks_ids = new uint[](my_task_count);
        uint idx = 0;
        for (uint i =0; i < numberOfTasks; i++)
        {
            if(bytes(tasks[i].data.description).length > 0  &&
                tasks[i].state == MarketTypes.TaskState.Evaluating &&
                tasks[i].evaluator == msg.sender)
            {
                tasks_ids[idx] = i;
                i++;
            }
        }
        return tasks_ids;
    }

    function evaluatorReview(uint taskId, bool done) 
        public 
        restrictedTo(ActorsContract.ActorTypes.Evaluator) 
        taskCurrentState(taskId, MarketTypes.TaskState.Evaluating)
    {
        require(tasks[taskId].evaluator == msg.sender, "Your not evaluator of this task!");

        address freelancer = tasks[taskId].freelancerChoosed;
        address evaluator = tasks[taskId].evaluator;

        if (done){
            actorsContract.updateFreelancer(freelancer, true);
            token.transfer(freelancer, tasks[taskId].data.rewardEvaluator + tasks[taskId].data.rewardFreelancer);
            token.transfer(evaluator, tasks[taskId].data.rewardEvaluator);
            tasks[taskId].state = MarketTypes.TaskState.EvACK;
        } else {
            actorsContract.updateFreelancer(freelancer, false);
            MarketTypes.TaskInfoWrapper storage task = tasks[taskId];

            for(uint i = 0;i < task.fundingsData.funders.length; i++){
                address funderAddr = task.fundingsData.funders[i];
                token.transfer(funderAddr, task.fundingsData.fundings[funderAddr]);
            }
            token.transfer(evaluator, tasks[taskId].data.rewardEvaluator);
            tasks[taskId].state = MarketTypes.TaskState.EvRejected;
        }

        emit evaluatorReviewed(taskId, done);
    }
    /* ------------------------------------------*/
}
