const REWARD_ADDRESS = '0x0e334A0a6aE3ecA8BAa000C35A887296248CEE8e';//todo
const FUNDATION_ADDRESS = '0x1250E38187Ff89d05f99F3fa0E324241bbE2120C';//todo
const BURN_ADDRESS = '0x0e334A0a6aE3ecA8BAa000C35A887296248CEE8e';//todo

// const unit = web3.utils.toBN(10 ** 18);

//todo  config earnLowerlimit need check before online
const GOF_VAULT = [
    { token : 'HBTC', symbol : 'HBTC', earnLowerlimit: 0},
    { token : 'HUSD', symbol : 'HUSD', earnLowerlimit: 0},
    { token : 'ETH', symbol : 'ETH', earnLowerlimit: 0},
    { token : 'USDT', symbol : 'USDT', earnLowerlimit: 0},
    { token : 'HBCH', symbol : 'HBCH', earnLowerlimit: 0},
    { token : 'HDOT', symbol : 'HDOT', earnLowerlimit: 0},
    { token : 'HLTC', symbol : 'HLTC', earnLowerlimit: 0},
]

const GOF_STRATEGY = [
    { pid : 0, token : 'HBTC', output: 'MDX'},
    { pid : 1, token : 'HUSD', output: 'MDX'},
    { pid : 2, token : 'ETH', output: 'MDX'},
    { pid : 3, token : 'USDT', output: 'MDX'},
    { pid : 4, token : 'HBCH', output: 'MDX'},
    { pid : 5, token : 'HDOT',output: 'MDX'},
    { pid : 6, token : 'HLTC', output: 'MDX'},
    { pid : 7, token : 'WHT', output: 'MDX'}
]

module.exports = {
    REWARD_ADDRESS,
    FUNDATION_ADDRESS,
    BURN_ADDRESS,
    GOF_VAULT,
    GOF_STRATEGY
}