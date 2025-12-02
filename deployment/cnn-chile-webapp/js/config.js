// CNN Chile - Configuración AWS
const AWS_CONFIG = {
    region: 'us-east-1',
    account: '220017832616',
    
    // VPC Configuration
    vpc: {
        id: 'vpc-025aea4b75e561b62',
        cidr: '10.0.0.0/16'
    },
    
    // S3 Buckets
    s3: {
        staticContent: 'cnn-chile-dev-static-content-2854546c',
        liveStreaming: 'cnn-chile-dev-live-streaming-2854546c',
        mediaContent: 'cnn-chile-dev-media-content-2854546c'
    },
    
    // DynamoDB Tables
    dynamodb: {
        users: 'cnn-chile-dev-users',
        content: 'cnn-chile-dev-content',
        sessions: 'cnn-chile-dev-sessions',
        analytics: 'cnn-chile-dev-analytics',
        subscriptions: 'cnn-chile-dev-subscriptions',
        mediaAssets: 'cnn-chile-dev-media-assets'
    },
    
    // Load Balancer
    alb: {
        dnsName: 'cnn-chile-dev-alb-1352075639.us-east-1.elb.amazonaws.com',
        url: 'http://cnn-chile-dev-alb-1352075639.us-east-1.elb.amazonaws.com'
    },
    
    // ElastiCache Redis
    redis: {
        replicationGroupId: 'cnn-chile-dev-redis',
        nodeType: 'cache.t3.micro',
        port: 6379
    },
    
    // SNS Topics
    sns: {
        alerts: 'cnn-chile-dev-alerts',
        pushNotifications: 'cnn-chile-dev-push-notifications'
    },
    
    // SQS Queues
    sqs: {
        notificationQueue: 'cnn-chile-dev-notification-queue',
        notificationDLQ: 'cnn-chile-dev-notification-dlq'
    }
};

// API Endpoints (simulados para demo)
const API_ENDPOINTS = {
    base: 'https://api.cnn-chile.com',
    
    // Content APIs
    news: {
        latest: '/api/news/latest',
        category: '/api/news/category',
        search: '/api/news/search',
        article: '/api/news/article'
    },
    
    // User APIs
    auth: {
        login: '/api/auth/login',
        register: '/api/auth/register',
        logout: '/api/auth/logout',
        profile: '/api/auth/profile'
    },
    
    // Analytics APIs
    analytics: {
        realtime: '/api/analytics/realtime',
        pageviews: '/api/analytics/pageviews',
        users: '/api/analytics/users'
    },
    
    // Streaming APIs
    streaming: {
        live: '/api/streaming/live',
        status: '/api/streaming/status',
        schedule: '/api/streaming/schedule'
    }
};

// Configuración de la aplicación
const APP_CONFIG = {
    name: 'CNN Chile',
    version: '1.0.0',
    environment: 'development',
    
    // Features flags
    features: {
        liveStreaming: true,
        userRegistration: true,
        analytics: true,
        pushNotifications: true,
        darkMode: false
    },
    
    // Cache settings
    cache: {
        ttl: 300, // 5 minutos
        enabled: true
    },
    
    // UI Settings
    ui: {
        articlesPerPage: 12,
        breakingNewsInterval: 30000, // 30 segundos
        analyticsUpdateInterval: 60000 // 1 minuto
    },
    
    // Social Media
    social: {
        facebook: 'https://facebook.com/cnnchile',
        twitter: 'https://twitter.com/cnnchile',
        instagram: 'https://instagram.com/cnnchile',
        youtube: 'https://youtube.com/cnnchile'
    }
};

// Datos de muestra para desarrollo
const SAMPLE_DATA = {
    news: [
        {
            id: '1',
            title: 'Infraestructura AWS CNN Chile desplegada exitosamente',
            summary: 'La nueva plataforma digital de CNN Chile utiliza 77 recursos de AWS para garantizar escalabilidad y disponibilidad.',
            category: 'tecnologia',
            image: 'https://via.placeholder.com/400x250/CC0000/FFFFFF?text=CNN+Chile',
            author: 'Redacción CNN Chile',
            publishDate: new Date().toISOString(),
            readTime: 3
        },
        {
            id: '2',
            title: 'Análisis: El futuro de la infraestructura digital en medios',
            summary: 'Expertos analizan cómo la tecnología cloud está transformando el periodismo y la distribución de contenido.',
            category: 'politica',
            image: 'https://via.placeholder.com/400x250/1E3A8A/FFFFFF?text=Análisis',
            author: 'Juan Pérez',
            publishDate: new Date(Date.now() - 3600000).toISOString(),
            readTime: 5
        },
        {
            id: '3',
            title: 'Streaming en vivo: Nueva experiencia para los usuarios',
            summary: 'La implementación de ElastiCache Redis mejora significativamente la experiencia de streaming.',
            category: 'economia',
            image: 'https://via.placeholder.com/400x250/10B981/FFFFFF?text=Streaming',
            author: 'María González',
            publishDate: new Date(Date.now() - 7200000).toISOString(),
            readTime: 4
        }
    ],
    
    analytics: {
        usersOnline: Math.floor(Math.random() * 5000) + 1000,
        pageViews: Math.floor(Math.random() * 50000) + 10000,
        totalArticles: 847,
        streamingViewers: Math.floor(Math.random() * 2000) + 500
    },
    
    breakingNews: [
        'Sistema CNN Chile operativo al 100% • Infraestructura AWS estable',
        'Nuevo récord de usuarios simultáneos en plataforma digital',
        'ElastiCache Redis mejora rendimiento de streaming en 40%'
    ]
};

// Utilidades para desarrollo local
const DEV_UTILS = {
    // Simular delay de red
    networkDelay: (min = 500, max = 2000) => {
        return new Promise(resolve => {
            const delay = Math.floor(Math.random() * (max - min + 1)) + min;
            setTimeout(resolve, delay);
        });
    },
    
    // Generar ID único
    generateId: () => {
        return Date.now().toString(36) + Math.random().toString(36).substr(2);
    },
    
    // Formatear fecha
    formatDate: (date) => {
        return new Intl.DateTimeFormat('es-CL', {
            year: 'numeric',
            month: 'long',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        }).format(new Date(date));
    },
    
    // Calcular tiempo de lectura
    calculateReadTime: (text) => {
        const wordsPerMinute = 200;
        const wordCount = text.split(/\s+/).length;
        return Math.ceil(wordCount / wordsPerMinute);
    }
};

// Log de configuración
console.log('🚀 CNN Chile - Configuración cargada');
console.log('📊 AWS Account:', AWS_CONFIG.account);
console.log('🌍 Region:', AWS_CONFIG.region);
console.log('🗂️ Environment:', APP_CONFIG.environment);

// Exportar configuración para uso global
window.CNN_CONFIG = {
    AWS_CONFIG,
    API_ENDPOINTS,
    APP_CONFIG,
    SAMPLE_DATA,
    DEV_UTILS
};
