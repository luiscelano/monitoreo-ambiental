import { DynamoDBClient, PutItemCommand, DeleteItemCommand } from "@aws-sdk/client-dynamodb";

const db = new DynamoDBClient();
const table = "ws_connections";

export const handler = async (event) => {
  const connectionId = event.requestContext.connectionId;

  if (event.requestContext.routeKey === "$connect") {
    await db.send(new PutItemCommand({
      TableName: table,
      Item: { connection_id: { S: connectionId } }
    }));
  }

  if (event.requestContext.routeKey === "$disconnect") {
    await db.send(new DeleteItemCommand({
      TableName: table,
      Key: { connection_id: { S: connectionId } }
    }));
  }

  return { statusCode: 200 };
};
