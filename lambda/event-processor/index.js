const AWS = require('aws-sdk');

const dynamodb = new AWS.DynamoDB.DocumentClient();
const lambda = new AWS.Lambda();
const eventBridge = new AWS.EventBridge();

exports.handler = async (event) => {
    console.log('Event processor triggered:', JSON.stringify(event, null, 2));
    
    try {
        const processedEvents = [];
        
        // Handle different event sources
        for (const record of event.Records || [event]) {
            let eventData;
            
            // Parse event data based on source
            if (record.eventSource === 'aws:dynamodb') {
                eventData = await processDynamoDBEvent(record);
            } else if (record.eventSource === 'aws:sqs') {
                eventData = JSON.parse(record.body);
            } else if (record.eventSource === 'aws:s3') {
                eventData = await processS3Event(record);
            } else {
                eventData = record;
            }
            
            // Process different event types
            const result = await processEvent(eventData);
            processedEvents.push(result);
        }
        
        return {
            statusCode: 200,
            body: JSON.stringify({
                processed: processedEvents.length,
                results: processedEvents
            })
        };
        
    } catch (error) {
        console.error('Error processing events:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: error.message })
        };
    }
};

async function processDynamoDBEvent(record) {
    const eventName = record.eventName;
    const tableName = record.eventSourceARN.split('/')[1];
    
    console.log(`Processing DynamoDB event: ${eventName} on table ${tableName}`);
    
    const eventData = {
        type: 'dynamodb',
        eventName,
        tableName,
        keys: record.dynamodb.Keys,
        newImage: record.dynamodb.NewImage,
        oldImage: record.dynamodb.OldImage
    };
    
    // Handle specific table events
    if (tableName === 'cnn-chile-subscriptions') {
        await handleSubscriptionEvent(eventData);
    } else if (tableName === 'cnn-chile-users') {
        await handleUserEvent(eventData);
    }
    
    return eventData;
}

async function processS3Event(record) {
    const bucket = record.s3.bucket.name;
    const key = record.s3.object.key;
    const eventName = record.eventName;
    
    console.log(`Processing S3 event: ${eventName} for object ${key} in bucket ${bucket}`);
    
    const eventData = {
        type: 's3',
        eventName,
        bucket,
        key,
        size: record.s3.object.size
    };
    
    // Handle media file uploads
    if (key.startsWith('media/') && eventName.startsWith('ObjectCreated')) {
        await handleMediaUpload(eventData);
    }
    
    return eventData;
}

async function processEvent(eventData) {
    console.log('Processing event:', eventData.type);
    
    switch (eventData.type) {
        case 'user_registration':
            return await handleUserRegistration(eventData);
        case 'subscription_created':
            return await handleSubscriptionCreated(eventData);
        case 'subscription_expiring':
            return await handleSubscriptionExpiring(eventData);
        case 'breaking_news':
            return await handleBreakingNews(eventData);
        case 'content_published':
            return await handleContentPublished(eventData);
        default:
            console.log(`No handler for event type: ${eventData.type}`);
            return { status: 'ignored', type: eventData.type };
    }
}

async function handleUserRegistration(eventData) {
    console.log('Handling user registration for:', eventData.userId);
    
    // Send welcome email
    await invokeNotificationService({
        type: 'email',
        recipient: eventData.email,
        subject: 'Bienvenido a CNN Chile',
        body: 'Gracias por registrarte en nuestra plataforma.',
        template: 'welcome'
    });
    
    // Create user analytics record
    await createAnalyticsEvent('user_registered', eventData);
    
    return { status: 'completed', action: 'user_registration_processed' };
}

async function handleSubscriptionCreated(eventData) {
    console.log('Handling subscription created for:', eventData.userId);
    
    // Send confirmation email
    await invokeNotificationService({
        type: 'email',
        recipient: eventData.email,
        subject: 'Confirmación de Suscripción - CNN Chile',
        body: `Tu suscripción ${eventData.planType} ha sido activada.`,
        template: 'subscription_confirmation'
    });
    
    // Update user permissions
    await updateUserPermissions(eventData.userId, eventData.planType);
    
    return { status: 'completed', action: 'subscription_created_processed' };
}

