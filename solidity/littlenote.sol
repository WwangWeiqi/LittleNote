pragma solidity ^0.4.21;
// pragma experimental ABIEncoderV2;
//Xinle Yang
//The full contract handling betting and rewarding.

//TODO:
//1) add voting part.
//2) add possibility to do upgrade.

contract LittleNote {

    address public founder;

    bool public haltFlag;
    bool public anybodyAddOtherUser;
    uint256 public MaxUserNameLength = 20;
    uint256 public MaxNoteLength = 128;
    uint256 public MaxFreeNoteCount = 1;

    uint256 public MinPrice = 25 * 10 ** 18;
    uint256 public MaxPrice = 4 * 10 ** 29;
    uint256 public ratio = 130;
    uint256 public MaxPresetPricePower = 100;

    uint256[] public PriceTable;

    uint256 public potReserve = 0;
    uint256 public feesAndCharity = 0;
    uint256 public threshold = 16384 * 10 ** 18;
    uint256 public totalPurchase = 0;
    uint256 public developerAmount = 0;
    uint256 public lastPurchaseTime;
    uint256 public potDistCountLimit = 500;
    uint256 public potDistBasisPointLimit = 50;
    uint256 public mediaRate = 10;

    //lat and lng:
    //1) both are turned into positive numbers by adding 360 to each.
    //2) both will be multiplied by 10**16
    struct Note {
        string _id;
        address userAddress;
        string note;
        uint256 lat;
        uint256 lng;
        uint256 grid;
        uint256 grid10;
        bool forSell;
        uint256 purchasePrice;
        address referral;
        uint256 createdAt;
        bool mediaFlag;
    }

    struct Account {
        address userAddress;
        string userName;
        uint256 noteNumber;
    }

    mapping (address => Account) private accounts;
    mapping (string => uint256) private accountsByUserName;
    address[] public accountsArray;

    mapping (string => Note) private notes;
    string[] public notesArray;
    uint256[] public notesArrayByTime;
    mapping (uint256 => uint256) private notesCountByGrid10;
    mapping (uint256 => string[]) private notesIdByGrid10;
    string[] public potNotesId;

    mapping (uint256 => uint256) private hourlyPotReserves;
    uint256[] public hourlyPotReservesArray;

    mapping (address => uint256) private investors;
    address[] public investorsArray; 
    uint256 totalInvestment = 0;

    function LittleNote(address _founder) public {
        founder = _founder;
        haltFlag = false;
        initPriceTable();
    }

    function SetHalt(bool halt) public {
        if (msg.sender != founder) revert();
        haltFlag = halt;
    }

    function SetFounder(address newFounder) public returns (bool) {
        if (msg.sender != founder) revert();
        founder = newFounder;
        return true;
    }

    function AddAccount(string userName, address userAddress) public returns (bool) {
        if (bytes(userName).length > MaxUserNameLength) {
            revert();
        }
        if (msg.sender != userAddress && (msg.sender != founder && !anybodyAddOtherUser)) {
            revert();
        }
        if (accounts[userAddress].userAddress == 0 && accountsByUserName[userName] == 0) {
            accounts[userAddress].userAddress = userAddress;
            accounts[userAddress].userName = userName;
            accounts[userAddress].noteNumber = 0;
            uint256 length = accountsArray.push(userAddress);
            accountsByUserName[userName] = length; //length is (index + 1)
            return true;
        } else {
            return false;
        }
    }

    function Invest() public payable {
        address investor = msg.sender;
        if (investors[investor] == 0) {
            investorsArray.push(investor);
        }
        investors[investor] += msg.value;
        totalInvestment += msg.value;
        uint256 potReserveAdd = msg.value / 2;
        potReserve += potReserveAdd;
        if (msg.value > potReserveAdd) {
            feesAndCharity += msg.value - potReserveAdd;
        }
    }

    function AddNote(string noteText, uint256 lat, uint256 lng, string _id, bool forSell, address referral, bool mediaFlag) public payable {
        if (accounts[msg.sender].userAddress == 0 || bytes(noteText).length > MaxNoteLength) {
            revert();
        }
        uint256 grid10 = getGrid10(lat, lng);
        bool freeFlag = true;
        if (notesCountByGrid10[grid10] > 0 || accounts[msg.sender].noteNumber > MaxFreeNoteCount) {
            freeFlag = false;
        }
        bool newFlag = true;
        uint256 price = getPrice(freeFlag, newFlag, grid10, mediaFlag);
        if (!freeFlag && msg.value < price) {
            revert();
        } else {
            distributePayment(referral, grid10, 0, 0);
        }
        if (notes[_id].createdAt == 0) {
            uint256 grid = getGrid(lat, lng);
            notesArray.push(_id);
            notes[_id]._id = _id;
            notes[_id].userAddress = msg.sender;
            notes[_id].note = noteText;
            notes[_id].lat = lat;
            notes[_id].lng = lng;
            notes[_id].grid = grid;
            notes[_id].grid10 = grid10;
            notes[_id].forSell = forSell;
            notes[_id].referral = referral;
            notes[_id].mediaFlag = mediaFlag;
            notes[_id].createdAt = now;
            lastPurchaseTime = now;
            notesCountByGrid10[grid10]++;
            string[] notesId = notesIdByGrid10[grid10];
            notesId.push(_id);
            notesIdByGrid10[grid10] = notesId;
            potNotesId.push(_id);
            notesArrayByTime.push(lastPurchaseTime);
        }
    }

    function BuyNote(string noteText, uint256 lat, uint256 lng, string _id, bool forSell, address referral, bool mediaFlag) public payable {
        if (notes[_id].createdAt == 0 || !notes[_id].forSell || accounts[msg.sender].userAddress == 0 || bytes(noteText).length > MaxNoteLength) {
            revert();
        }
        uint256 grid10 = getGrid10(lat, lng);
        bool freeFlag = true;
        if (notesCountByGrid10[grid10] > 0 || accounts[msg.sender].noteNumber > MaxFreeNoteCount) {
            freeFlag = false;
        }
        bool newFlag = false;
        uint256 price = getPrice(freeFlag, newFlag, grid10, mediaFlag);
        if (!freeFlag && msg.value < price) {
            revert();
        } else {
            distributePayment(referral, grid10, notes[_id].userAddress, notes[_id].purchasePrice);
        }
        uint256 grid = getGrid(lat, lng);
        notes[_id]._id = _id;
        notes[_id].userAddress = msg.sender;
        notes[_id].note = noteText;
        notes[_id].lat = lat;
        notes[_id].lng = lng;
        notes[_id].grid = grid;
        notes[_id].grid10 = grid10;
        notes[_id].referral = referral;
        notes[_id].forSell = forSell;
        notes[_id].mediaFlag = mediaFlag;
        notes[_id].createdAt = now;
        lastPurchaseTime = now;
        potNotesId.push(_id);
        notesArrayByTime.push(lastPurchaseTime);
    }

    function ToggleSell(string _id, bool forSell) public {
        if (notes[_id].createdAt == 0) {
            revert();
        }
        Note note = notes[_id];
        if (note.userAddress != msg.sender || note.userAddress != founder) {
            revert();
        }
        note.forSell = forSell;
    }

    function EditNote(string noteText, uint256 lat, uint256 lng, string _id, bool forSell) public {
        if (msg.sender != founder || notes[_id].createdAt == 0) {
            revert();
        }
        notes[_id].note = noteText;
        notes[_id].forSell = forSell;
        notes[_id].createdAt = now;
    }

    function getGrid10(uint256 lat, uint256 lng) public returns (uint256) {
        uint256 grid10 = lat/100000000000000*100000 + lng/100000000000000;
        return grid10;
    }

    function getGrid(uint256 lat, uint256 lng) public returns (uint256) {
        uint256 grid = lat/10000000000000*1000000 + lng/10000000000000;
        return grid;
    }

    function getPrice(bool freeFlag, bool newFlag, uint grid10, bool mediaFlag) public returns (uint256) {
        uint256 count = notesCountByGrid10[grid10];

        if (newFlag) {
            if (count == 0) {
                if (freeFlag) {
                    return 0;
                } else {
                    return MinPrice;
                }
            } else {
                count++;
            }
        } else {
            if (count == 0) {
                count++;
            }
        }

        uint256 price = 0;
        if (count <= MaxPresetPricePower && PriceTable.length > count) {
            price = PriceTable[count];
        } else {
            price = getBigPrice(count - MaxPresetPricePower);
        }

        if (mediaFlag) {
            if (price == 0) {
                price = MinPrice;
            }
            price *= mediaRate;
        }

        return price;
    }

    function initPriceTable() public {
        if (PriceTable.length > 0) {
            delete PriceTable;
        }
        uint256 price = MinPrice;
        for (uint i=0; i<=MaxPresetPricePower; i++) {
            PriceTable.push(price);
            price = multiplyByRatio(price);
            if (price > MaxPrice) {
                price = MaxPrice;
            }
        }
    }

    function getBigPrice(uint n) public returns (uint256) {
        if (PriceTable.length <= MaxPresetPricePower) {
            initPriceTable();
        }
        uint256 price = PriceTable[MaxPresetPricePower];
        uint256 tempPrice;
        for (uint256 i=0; i<n; i++) {
            tempPrice = price * ratio / 100;
            if (tempPrice < price) {
                tempPrice = price;
            }
            price = tempPrice;
        }
        if (price > MaxPrice) {
            price = MaxPrice;
        }

        return price;
    }

    function getAccount(address accountAddress) public view returns (address, string, uint256) {
        Account account = accounts[accountAddress];
        return (account.userAddress, account.userName, account.noteNumber);
    }

    function getAccountByName(string name) public view returns (uint256) {
        return accountsByUserName[name];
    }

    function getNote(string _id) public view returns (string, address, string, uint256, uint256, uint256, uint256, bool, uint256, address, uint256) {
        Note note = notes[_id];
        return (note._id, note.userAddress, note.note, note.lat, note.lng, note.grid, note.grid10, note.forSell, note.purchasePrice, note.referral, note.createdAt);
    }

    function getNotesCountByGrid10(uint256 grid10) public view returns (uint256) {
        return notesCountByGrid10[grid10];
    }

    function getNotesIdByGrid10(uint256 grid10, uint256 index) public view returns (string) {
        return notesIdByGrid10[grid10][index];
    }

    function getHourlyPotReserves(uint256 hourNumber) public view returns (uint256) {
        return hourlyPotReserves[hourNumber];
    }

    function getInvestor(address investor) public view returns (uint256) {
        return investors[investor];
    }

    function multiplyByRatio(uint256 input) public returns (uint256) {
        uint256 output = input * ratio / 100;
        return output;
    }

    function sellerDistribution(uint256 totalMoney, uint256 availableMoney, uint256 sellerCost, address seller) public returns (uint256) {
        //0) Seller will retain the purchasing cost and receive 75% of the profit
        uint256 sellerTake;
        if (totalMoney > sellerCost) {
            sellerTake = sellerCost + (totalMoney - sellerCost) * 75 / 100;
        } else {
            sellerTake = totalMoney;
        }
        if (availableMoney < sellerTake) {
            sellerTake = availableMoney;
        }
        availableMoney -= sellerTake;
        seller.send(sellerTake);
        return availableMoney;
    }

    function gridPatronDistribution(uint256 totalMoney, uint256 availableMoney, uint256 grid10) public returns (uint256) {
        //1) 20% patron bonus
        // 1.1) 20% to patrons in this grid10
        if (notesIdByGrid10[grid10].length != 0 ) {
            uint256 grid10TotalPatronBonus = totalMoney * 20 / 100;
            uint256 grid10Len = notesIdByGrid10[grid10].length;
            uint256 grid10Bonus = grid10TotalPatronBonus / grid10Len;
            for (uint256 i=0; i<grid10Len; i++) {
                string _id = notesIdByGrid10[grid10][i];

                if (availableMoney < grid10Bonus) {
                    grid10Bonus = availableMoney;
                }
                availableMoney -= grid10Bonus;
                if (notes[_id].userAddress != 0) {
                    notes[_id].userAddress.send(grid10Bonus);
                }
            }
        }

        return availableMoney;
    }

    function allPatronDistribution(uint256 totalMoney, uint256 availableMoney) public returns (uint256) {
        // 1.2) 20% to all patrons
        if (notesArray.length != 0) {
            uint256 allPatronBonus = totalMoney * 20 / 100;
            uint256 arrayLen = notesArray.length;
            uint256 patronBonus = allPatronBonus / arrayLen;
            for (uint256 i=0; i<arrayLen; i++) {
                // noteId = notesArray[i];
                if (availableMoney < patronBonus) {
                    patronBonus = availableMoney;
                }
                availableMoney -= patronBonus;
                notes[notesArray[i]].userAddress.send(patronBonus);
            }
        }

        return availableMoney;
    }

    function updatePotReserves(uint256 totalMoney, uint256 availableMoney) public returns (uint256) {
        // 2) 20% last note pot
        uint256 addition= totalMoney * 20 / 100;
        potReserve += addition;
        if (availableMoney > addition) {
            addition = availableMoney;
        }
        availableMoney -= addition;
        return availableMoney;
    }

    function distributeReferral(uint256 totalMoney, uint256 availableMoney, address referral) public returns (uint256) {
        // 3） 8% referral reward
        uint256 referralReward = totalMoney * 8 / 100;
        if (availableMoney < referralReward) {
            referralReward = availableMoney;
        }
        availableMoney -= referralReward;
        referral.send(referralReward);
        return availableMoney;
    }

    function devTeamDistribution(uint256 totalMoney, uint256 availableMoney) public returns (uint256) {
        // 4） 15% developer team
        uint256 developerShare = totalMoney * 15 / 100;
        if (availableMoney < developerShare) {
            developerShare = availableMoney;
        }
        availableMoney -= developerShare;
        developerAmount += developerShare;
        return availableMoney;
    }

    function investorDistribution(uint256 totalMoney, uint256 availableMoney) public returns (uint256) {
        // 5） 8% investors
        uint256 investorShare = totalMoney * 8 / 100;

        uint256 uintShare = investorShare / totalInvestment;
        uint256 len = investorsArray.length; 
        for (uint256 i=0; i<len; i++) {
            address investor = investorsArray[i];
            uint256 amount = investors[investor] * uintShare;
            investor.send(amount);
            if (availableMoney < amount) {
                amount = availableMoney;
            }
            availableMoney -= amount;
        }

        return availableMoney;
    }

    function feesAndCharityReserve(uint256 availableMoney) public returns (uint256) {
        feesAndCharity += availableMoney;
        return 0;
    }

    function distributePayment(address referral, uint256 grid10, address seller, uint256 sellerCost) public payable {
        uint256 totalMoney = msg.value;
        uint256 availableMoney = totalMoney;

        //0) Seller will retain the purchasing cost and receive 75% of the profit
        availableMoney = sellerDistribution(totalMoney, availableMoney, sellerCost, seller);

        //1) 40% patron bonus
        // 1.1) 20% to patrons in this grid10
        availableMoney = gridPatronDistribution(totalMoney, availableMoney, grid10);

        // 1.2) 20% to all patrons
        availableMoney = allPatronDistribution(totalMoney, availableMoney);

        // 2) 20% last note pot
        availableMoney = updatePotReserves(totalMoney, availableMoney);

        // 3） 8% referral reward
        availableMoney = distributeReferral(totalMoney, availableMoney, referral);

        // 4） 15% developer team
        availableMoney = devTeamDistribution(totalMoney, availableMoney);

        // 5） 8% investors
        availableMoney = investorDistribution(totalMoney, availableMoney);

        // 6） 9% other fees and charity
        availableMoney = feesAndCharityReserve(availableMoney);

    }

    function distributePotReserve() public {
        if (canDistributePotReserve()) {
            uint256 lastNotesCount = 5;
            uint256 len = notesArray.length;
            if (lastNotesCount > len) {
                lastNotesCount = len;
            }
            uint256 distributeAmount = potReserve / 2 / lastNotesCount;
            for (uint256 i = 0; i<lastNotesCount; i++) {
                string _id = notesArray[len - i - 1];
                address userAddress = notes[_id].userAddress;
                userAddress.send(distributeAmount);
            }
        }
    }

    function last24HourCount() public view returns (uint256) {
        uint256 len = notesArrayByTime.length;
        if (len == 0) {
            return 0;
        }

        for (uint256 i = len - 1; i >= 0; i--) {
            if (notesArrayByTime[i] - now > 1 days) {
                return len - i -1;
            }
        } 

        return len;
    }

    function last24HourBasisPoint() public view returns (uint256) {
        uint256 count = last24HourCount();
        uint256 baseCount = notesArrayByTime.length - count;
        if (baseCount == 0) {
            return 1000000;
        }
        uint256 basisPoint = count * 100 / baseCount;
        return basisPoint;
    }

    function canDistributePotReserve() public view returns (bool) {
        if (potReserve >= threshold && last24HourCount() < potDistCountLimit) {
            if (last24HourBasisPoint() < potDistBasisPointLimit) {
                return true;
            }
        }
        return false;
    }

    function deleteHourlyPotReserves() private {
        uint256 len = hourlyPotReservesArray.length;
        for (uint256 i=0; i<len; i++) {
            delete hourlyPotReserves[hourlyPotReservesArray[i]];
        }

        delete hourlyPotReservesArray;
    }

    function ManualTransfer(uint256 amount, address to) public {
        if (msg.sender != founder) revert();

        to.transfer(amount);
    }

    function SafetySendout(uint256 amount) public {
        if (msg.sender != founder) revert();

        founder.transfer(amount);
    }

    function () public payable {
    }

    //TODO: more to add
}
