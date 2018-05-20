pragma solidity ^0.4.19;

/// @title DigitalOption
/// @author legalblock
/// @notice Correctness or safety of code not warranted

contract DigitalOptionMaster {

	event StateUpdate(string stateMessage);
	event Error(string errorMessage);
	event Arbitration(string arbitrationMessage);

	address buyer;
	address seller;
	address oracle;
	address arbitrator;

	uint public principal;
	uint public interest;
	
	uint public activeTime;
	uint public exerciseStart;
	uint public exerciseExpiry;
	
	uint public strikePrice;
	uint public finalPrice;

	uint public oracleFee;
	uint public arbitrationFee;

	uint public buyerPositionPrice; 
	uint public sellerPositionPrice;

	bool public optionBought;
	bool public buyerPositionOffered;
	bool public sellerPositionOffered;
	bool public arbitrationRequested;

	constructor() payable {

		oracle = 0x4b0897b0513fdc7c541b6d9d7e929c4e5364d2db;
		arbitrator = 0x583031d1113ad414f02576bd6afabfb302140225; 

		oracleFee = 0.1 ether;
		arbitrationFee = 0.2 ether;
			
		principal = msg.value - oracleFee; // e.g. 10.1 - 0.1 ether

		activeTime = now; // clock starts when transaction mined
		exerciseExpiry = exerciseStart + 1 days;

		optionBought = false;
		buyerPositionOffered = false;
		sellerPositionOffered = false;		
		arbitrationRequested = false;

		emit StateUpdate("active");

	}

	// Modifiers restrict function calls (syntax = underscore)
	
	   // Parties

	modifier only_buyer {
		require (msg.sender == buyer); 
		_;
	}

	modifier only_seller {
		require (msg.sender == seller); 
		_;
	}
	
	modifier only_parties {
	    require (msg.sender == seller || msg.sender == buyer);
	    _;
	}

	modifier only_oracle {
		require (msg.sender == oracle);
		_;
	}

	modifier only_arbitrator {
		require (msg.sender == arbitrator);
		_;
	}
	
	    // Contract state
	

	modifier option_not_bought {
		require (optionBought == false);
		_;
	}
	
	modifier buyer_position_offered {
		require (buyerPositionOffered == true); 
		_;
	}

	modifier seller_position_offered {
		require (sellerPositionOffered == true);
		_;
	}

	modifier arbitration_requested {
	    require (arbitrationRequested == true);
	    _;
	}
	
	modifier arbitration_not_requested {
	    require (arbitrationRequested == false);
	    _;
	} 
	
	    // Timing

	modifier from_expiry {
	    require (now >= exerciseStart && now <= exerciseExpiry);
	    _;
	}

	modifier after_oracle {
		_;
	}

	modifier before_exerciseExpiry {
		require (now < exerciseExpiry);
		_;
	}
    
	// Seller functions

    function transferSeller(address _newSeller) only_seller {
    	seller = _newSeller;
    }

    function offerSellerPosition(uint _amount) only_seller {
    	sellerPositionPrice = _amount;
    }

    function sellerClaimFunds() only_seller after_oracle { 
    	if (finalPrice >= strikePrice) {
    		seller.transfer(principal - principal * strikePrice/finalPrice);
    	}
    	else {
    		seller.transfer(principal);
    	}
    }

	// Buyer functions

		// Buyer transfers interest to seller

    function buyOption() payable option_not_bought { 
     	if (interest == msg.value) {
     	    seller.transfer(msg.value);
     	    buyer = msg.sender;
     	    optionBought = true;
     	    emit StateUpdate("Option bought");
     	}
     	else {
     	    emit Error("Invalid interest");
     	    revert();  
     	}
    }

    function offerBuyerPosition(uint _amount) only_buyer {
    	buyerPositionPrice = _amount;
    	buyerPositionOffered = true;
    }

    function transferBuyer(address _newBuyer) only_buyer {
    	buyer = _newBuyer;
    }


    function buyerClaimFunds() only_buyer after_oracle before_exerciseExpiry {
    	if (finalPrice >= strikePrice) {
    		buyer.transfer(principal * strikePrice/finalPrice);
    	}
    	else {
    		revert("You get fuck all");
    	}
    } 

	// Either party functions

    function requestArbitration() payable only_parties {
        if (msg.value == arbitrationFee) {
        arbitrationRequested = true;
        emit Arbitration("Arbitration has been requested");
        }
        else {
            revert();
        }
    }

    // Third party functions

    function takeSellerPosition() payable seller_position_offered {
    	if (msg.value == sellerPositionPrice) {
    		seller.transfer(msg.value);
    		seller = msg.sender;
    		sellerPositionOffered = false;
    	}
    	else {
    	    revert();
    	}
    }

    function takeBuyerPosition() payable buyer_position_offered {  
    	if (msg.value == buyerPositionPrice) {
    		buyer.transfer(msg.value);
    		buyer = msg.sender;
    		buyerPositionOffered = false;
    	}
    	else {
    	    revert();
    	}
    }

	// Oracle functions

    function feedPrice(uint _finalPrice) only_oracle {
        finalPrice = _finalPrice;
        if (finalPrice >= strikePrice) {
            emit StateUpdate ("Buyer In The Money");
        }
        else {
            emit StateUpdate ("Seller Gets Principal");
        }
    }

	// Arbitrator functions

    function checkSeller() only_arbitrator arbitration_requested view returns (address) { 
        return seller;
    }
    
    function checkBuyer() only_arbitrator arbitration_requested view returns (address) {
        return buyer;
    }

    function terminate() only_arbitrator arbitration_requested {
    	selfdestruct(arbitrator);
    }
}

// withdraw offers to sell? Role of arbitration.. event vs revert... require why error... add oracle fee.. finish if statements