const AWS = require('aws-sdk');
const { SESv2 } = require('aws-sdk');
const { SNS } = require('aws-sdk');

const ses = new SESv2({ region: process.env.AWS_REGION });
const sns = new SNS({ region: process.env.AWS_REGION });

exports.handler = async (event) => {
    console.log('Notification service triggered:', JSON.stringify(event, null, 2));
    
    try {
        const notifications = Array.isArray(event.Records) ? event.Records : [event];
        
        const results = await Promise.allSettled(
            notifications.map(async (record) => {
                const message = JSON.parse(record.body || record.Message || JSON.stringify(record));
                
                switch (message.type) {
                    case 'email':
                        return await sendEmail(message);
                    case 'push':
                        return await sendPushNotification(message);
                    case 'sms':
                        return await sendSMS(message);
                    case 'websocket':
                        return await sendWebSocketMessage(message);
                    default:
                        throw new Error(`Unknown notification type: ${message.type}`);
                }
            })
        );
        
        const successful = results.filter(r => r.status === 'fulfilled').length;
        const failed = results.filter(r => r.status === 'rejected').length;
        
        console.log(`Processed ${notifications.length} notifications: ${successful} successful, ${failed} failed`);
        
        return {
            statusCode: 200,
            body: JSON.stringify({
                processed: notifications.length,
                successful,
                failed,
                results: results.map(r => r.status === 'rejected' ? r.reason.message : 'success')
            })
        };
        
    } catch (error) {
        console.error('Error processing notifications:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: error.message })
        };
    }
};

async function sendEmail(notification) {
    const params = {
        FromEmailAddress: process.env.FROM_EMAIL || 'noreply@cnnchile.com',
        Destination: {
            ToAddresses: [notification.recipient]
        },
        Content: {
            Simple: {
                Subject: {
                    Data: notification.subject,
                    Charset: 'UTF-8'
                },
                Body: {
                    Html: {
                        Data: notification.htmlBody || notification.body,
                        Charset: 'UTF-8'
                    },
                    Text: {
                        Data: notification.textBody || notification.body,
                        Charset: 'UTF-8'
                    }
                }
            }
        }
    };
    
    const result = await ses.sendEmail(params).promise();
    console.log('Email sent:', result.MessageId);
    return result;
}

async function sendPushNotification(notification) {
    // Integrate with FCM or SNS for push notifications
    const params = {
        TopicArn: process.env.PUSH_TOPIC_ARN,
        Message: JSON.stringify({
            default: notification.body,
            GCM: JSON.stringify({
                data: {
                    title: notification.title,
                    body: notification.body,
                    ...notification.data
                }
            }),
            APNS: JSON.stringify({
                aps: {
                    alert: {
                        title: notification.title,
                        body: notification.body
                    },
                    sound: 'default'
                },
                ...notification.data
            })
        }),
        MessageStructure: 'json'
    };
    
    const result = await sns.publish(params).promise();
    console.log('Push notification sent:', result.MessageId);
    return result;
}

async function sendSMS(notification) {
    const params = {
        PhoneNumber: notification.phoneNumber,
        Message: notification.body
    };
    
    const result = await sns.publish(params).promise();
    console.log('SMS sent:', result.MessageId);
    return result;
}

async function sendWebSocketMessage(notification) {
    const apiGateway = new AWS.ApiGatewayManagementApi({
        apiVersion: '2018-11-29',
        endpoint: process.env.WEBSOCKET_ENDPOINT
    });
    
    const params = {
        ConnectionId: notification.connectionId,
        Data: JSON.stringify({
            type: notification.messageType || 'notification',
            data: notification.data || { message: notification.body }
        })
    };
    
    const result = await apiGateway.postToConnection(params).promise();
    console.log('WebSocket message sent to:', notification.connectionId);
    return result;
}
