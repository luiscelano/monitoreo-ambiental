import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, UpdateCommand } from "@aws-sdk/lib-dynamodb";

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

export const handler = async (event) => {
  console.log("Event received:", event);
    const body = JSON.parse(event.body);

    const { temperature, humidity, air_quality } = body;


    const command = new UpdateCommand({
        TableName: "iot_data",
        Key: {
            device_id: "arduino_remote",
            timestamp: 0,
        },
        UpdateExpression: "SET temperature = :temp, humidity = :hum, air_quality = :aq",
        ExpressionAttributeValues: {
            ":temp": temperature,
            ":hum": humidity,
            ":aq": air_quality
        },
        ReturnValues: "ALL_NEW",
    });

  try {
    await docClient.send(command);
    return {
      statusCode: 200,
      body: JSON.stringify({ message: "Data stored!" })
    };
  } catch (err) {
    console.error("Error saving data:", err);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: "Internal Server Error" })
    };
  }
};
