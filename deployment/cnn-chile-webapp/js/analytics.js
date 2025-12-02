// CNN Chile - Analytics en tiempo real
class AnalyticsManager {
    constructor() {
        this.updateInterval = null;
        this.isRunning = false;
        this.currentData = {};
        
        console.log('📊 Analytics Manager inicializado');
    }

    // Iniciar actualizaciones automáticas
    start() {
        if (this.isRunning) return;
        
        console.log('▶️ Iniciando analytics en tiempo real...');
        
        // Actualización inicial
        this.updateAnalytics();
        
        // Configurar intervalo de actualización
        this.updateInterval = setInterval(() => {
            this.updateAnalytics();
        }, window.CNN_CONFIG.APP_CONFIG.ui.analyticsUpdateInterval);
        
        this.isRunning = true;
    }

    // Detener actualizaciones
    stop() {
        if (this.updateInterval) {
            clearInterval(this.updateInterval);
            this.updateInterval = null;
        }
        this.isRunning = false;
        console.log('⏹️ Analytics detenido');
    }

    // Actualizar datos de analytics
    async updateAnalytics() {
        try {
            // Obtener datos actuales
            const analytics = await window.dynamoDBIntegration.getAnalytics();
            
            // Aplicar variaciones aleatorias para simular tiempo real
            const updatedAnalytics = {
                usersOnline: this.simulateRealTimeVariation(analytics.usersOnline, 0.1),
                pageViews: this.simulateRealTimeVariation(analytics.pageViews, 0.02, true),
                totalArticles: analytics.totalArticles,
                streamingViewers: this.simulateRealTimeVariation(analytics.streamingViewers, 0.15)
            };
            
            this.currentData = updatedAnalytics;
            
            // Actualizar UI
            this.updateAnalyticsUI(updatedAnalytics);
            
            // Guardar en DynamoDB (simulado)
            await this.saveAnalyticsToDB(updatedAnalytics);
            
        } catch (error) {
            console.error('❌ Error actualizando analytics:', error);
        }
    }

    // Simular variaciones en tiempo real
    simulateRealTimeVariation(baseValue, variationPercent, onlyIncrease = false) {
        const variation = baseValue * variationPercent;
        let change;
        
        if (onlyIncrease) {
            // Solo incrementos (como page views)
            change = Math.random() * variation;
        } else {
            // Incrementos y decrementos
            change = (Math.random() - 0.5) * 2 * variation;
        }
        
        return Math.max(0, Math.floor(baseValue + change));
    }

    // Actualizar elementos de la UI
    updateAnalyticsUI(analytics) {
        const elements = {
            'users-online': analytics.usersOnline,
            'page-views': this.formatNumber(analytics.pageViews),
            'total-articles': analytics.totalArticles,
            'streaming-viewers': analytics.streamingViewers
        };

        Object.entries(elements).forEach(([id, value]) => {
            const element = document.getElementById(id);
            if (element) {
                // Animación de actualización
                element.style.opacity = '0.6';
                
                setTimeout(() => {
                    element.textContent = value;
                    element.style.opacity = '1';
                }, 300);
            }
        });
        
        console.log('📊 Analytics UI actualizada:', analytics);
    }

    // Formatear números grandes
    formatNumber(num) {
        if (num >= 1000000) {
            return (num / 1000000).toFixed(1) + 'M';
        } else if (num >= 1000) {
            return (num / 1000).toFixed(1) + 'K';
        }
        return num.toString();
    }

    // Guardar analytics en base de datos (simulado)
    async saveAnalyticsToDB(analytics) {
        try {
            const timestamp = new Date().toISOString();
            
            // Guardar cada métrica individualmente
            await window.dynamoDBIntegration.updateAnalytics('users_online', analytics.usersOnline);
            await window.dynamoDBIntegration.updateAnalytics('page_views', analytics.pageViews);
            await window.dynamoDBIntegration.updateAnalytics('streaming_viewers', analytics.streamingViewers);
            
            // Crear snapshot completo cada 5 minutos
            const now = new Date();
            if (now.getMinutes() % 5 === 0) {
                await window.dynamoDBIntegration.updateAnalytics('snapshot', {
                    ...analytics,
                    timestamp
                });
            }
            
        } catch (error) {
            console.error('❌ Error guardando analytics:', error);
        }
    }

    // Obtener datos históricos (simulado)
    async getHistoricalData(metric, days = 7) {
        console.log(`📈 Obteniendo datos históricos de ${metric} (${days} días)`);
        
        // Simular datos históricos
        const data = [];
        const currentValue = this.currentData[metric] || 1000;
        
        for (let i = days; i >= 0; i--) {
            const date = new Date();
            date.setDate(date.getDate() - i);
            
            // Generar variación para cada día
            const variation = (Math.random() - 0.5) * 0.3;
            const value = Math.floor(currentValue * (1 + variation));
            
            data.push({
                date: date.toISOString().split('T')[0],
                value: Math.max(0, value)
            });
        }
        
        return data;
    }

