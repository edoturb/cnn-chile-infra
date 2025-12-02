// CNN Chile - Sistema de Streaming
class StreamingManager {
    constructor() {
        this.isStreaming = false;
        this.streamData = null;
        this.viewerCount = 0;
        this.streamQuality = 'HD';
        
        console.log('🎥 Streaming Manager inicializado');
    }

    // Inicializar streaming
    async initLiveStream() {
        try {
            console.log('📡 Inicializando stream en vivo...');
            
            // Simular inicialización de stream
            await window.CNN_CONFIG.DEV_UTILS.networkDelay(1000, 2000);
            
            this.isStreaming = true;
            this.viewerCount = window.CNN_CONFIG.SAMPLE_DATA.analytics.streamingViewers;
            
            // Actualizar UI
            this.updateStreamingUI();
            
            // Iniciar simulación de stream
            this.startStreamSimulation();
            
            // Rastrear evento
            await window.analyticsManager.trackEvent('streaming_start', {
                quality: this.streamQuality,
                platform: 'web'
            });
            
            console.log('✅ Stream iniciado correctamente');
            
        } catch (error) {
            console.error('❌ Error inicializando stream:', error);
            this.showStreamingError('Error al inicializar transmisión');
        }
    }

    // Actualizar UI de streaming
    updateStreamingUI() {
        const videoPlaceholder = document.querySelector('.video-placeholder');
        
        if (videoPlaceholder && this.isStreaming) {
            videoPlaceholder.innerHTML = `
                <div class="streaming-active">
                    <div class="streaming-indicator">
                        <span class="live-badge">● EN VIVO</span>
                        <span class="viewer-count">${this.formatViewerCount()} espectadores</span>
                    </div>
                    <div class="video-controls">
                        <button onclick="toggleStreamQuality()" class="quality-btn">
                            <i class="fas fa-cog"></i> ${this.streamQuality}
                        </button>
                        <button onclick="toggleFullscreen()" class="fullscreen-btn">
                            <i class="fas fa-expand"></i>
                        </button>
                        <button onclick="stopStream()" class="stop-btn">
                            <i class="fas fa-stop"></i> Detener
                        </button>
                    </div>
                    <div class="streaming-stats">
                        <div class="stat">
                            <i class="fas fa-signal"></i>
                            <span>Señal: Excelente</span>
                        </div>
                        <div class="stat">
                            <i class="fas fa-clock"></i>
                            <span id="stream-duration">00:00:00</span>
                        </div>
                    </div>
                </div>
            `;
            
            // Iniciar contador de duración
            this.startDurationCounter();
        }
    }

    // Formatear número de espectadores
    formatViewerCount() {
        if (this.viewerCount >= 1000) {
            return (this.viewerCount / 1000).toFixed(1) + 'K';
        }
        return this.viewerCount.toString();
    }

    // Iniciar simulación de stream
    startStreamSimulation() {
        // Simular variaciones en el número de espectadores
        this.streamInterval = setInterval(() => {
            const variation = (Math.random() - 0.5) * 0.1; // ±10%
            const newCount = Math.floor(this.viewerCount * (1 + variation));
            this.viewerCount = Math.max(1, newCount);
            
            // Actualizar contador en UI
            const viewerCountElement = document.querySelector('.viewer-count');
            if (viewerCountElement) {
                viewerCountElement.textContent = `${this.formatViewerCount()} espectadores`;
            }
            
            // Actualizar analytics
            window.dynamoDBIntegration.updateAnalytics('streaming_viewers', this.viewerCount);
            
        }, 5000); // Cada 5 segundos
    }

    // Iniciar contador de duración
    startDurationCounter() {
        this.streamStartTime = Date.now();
        
        this.durationInterval = setInterval(() => {
            const duration = Date.now() - this.streamStartTime;
            const formatted = this.formatDuration(duration);
            
            const durationElement = document.getElementById('stream-duration');
            if (durationElement) {
                durationElement.textContent = formatted;
            }
        }, 1000);
    }

