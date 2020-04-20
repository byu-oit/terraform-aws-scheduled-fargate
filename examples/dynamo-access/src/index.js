const AWS = require('aws-sdk')
const dynamodb = new AWS.DynamoDB({ region: 'us-west-2' })

async function fetchDbData ()
{
  const dynamoParams = { TableName: process.env.DYNAMO_TABLE_NAME }
  try {
    const dynamoData = await dynamodb.scan(dynamoParams).promise()
    console.log(dynamoData.Count)
    // for (let data of dynamoData.Items) {
    //   console.log(data)
    // }
  } catch (err) {
    console.log(err, err.stack)
  }
}

fetchDbData()