    // Rastrear evento específico
    async trackEvent(eventName, eventData = {}) {
        try {
            const event = {
                eventName,
                eventData,
                timestamp: new Date().toISOString(),
                sessionId: this.getSessionId(),
                userId: window.cnnChileApp?.currentUser?.userId || 'anonymous'
            };
            
            console.log('🎯 Evento rastreado:', event);
            
            // En una implementación real, enviar a analytics service
            await window.dynamoDBIntegration.updateAnalytics(`event_${eventName}`, event);
            
        } catch (error) {
            console.error('❌ Error rastreando evento:', error);
        }
    }

    // Obtener o crear session ID
    getSessionId() {
        let sessionId = sessionStorage.getItem('cnn_session_id');
        
        if (!sessionId) {
            sessionId = 'sess_' + window.CNN_CONFIG.DEV_UTILS.generateId();
            sessionStorage.setItem('cnn_session_id', sessionId);
        }
        
        return sessionId;
    }

    // Rastrear tiempo en página
    trackPageTime() {
        let startTime = Date.now();
        
        // Rastrear cuando el usuario sale de la página
        window.addEventListener('beforeunload', () => {
            const timeSpent = Math.floor((Date.now() - startTime) / 1000);
            this.trackEvent('page_time', { 
                seconds: timeSpent,
                page: window.location.pathname 
            });
        });
        
        // Rastrear cuando la página pierde focus
        document.addEventListener('visibilitychange', () => {
            if (document.hidden) {
                const timeSpent = Math.floor((Date.now() - startTime) / 1000);
                this.trackEvent('page_blur', { 
                    seconds: timeSpent,
                    page: window.location.pathname 
                });
            } else {
                startTime = Date.now();
            }
        });
    }

    // Rastrear interacciones del usuario
    trackUserInteractions() {
        // Clicks en artículos
        document.addEventListener('click', (e) => {
            const newsCard = e.target.closest('.news-card');
            if (newsCard) {
                this.trackEvent('article_click', {
                    articleId: newsCard.dataset.id,
                    category: newsCard.querySelector('.news-category')?.textContent
                });
            }
            
            // Clicks en categorías
            const categoryBtn = e.target.closest('.category-btn');
            if (categoryBtn) {
                this.trackEvent('category_filter', {
                    category: categoryBtn.dataset.category
                });
            }
            
            // Clicks en streaming
            const playBtn = e.target.closest('.play-btn');
            if (playBtn) {
                this.trackEvent('streaming_start', {
                    source: 'main_page'
                });
            }
        });
        
        // Scroll tracking
        let scrollTimeout;
        window.addEventListener('scroll', () => {
            clearTimeout(scrollTimeout);
            scrollTimeout = setTimeout(() => {
                const scrollPercent = Math.round(
                    (window.scrollY / (document.body.scrollHeight - window.innerHeight)) * 100
                );
                
                if (scrollPercent > 0 && scrollPercent % 25 === 0) {
                    this.trackEvent('scroll_depth', { 
                        percent: scrollPercent,
                        page: window.location.pathname
                    });
                }
            }, 250);
        });
    }

    // Generar reporte de analytics
    async generateReport() {
        console.log('📋 Generando reporte de analytics...');
        
        const report = {
            timestamp: new Date().toISOString(),
            current: this.currentData,
            session: this.getSessionId(),
            historical: {
                users: await this.getHistoricalData('usersOnline'),
                pageViews: await this.getHistoricalData('pageViews'),
                streaming: await this.getHistoricalData('streamingViewers')
            }
        };
        
        console.table(report.current);
        return report;
    }
}

// Crear instancia global
window.analyticsManager = new AnalyticsManager();

// Función para inicializar analytics
function startAnalyticsUpdate() {
    console.log('📊 Iniciando sistema de analytics...');
    
    // Inicializar analytics manager
    window.analyticsManager.start();
    
    // Configurar tracking de interacciones
    window.analyticsManager.trackPageTime();
    window.analyticsManager.trackUserInteractions();
    
    // Rastrear carga inicial de página
    window.analyticsManager.trackEvent('page_load', {
        page: window.location.pathname,
        referrer: document.referrer,
        userAgent: navigator.userAgent.substring(0, 100)
    });
}

// Función para obtener analytics actuales
function getCurrentAnalytics() {
    return window.analyticsManager.currentData;
}

// Función para generar reporte
async function generateAnalyticsReport() {
    return await window.analyticsManager.generateReport();
}

console.log('📊 Analytics Manager cargado');
