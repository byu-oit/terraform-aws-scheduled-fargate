const AWS = require('aws-sdk')
const dynamodb = new AWS.DynamoDB({ region: 'us-west-2' })
const fs = require('fs')

async function run ()
{
  const dynamoParams = { TableName: process.env.DYNAMO_TABLE_NAME }
  try {
    const dynamoData = await dynamodb.scan(dynamoParams).promise()
    console.log(`dynamo scan db count: ${dynamoData.Count}`)

    fs.mkdirSync('/usr/app/data', {recursive: true})
    fs.appendFileSync('/usr/app/data/test-efs.txt', `scheduled process ran: ${Date.now()}\n`, 'utf8')
    const fileContents = fs.readFileSync('/usr/app/data/test-efs.txt', 'utf8')
    console.log('test-efs.txt file:')
    console.log(fileContents)
  } catch (err) {
    console.log(err, err.stack)
  }
}

run()
