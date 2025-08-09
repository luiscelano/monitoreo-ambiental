import {
  DynamoDBClient,
  ScanCommand
} from "@aws-sdk/client-dynamodb";
import {
  ApiGatewayManagementApiClient,
  PostToConnectionCommand
} from "@aws-sdk/client-apigatewaymanagementapi";

const db = new DynamoDBClient();
const wsClient = new ApiGatewayManagementApiClient({
  endpoint: "https://108dpxfuq2.execute-api.us-east-1.amazonaws.com/$default"
});

export const handler = async (event) => {
  try {
    for (const record of event.Records) {

    const data = record.dynamodb.NewImage;
    const payload = {
      deviceId: data.device_id.S,
      timestamp: data.timestamp.S,
      temperature: data.temperature.N,
      humidity: data.humidity.N,
      air_quality: data.air_quality.N,

    };

    const connections = await db.send(new ScanCommand({ TableName: "ws_connections" }));

    await Promise.all(
      connections.Items.map(conn =>
        wsClient.send(new PostToConnectionCommand({
          ConnectionId: conn.connection_id.S,
          Data: Buffer.from(JSON.stringify(payload))
        }))
      )
    );
    console.log("success!");
  }
  } catch (error) {
    console.error('ws error:', error); 
  }
};