    // Formatear duración
    formatDuration(milliseconds) {
        const seconds = Math.floor(milliseconds / 1000);
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        const secs = seconds % 60;
        
        return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }

    // Detener stream
    async stopStream() {
        try {
            console.log('⏹️ Deteniendo stream...');
            
            this.isStreaming = false;
            
            // Limpiar intervalos
            if (this.streamInterval) {
                clearInterval(this.streamInterval);
            }
            if (this.durationInterval) {
                clearInterval(this.durationInterval);
            }
            
            // Calcular duración total
            const totalDuration = this.streamStartTime ? Date.now() - this.streamStartTime : 0;
            
            // Rastrear evento
            await window.analyticsManager.trackEvent('streaming_stop', {
                duration: totalDuration,
                peak_viewers: this.viewerCount,
                quality: this.streamQuality
            });
            
            // Restaurar UI original
            this.resetStreamingUI();
            
            console.log('✅ Stream detenido');
            
        } catch (error) {
            console.error('❌ Error deteniendo stream:', error);
        }
    }

    // Restaurar UI original
    resetStreamingUI() {
        const videoPlaceholder = document.querySelector('.video-placeholder');
        
        if (videoPlaceholder) {
            videoPlaceholder.innerHTML = `
                <i class="fas fa-play-circle"></i>
                <h3>Señal en Vivo</h3>
                <p>Haz clic para ver CNN Chile en vivo</p>
                <button class="play-btn" onclick="initLiveStream()">
                    <i class="fas fa-play"></i> Ver Ahora
                </button>
            `;
        }
    }

    // Cambiar calidad de stream
    toggleStreamQuality() {
        const qualities = ['HD', '720p', '480p', '360p'];
        const currentIndex = qualities.indexOf(this.streamQuality);
        const nextIndex = (currentIndex + 1) % qualities.length;
        
        this.streamQuality = qualities[nextIndex];
        
        // Actualizar UI
        const qualityBtn = document.querySelector('.quality-btn');
        if (qualityBtn) {
            qualityBtn.innerHTML = `<i class="fas fa-cog"></i> ${this.streamQuality}`;
        }
        
        // Rastrear cambio de calidad
        window.analyticsManager.trackEvent('stream_quality_change', {
            new_quality: this.streamQuality,
            previous_quality: qualities[currentIndex]
        });
        
        console.log(`📺 Calidad cambiada a: ${this.streamQuality}`);
    }

    // Pantalla completa
    toggleFullscreen() {
        const videoContainer = document.querySelector('.video-player');
        
        if (videoContainer) {
            if (!document.fullscreenElement) {
                videoContainer.requestFullscreen().catch(err => {
                    console.error('Error activando fullscreen:', err);
                });
                
                window.analyticsManager.trackEvent('fullscreen_enter');
            } else {
                document.exitFullscreen();
                window.analyticsManager.trackEvent('fullscreen_exit');
            }
        }
    }

    // Obtener información del stream
    getStreamInfo() {
        return {
            isStreaming: this.isStreaming,
            viewerCount: this.viewerCount,
            quality: this.streamQuality,
            duration: this.streamStartTime ? Date.now() - this.streamStartTime : 0,
            status: this.isStreaming ? 'live' : 'offline'
        };
    }

    // Obtener schedule de programación
    async getStreamSchedule() {
        console.log('📅 Obteniendo programación...');
        
        // Simular datos de programación
        const schedule = [
            {
                time: '18:00',
                program: 'CNN Chile Noticias',
                description: 'Resumen de las principales noticias del día',
                duration: 60,
                type: 'news'
            },
            {
                time: '19:00',
                program: 'Análisis Político',
                description: 'Debate y análisis de la contingencia política',
                duration: 60,
                type: 'analysis'
            },
            {
                time: '20:00',
                program: 'CNN Chile Prime',
                description: 'El noticiero central con las noticias más relevantes',
                duration: 90,
                type: 'news'
            },
            {
                time: '21:30',
                program: 'Deportes CNN',
                description: 'Resumen deportivo nacional e internacional',
                duration: 30,
                type: 'sports'
            },
            {
                time: '22:00',
                program: 'Análisis Internacional',
                description: 'Noticias y análisis del panorama mundial',
                duration: 60,
                type: 'international'
            }
        ];
        
        return schedule;
    }

