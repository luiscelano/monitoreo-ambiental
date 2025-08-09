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
  endpoint: "https://<your-websocket-id>.execute-api.us-east-1.amazonaws.com/$default"
});

export const handler = async (event) => {
  for (const record of event.Records) {
    if (record.eventName !== "INSERT") continue;

    const data = record.dynamodb.NewImage;
    const payload = {
      deviceId: data.deviceId.S,
      timestamp: data.timestamp.S,
      data: JSON.parse(data.data.S)
    };

    const connections = await db.send(new ScanCommand({ TableName: "connections" }));

    await Promise.all(
      connections.Items.map(conn =>
        wsClient.send(new PostToConnectionCommand({
          ConnectionId: conn.connectionId.S,
          Data: Buffer.from(JSON.stringify(payload))
        }))
      )
    );
  }
};
