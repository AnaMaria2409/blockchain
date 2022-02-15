// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;
pragma experimental ABIEncoderV2;

import "./Ownable.sol";
import "./Categories.sol";

library Actors{
    struct Manager{
        string name;
    }

    struct Funder{
        string name;
    }

    struct Freelancer{
        string name;
        uint8 reputation;
        uint categoryId;
    }

    struct Evaluator {
        string name;
        uint categoryId;
    }
}


contract ActorsContract is Ownable{
    Categories categories;
    uint256 internal actorsNumber = 0;
    
    enum ActorTypes {NotAssigned, Manager, Funder, Freelancer, Evaluator}
    mapping(address => ActorTypes) internal actorsMapping;
    mapping(address => Actors.Manager) internal managers;
    mapping(address => Actors.Funder) internal funders;
    mapping(address => Actors.Freelancer) internal freelancers;
    mapping(address => Actors.Evaluator) internal evaluators;

    // events
    event actorAdded(ActorTypes actor, string name, address address_);
    event freelancerModified(address freelancer, bool increase);

    // modifiers
    modifier notCreated(address _addr){
        require(actorsMapping[_addr] == ActorTypes.NotAssigned, "You are already registred!");
        _;
    }

    constructor(address categories_) {
        require(categories_ != address(0), "Your address is wrong!");
        categories = Categories(categories_);
    }

    function addManager(address _addr, Actors.Manager calldata _data) external notCreated(_addr){
        require(bytes(_data.name).length != 0, "Name is empty!");

        actorsMapping[_addr] = ActorTypes.Manager;
        managers[_addr] = Actors.Manager(
            {
                name : _data.name
            }
        );
        actorsNumber++;

        emit actorAdded(ActorTypes.Manager, _data.name, _addr);
    }
     
    function addFunder(address _addr, Actors.Funder calldata _data) external notCreated(_addr) {
        require(bytes(_data.name).length != 0, "Name is empty!");

        actorsMapping[_addr] = ActorTypes.Funder;
        funders[_addr] = Actors.Funder(
            {
                name : _data.name
            }
        );
        actorsNumber++;
        emit actorAdded(ActorTypes.Funder, _data.name, _addr);
    }

    function addEvaluator(address _addr, Actors.Evaluator calldata _data) external notCreated(_addr){
        require(bytes(_data.name).length != 0,  "Name is empty!");
        require(categories.isValidCategoryId(_data.categoryId), "Category doesn't exists!");
        
        actorsMapping[_addr] = ActorTypes.Evaluator;
        evaluators[_addr] = Actors.Evaluator(
            {
                name : _data.name,
                categoryId : _data.categoryId
            }
        );
        actorsNumber++;
        emit actorAdded(ActorTypes.Evaluator, _data.name, _addr);
    }

    function addFreelancer(address _addr, Actors.Freelancer calldata _data) external notCreated(_addr){
        require(bytes(_data.name).length != 0, "Name is empty!");
        require(categories.isValidCategoryId(_data.categoryId), "Category doesn't exists!");
        
        actorsMapping[_addr] = ActorTypes.Freelancer;
        freelancers[_addr] = Actors.Freelancer(
            {
                name : _data.name,
                reputation : 5,
                categoryId : _data.categoryId
            }
        );
        actorsNumber++;
        emit actorAdded(ActorTypes.Freelancer, _data.name, _addr);
    }

    function updateFreelancer(address _address, bool increase) public {
        if (increase) {
            if(freelancers[_address].reputation <= 9)
                freelancers[_address].reputation += 1;
        } else {
            if (freelancers[_address].reputation >= 2) 
            freelancers[_address].reputation -= 1;
        }
        emit freelancerModified(_address, increase);
    }       
   
    // getters 
    function getManagerDetails(address _address)public view returns(Actors.Manager memory){
        Actors.Manager memory data = managers[_address];
        assert(bytes(data.name).length != 0);

        return data;
    }

    function getFunderDetails(address _address)public view returns(Actors.Funder memory){
        Actors.Funder memory data = funders[_address];
        assert(bytes(data.name).length != 0);

        return data;
    }

    function getFreelancerDetails(address _address)public view returns(Actors.Freelancer memory){
        Actors.Freelancer memory data = freelancers[_address];
        assert(bytes(data.name).length != 0);

        return data;
    }

    function getEvaluatorDetails(address _address) public view returns(Actors.Evaluator memory){
        Actors.Evaluator memory data = evaluators[_address];
        assert(bytes(data.name).length != 0);
        
        return data;
    }


    function getActorType(address _address) public view returns(ActorTypes){
        return actorsMapping[_address];
    }


}