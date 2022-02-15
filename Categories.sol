// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;
pragma experimental ABIEncoderV2;

import "./Ownable.sol";

contract Categories is Ownable {

    struct category {
        uint id;
        string c_name;
    }

    uint internal m_next_id;
    category[] internal m_categories;

    event CategoryAdded(uint id, string name);

    constructor(){
        m_next_id = 0;
    }

    function addCategory(string memory name) public returns (uint){
        require(bytes(name).length > 0, "invalid category name");
        
        uint id = m_next_id;
        category memory categoryVar = category(id, name);
        m_categories.push(categoryVar);
        m_next_id += 1;
        
        emit CategoryAdded(id, name);
        return id;
    }

    function getCategoryName(uint id) public view returns(string memory){
        require(isValidCategoryId(id), "invalid id");
        return m_categories[id].c_name;
    }

    function isValidCategoryId(uint id) public view returns(bool){
        return id < m_next_id;
    }

    function getCategoriesCount() public view returns(uint){
        return m_next_id;
    }

    function getCategories() external view returns(category[] memory){
        return m_categories;
    }

        function getCategoriesNames() external view returns(string[] memory){
        string[] memory categArr = new string[](m_next_id);
        for(uint i = 0; i < m_next_id; i++){
            categArr[i] = m_categories[i].c_name;
        }
        return categArr;
    }
}