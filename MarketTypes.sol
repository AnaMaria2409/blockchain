// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;
pragma experimental ABIEncoderV2;

library MarketTypes
{
    enum TaskState 
    { 
        Unknown,
        NotFunded,
        Funded,
        WaitingFreelancer, 
        InProgres, 
        Completed, 
        Accepted, 
        Evaluating, 
        EvACK, 
        EvRejected, 
        TimeoutOnHiring, 
        TimeoutOnEvaluation
    }

    struct TaskInfo
    {
        string  description;
        uint    rewardFreelancer;
        uint    rewardEvaluator;
        uint    category_id;
    }
    
    struct TaskInfoWrapper
    {
        uint              id;
        TaskInfo          data;
        TaskState         state;
        address           manager;
        address           evaluator;
        address           freelancerChoosed;
        Funding           fundingsData;
        mapping(address => bool) freelancersMapping;
        address[]           freelancers;
        uint256           endTimestamp;
    }

    struct Funding
    {
        address[] funders;
        mapping(address => uint) fundings;
        uint total_amount;
    }
}