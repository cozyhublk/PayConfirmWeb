const https = require('https');

const data = JSON.stringify({
    userId: 'shop_test',
    smsText: 'HNB Alert: A/C Credited Rs. 2,000.00.'
});

const options = {
    hostname: 'us-central1-payconfirmapp.cloudfunctions.net',
    path: '/swiftAlert',
    method: 'POST',
    headers: {
        'Content-Type': 'application/json',
        'Content-Length': data.length
    }
};

const req = https.request(options, (res) => {
    console.log(`STATUS: ${res.statusCode}`);
    res.setEncoding('utf8');
    res.on('data', (chunk) => {
        console.log(`BODY: ${chunk}`);
    });
});

req.on('error', (e) => {
    console.error(`problem with request: ${e.message}`);
});

req.write(data);
req.end();
