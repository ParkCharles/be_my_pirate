// ExpressJS Setup
const express = require('express');
const app = express();

// Hyperledger Bridge
const { FileSystemWallet, Gateway } = require('fabric-network');
const fs = require('fs');
const path = require('path');
const ccpPath = path.resolve(__dirname, '..', 'network' ,'connection.json');
const ccpJSON = fs.readFileSync(ccpPath, 'utf8');
const ccp = JSON.parse(ccpJSON);

// Constants
const PORT = 8080;
const HOST = '0.0.0.0';

// use static file
app.use(express.static(path.join(__dirname, 'views')));

// configure app to use body-parser
app.use(express.json());
app.use(express.urlencoded({ extended: false }));

// main page routing
app.get('/', (req, res)=>{
    res.sendFile(__dirname + '/index.html');
})

async function cc_call(fn_name, args){
    
    const walletPath = path.join(process.cwd(), 'wallet');
    const wallet = new FileSystemWallet(walletPath);

    const userExists = await wallet.exists('user1');
    if (!userExists) {
        console.log('An identity for the user "user1" does not exist in the wallet');
        console.log('Run the registerUser.js application before retrying');
        return;
    }
    const gateway = new Gateway();
    await gateway.connect(ccp, { wallet, identity: 'user1', discovery: { enabled: false } });
    const network = await gateway.getNetwork('mychannel');
    const contract = network.getContract('be_my_pirate');

    var result;
    
    if(fn_name == 'addUser')
        result = await contract.submitTransaction('addUser', args);
    else if( fn_name == 'addRating')
    {
        e=args[0];
        p=args[1];
        s=args[2];
        result = await contract.submitTransaction('addRating', e, p, s);
    }
    else if(fn_name == 'readRating')
        result = await contract.evaluateTransaction('readRating', args);
    else
        result = 'not supported function'

    return result;
}

// create pirate
app.post('/pirate', async(req, res)=>{
    const email = req.body.email;
    console.log("add pirate email: " + email);

    result = cc_call('addUser', email)

    const myobj = {result: "success"}
    res.status(200).json(myobj) 
})

// add price
app.post('/price', async(req, res)=>{
    const email = req.body.email;
    const tre = req.body.treasure;
    const sc = req.body.price;
    console.log("add pirate email: " + email);
    console.log("add treasure name: " + tre);
    console.log("add treasure price: " + sc);

    var args=[email, tre, sc];
    result = cc_call('addRating', args)

    const myobj = {result: "success"}
    res.status(200).json(myobj) 
})

// find pirate
app.post('/pirate/:email', async (req,res)=>{
    const email = req.body.email;
    console.log("email: " + req.body.email);
    const walletPath = path.join(process.cwd(), 'wallet');
    const wallet = new FileSystemWallet(walletPath);
    console.log(`Wallet path: ${walletPath}`);

    // Check to see if we've already enrolled the user.
    const userExists = await wallet.exists('user1');
    if (!userExists) {
        console.log('An identity for the user "user1" does not exist in the wallet');
        console.log('Run the registerUser.js application before retrying');
        return;
    }
    const gateway = new Gateway();
    await gateway.connect(ccp, { wallet, identity: 'user1', discovery: { enabled: false } });
    const network = await gateway.getNetwork('mychannel');
    const contract = network.getContract('be_my_pirate');
    const result = await contract.evaluateTransaction('readRating', email);
    const myobj = JSON.parse(result)
    res.status(200).json(myobj)
    // res.status(200).json(result)

});

// server start
app.listen(PORT, HOST);
console.log(`Running on http://${HOST}:${PORT}`);