    // Mostrar error de streaming
    showStreamingError(message) {
        const videoPlaceholder = document.querySelector('.video-placeholder');
        
        if (videoPlaceholder) {
            videoPlaceholder.innerHTML = `
                <div class="streaming-error">
                    <i class="fas fa-exclamation-triangle"></i>
                    <h3>Error de Transmisión</h3>
                    <p>${message}</p>
                    <button class="retry-btn" onclick="initLiveStream()">
                        <i class="fas fa-redo"></i> Reintentar
                    </button>
                </div>
            `;
        }
    }

    // Inicializar noticias breaking
    initBreakingNews() {
        const breakingNews = window.CNN_CONFIG.SAMPLE_DATA.breakingNews;
        let currentIndex = 0;
        
        const updateBreakingNews = () => {
            const breakingElement = document.getElementById('breaking-news');
            if (breakingElement && breakingNews.length > 0) {
                breakingElement.innerHTML = `<span>${breakingNews[currentIndex]}</span>`;
                currentIndex = (currentIndex + 1) % breakingNews.length;
            }
        };
        
        // Actualizar inmediatamente
        updateBreakingNews();
        
        // Configurar intervalo de actualización
        setInterval(updateBreakingNews, window.CNN_CONFIG.APP_CONFIG.ui.breakingNewsInterval);
        
        console.log('📰 Breaking news inicializado');
    }
}

// Crear instancia global
window.streamingManager = new StreamingManager();

// Funciones globales para compatibilidad
function initLiveStream() {
    window.streamingManager.initLiveStream();
}

function stopStream() {
    window.streamingManager.stopStream();
}

function toggleStreamQuality() {
    window.streamingManager.toggleStreamQuality();
}

function toggleFullscreen() {
    window.streamingManager.toggleFullscreen();
}

function initBreakingNews() {
    window.streamingManager.initBreakingNews();
}

function getStreamInfo() {
    return window.streamingManager.getStreamInfo();
}

// Agregar estilos CSS para streaming
const streamingStyles = `
<style>
.streaming-active {
    height: 100%;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    padding: 1rem;
    background: linear-gradient(135deg, #000 0%, #333 100%);
    color: white;
}

.streaming-indicator {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
}

.live-badge {
    background: #CC0000;
    color: white;
    padding: 0.25rem 0.5rem;
    border-radius: 3px;
    font-weight: bold;
    font-size: 0.8rem;
    animation: pulse 2s infinite;
}

@keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.7; }
}

.viewer-count {
    font-size: 0.9rem;
    opacity: 0.9;
}

.video-controls {
    display: flex;
    gap: 0.5rem;
    margin-bottom: 1rem;
}

.video-controls button {
    background: rgba(255, 255, 255, 0.2);
    border: none;
    color: white;
    padding: 0.5rem;
    border-radius: 4px;
    cursor: pointer;
    font-size: 0.8rem;
    transition: background-color 0.3s;
}

.video-controls button:hover {
    background: rgba(255, 255, 255, 0.3);
}

.stop-btn {
    background: #CC0000 !important;
}

.streaming-stats {
    display: flex;
    gap: 1rem;
    font-size: 0.8rem;
    opacity: 0.8;
}

.streaming-stats .stat {
    display: flex;
    align-items: center;
    gap: 0.3rem;
}

.streaming-error {
    text-align: center;
    color: #CC0000;
}

.streaming-error i {
    font-size: 3rem;
    margin-bottom: 1rem;
}

.retry-btn {
    background: #CC0000;
    color: white;
    border: none;
    padding: 0.8rem 1.5rem;
    border-radius: 4px;
    cursor: pointer;
    font-size: 1rem;
    margin-top: 1rem;
}

.retry-btn:hover {
    background: #B91C1C;
}
</style>
`;

// Inyectar estilos
document.head.insertAdjacentHTML('beforeend', streamingStyles);

console.log('🎥 Streaming Manager cargado');