async function handleSubscriptionExpiring(eventData) {
    console.log('Handling subscription expiring for:', eventData.userId);
    
    const daysUntilExpiry = Math.ceil((new Date(eventData.expiresAt) - new Date()) / (1000 * 60 * 60 * 24));
    
    if (daysUntilExpiry <= 7) {
        await invokeNotificationService({
            type: 'email',
            recipient: eventData.email,
            subject: `Tu suscripción expira en ${daysUntilExpiry} días`,
            body: 'Renueva tu suscripción para continuar disfrutando del contenido premium.',
            template: 'subscription_expiring'
        });
        
        // Send push notification
        await invokeNotificationService({
            type: 'push',
            userId: eventData.userId,
            title: 'Suscripción por expirar',
            body: `Tu suscripción expira en ${daysUntilExpiry} días. ¡Renueva ahora!`,
            data: { action: 'renew_subscription' }
        });
    }
    
    return { status: 'completed', action: 'subscription_expiring_processed' };
}

async function handleBreakingNews(eventData) {
    console.log('Handling breaking news:', eventData.newsId);
    
    // Send push notifications to all active users
    await invokeNotificationService({
        type: 'push',
        topic: 'breaking_news',
        title: '🚨 Noticia de Último Momento',
        body: eventData.headline,
        data: { 
            newsId: eventData.newsId,
            action: 'open_article'
        }
    });
    
    // Send websocket notifications to online users
    await publishToEventBridge({
        source: 'cnn-chile.news',
        'detail-type': 'Breaking News Alert',
        detail: eventData
    });
    
    return { status: 'completed', action: 'breaking_news_processed' };
}

async function handleContentPublished(eventData) {
    console.log('Handling content published:', eventData.contentId);
    
    // Invalidate CDN cache
    await invalidateCloudFrontCache([
        `/api/v1/content/${eventData.contentId}`,
        '/api/v1/content/latest'
    ]);
    
    // Update search index
    await updateSearchIndex(eventData);
    
    return { status: 'completed', action: 'content_published_processed' };
}

async function invokeNotificationService(notification) {
    const params = {
        FunctionName: process.env.NOTIFICATION_LAMBDA_ARN,
        InvocationType: 'Event',
        Payload: JSON.stringify(notification)
    };
    
    return await lambda.invoke(params).promise();
}

async function createAnalyticsEvent(eventType, data) {
    const params = {
        TableName: process.env.ANALYTICS_TABLE,
        Item: {
            id: `${eventType}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
            eventType,
            timestamp: new Date().toISOString(),
            data,
            ttl: Math.floor(Date.now() / 1000) + (365 * 24 * 60 * 60) // 1 year TTL
        }
    };
    
    return await dynamodb.put(params).promise();
}

async function updateUserPermissions(userId, planType) {
    const permissions = {
        basic: ['news_access'],
        premium: ['news_access', 'live_stream', 'exclusive_content'],
        vip: ['news_access', 'live_stream', 'exclusive_content', 'ad_free']
    };
    
    const params = {
        TableName: process.env.USERS_TABLE,
        Key: { user_id: userId },
        UpdateExpression: 'SET permissions = :permissions, updatedAt = :timestamp',
        ExpressionAttributeValues: {
            ':permissions': permissions[planType] || permissions.basic,
            ':timestamp': new Date().toISOString()
        }
    };
    
    return await dynamodb.update(params).promise();
}

async function publishToEventBridge(event) {
    const params = {
        Entries: [{
            Source: event.source,
            DetailType: event['detail-type'],
            Detail: JSON.stringify(event.detail),
            Time: new Date()
        }]
    };
    
    return await eventBridge.putEvents(params).promise();
}

async function invalidateCloudFrontCache(paths) {
    // This would typically call CloudFront invalidation API
    console.log('Would invalidate CloudFront cache for paths:', paths);
    return { status: 'simulated' };
}

async function updateSearchIndex(contentData) {
    // This would typically update Elasticsearch or similar search service
    console.log('Would update search index for content:', contentData.contentId);
    return { status: 'simulated' };
}
