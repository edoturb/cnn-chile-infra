// CNN Chile - Funcionalidades principales
class CNNChileApp {
    constructor() {
        this.isInitialized = false;
        this.currentUser = null;
        this.currentCategory = 'all';
        this.newsOffset = 0;
        
        console.log('🚀 CNN Chile App inicializando...');
    }

    // Inicializar la aplicación
    async init() {
        if (this.isInitialized) return;
        
        try {
            // Configurar event listeners
            this.setupEventListeners();
            
            // Poblar datos iniciales
            await window.dynamoDBIntegration.seedDatabase();
            
            // Cargar contenido inicial
            await this.loadInitialContent();
            
            this.isInitialized = true;
            console.log('✅ CNN Chile App inicializada correctamente');
            
        } catch (error) {
            console.error('❌ Error inicializando aplicación:', error);
        }
    }

    // Configurar event listeners
    setupEventListeners() {
        // Navegación móvil
        const menuToggle = document.getElementById('menu-toggle');
        const navMenu = document.getElementById('nav-menu');
        
        if (menuToggle && navMenu) {
            menuToggle.addEventListener('click', () => {
                navMenu.classList.toggle('active');
                menuToggle.classList.toggle('active');
            });
        }

        // Navegación smooth scroll
        document.querySelectorAll('.nav-link').forEach(link => {
            link.addEventListener('click', (e) => {
                e.preventDefault();
                const targetId = link.getAttribute('href');
                const targetElement = document.querySelector(targetId);
                
                if (targetElement) {
                    targetElement.scrollIntoView({ 
                        behavior: 'smooth',
                        block: 'start'
                    });
                }
                
                // Cerrar menú móvil
                navMenu?.classList.remove('active');
                menuToggle?.classList.remove('active');
                
                // Actualizar link activo
                document.querySelectorAll('.nav-link').forEach(l => l.classList.remove('active'));
                link.classList.add('active');
            });
        });

        // Categorías de noticias
        document.querySelectorAll('.category-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const category = e.target.dataset.category;
                this.filterNewsByCategory(category);
                
                // Actualizar botón activo
                document.querySelectorAll('.category-btn').forEach(b => b.classList.remove('active'));
                e.target.classList.add('active');
            });
        });

        // Búsqueda
        const searchBtn = document.querySelector('.search-btn');
        if (searchBtn) {
            searchBtn.addEventListener('click', () => {
                this.showSearchModal();
            });
        }

        // Formularios de autenticación
        this.setupAuthForms();
    }

    // Configurar formularios de autenticación
    setupAuthForms() {
        const loginForm = document.getElementById('login-form');
        const registerForm = document.getElementById('register-form');

        if (loginForm) {
            loginForm.addEventListener('submit', async (e) => {
                e.preventDefault();
                const formData = new FormData(loginForm);
                const email = formData.get('email') || e.target.querySelector('input[type="email"]').value;
                const password = formData.get('password') || e.target.querySelector('input[type="password"]').value;
                
                await this.handleLogin(email, password);
            });
        }

        if (registerForm) {
            registerForm.addEventListener('submit', async (e) => {
                e.preventDefault();
                const formData = new FormData(registerForm);
                const inputs = e.target.querySelectorAll('input');
                
                const userData = {
                    name: inputs[0].value,
                    email: inputs[1].value,
                    password: inputs[2].value
                };
                
                await this.handleRegister(userData);
            });
        }
    }

    // Cargar contenido inicial
    async loadInitialContent() {
        console.log('📰 Cargando contenido inicial...');
        
        // Cargar sidebar stories
        await this.loadSidebarStories();
        
        // Cargar noticias principales
        await this.loadLatestNews();
    }

    // Cargar historias del sidebar
    async loadSidebarStories() {
        try {
            const sidebarContainer = document.getElementById('sidebar-stories');
            if (!sidebarContainer) return;

            const content = await window.dynamoDBIntegration.getContent('all', 3);
            
            sidebarContainer.innerHTML = content.map(story => `
                <article class="sidebar-story" data-id="${story.id}">
                    <img src="${story.image}" alt="${story.title}" onerror="this.src='https://via.placeholder.com/80x60/CCCCCC/666666?text=IMG'">
                    <div class="sidebar-story-content">
                        <h4>${story.title}</h4>
                        <p>${window.CNN_CONFIG.DEV_UTILS.formatDate(story.publishDate)}</p>
                    </div>
                </article>
            `).join('');
            
            console.log('✅ Sidebar stories cargadas');
        } catch (error) {
            console.error('❌ Error cargando sidebar stories:', error);
        }
    }

    // Cargar últimas noticias
    async loadLatestNews() {
        try {
            const newsGrid = document.getElementById('news-grid');
            if (!newsGrid) return;

            // Mostrar loading
            newsGrid.innerHTML = this.generateLoadingCards(6);
            
            const content = await window.dynamoDBIntegration.getContent(this.currentCategory, 12);
            
            newsGrid.innerHTML = content.map(article => this.createNewsCard(article)).join('');
            
            // Configurar click en cards
            this.setupNewsCardListeners();
            
            console.log(`✅ ${content.length} noticias cargadas`);
        } catch (error) {
            console.error('❌ Error cargando noticias:', error);
            this.showErrorMessage('Error cargando noticias');
        }
    }

    // Crear card de noticia
    createNewsCard(article) {
        return `
            <article class="news-card" data-id="${article.id}" onclick="openArticle('${article.id}')">
                <img src="${article.image}" alt="${article.title}" 
                     onerror="this.src='https://via.placeholder.com/400x250/CCCCCC/666666?text=Imagen+no+disponible'">
                <div class="news-card-content">
                    <span class="news-category">${this.getCategoryLabel(article.category)}</span>
                    <h3>${article.title}</h3>
                    <p>${article.summary}</p>
                    <div class="news-meta">
                        <span>${article.author}</span>
                        <span>${article.readTime} min lectura</span>
                    </div>
                </div>
            </article>
        `;
    }

    // Generar cards de loading
    generateLoadingCards(count) {
        return Array(count).fill(0).map(() => `
            <div class="news-card skeleton">
                <div style="height: 200px; background: #f0f0f0;"></div>
                <div class="news-card-content">
                    <div style="height: 20px; background: #f0f0f0; margin-bottom: 10px; width: 80px;"></div>
                    <div style="height: 24px; background: #f0f0f0; margin-bottom: 10px;"></div>
                    <div style="height: 18px; background: #f0f0f0; margin-bottom: 5px;"></div>
                    <div style="height: 18px; background: #f0f0f0; width: 70%;"></div>
                </div>
            </div>
        `).join('');
    }

    // Configurar listeners de news cards
    setupNewsCardListeners() {
        document.querySelectorAll('.news-card').forEach(card => {
            card.addEventListener('click', () => {
                const articleId = card.dataset.id;
                if (articleId) {
                    this.openArticle(articleId);
                }
            });
        });
    }

    // Filtrar noticias por categoría
    async filterNewsByCategory(category) {
        console.log(`🔍 Filtrando por categoría: ${category}`);
        this.currentCategory = category;
        this.newsOffset = 0;
        
        await this.loadLatestNews();
        
        // Actualizar analytics
        await window.dynamoDBIntegration.updateAnalytics('category_filter', category);
    }

    // Cargar más noticias
    async loadMoreNews() {
        try {
            const newsGrid = document.getElementById('news-grid');
            const loadBtn = document.querySelector('.load-more-btn');
            
            if (loadBtn) {
                loadBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Cargando...';
                loadBtn.disabled = true;
            }
            
            this.newsOffset += 12;
            const moreContent = await window.dynamoDBIntegration.getContent(this.currentCategory, 6);
            
            if (moreContent.length > 0) {
                const newCards = moreContent.map(article => this.createNewsCard(article)).join('');
                newsGrid.insertAdjacentHTML('beforeend', newCards);
                this.setupNewsCardListeners();
            } else {
                if (loadBtn) {
                    loadBtn.style.display = 'none';
                }
            }
            
            if (loadBtn) {
                loadBtn.innerHTML = '<i class="fas fa-plus"></i> Cargar Más Noticias';
                loadBtn.disabled = false;
            }
            
        } catch (error) {
            console.error('❌ Error cargando más noticias:', error);
        }
    }

    // Abrir artículo
    openArticle(articleId) {
        console.log(`📖 Abriendo artículo: ${articleId}`);
        
        // Simular apertura de artículo
        alert(`Artículo ${articleId} - En una implementación completa, esto abriría el artículo completo.`);
        
        // Actualizar analytics
        window.dynamoDBIntegration.updateAnalytics('article_view', articleId);
    }

    // Manejo de login
    async handleLogin(email, password) {
        try {
            console.log('🔐 Iniciando sesión:', email);
            
            // Simular autenticación
            const users = await window.dynamoDBIntegration.getUsers();
            const user = users.find(u => u.email === email);
            
            if (user) {
                this.currentUser = user;
                await window.dynamoDBIntegration.createSession(user.userId);
                
                this.showSuccessMessage('Sesión iniciada correctamente');
                this.closeUserModal();
                this.updateUserInterface();
            } else {
                this.showErrorMessage('Usuario no encontrado');
            }
            
        } catch (error) {
            console.error('❌ Error en login:', error);
            this.showErrorMessage('Error al iniciar sesión');
        }
    }

    // Manejo de registro
    async handleRegister(userData) {
        try {
            console.log('👤 Registrando usuario:', userData.email);
            
            const newUser = await window.dynamoDBIntegration.createUser({
                name: userData.name,
                email: userData.email,
                subscription: 'basic',
                preferences: { notifications: true, newsletter: true }
            });
            
            this.currentUser = newUser;
            await window.dynamoDBIntegration.createSession(newUser.userId);
            
            this.showSuccessMessage('Usuario registrado correctamente');
            this.closeUserModal();
            this.updateUserInterface();
            
        } catch (error) {
            console.error('❌ Error en registro:', error);
            this.showErrorMessage('Error al registrar usuario');
        }
    }

    // Actualizar interfaz de usuario
    updateUserInterface() {
        const userBtn = document.querySelector('.user-btn');
        if (userBtn && this.currentUser) {
            userBtn.innerHTML = `<i class="fas fa-user-check"></i>`;
            userBtn.title = `Conectado como ${this.currentUser.name}`;
        }
    }

    // Obtener etiqueta de categoría
    getCategoryLabel(category) {
        const labels = {
            'tecnologia': 'TECNOLOGÍA',
            'politica': 'POLÍTICA',
            'economia': 'ECONOMÍA',
            'deportes': 'DEPORTES',
            'internacional': 'INTERNACIONAL'
        };
        return labels[category] || 'GENERAL';
    }

    // Mostrar mensaje de éxito
    showSuccessMessage(message) {
        console.log('✅', message);
        // En una implementación completa, mostrar toast notification
        alert(message);
    }

    // Mostrar mensaje de error
    showErrorMessage(message) {
        console.error('❌', message);
        // En una implementación completa, mostrar toast notification
        alert(message);
    }

    // Mostrar modal de búsqueda
    showSearchModal() {
        alert('🔍 Funcionalidad de búsqueda - En desarrollo');
    }
}

// Funciones globales para compatibilidad
function toggleUserMenu() {
    const modal = document.getElementById('user-modal');
    if (modal) {
        modal.style.display = modal.style.display === 'block' ? 'none' : 'block';
    }
}

function closeUserModal() {
    const modal = document.getElementById('user-modal');
    if (modal) {
        modal.style.display = 'none';
    }
}

function showLogin() {
    document.getElementById('login-form').classList.remove('hidden');
    document.getElementById('register-form').classList.add('hidden');
    document.querySelectorAll('.tab-btn').forEach(btn => btn.classList.remove('active'));
    document.querySelector('.tab-btn').classList.add('active');
}

function showRegister() {
    document.getElementById('login-form').classList.add('hidden');
    document.getElementById('register-form').classList.remove('hidden');
    document.querySelectorAll('.tab-btn').forEach(btn => btn.classList.remove('active'));
    document.querySelectorAll('.tab-btn')[1].classList.add('active');
}

function openArticle(articleId) {
    if (window.cnnChileApp) {
        window.cnnChileApp.openArticle(articleId);
    }
}

function loadMoreNews() {
    if (window.cnnChileApp) {
        window.cnnChileApp.loadMoreNews();
    }
}

// Inicializar aplicación global
window.cnnChileApp = new CNNChileApp();

// Función de inicialización principal
async function initApp() {
    console.log('🚀 Inicializando CNN Chile App...');
    
    try {
        // Probar conectividad DynamoDB
        await window.dynamoDBIntegration.testConnection();
        
        // Inicializar aplicación
        await window.cnnChileApp.init();
        
        console.log('✅ CNN Chile App completamente inicializada');
    } catch (error) {
        console.error('❌ Error en inicialización:', error);
    }
}

// Función para cargar noticias (compatibilidad)
async function loadLatestNews() {
    if (window.cnnChileApp) {
        await window.cnnChileApp.loadLatestNews();
    }
}

console.log('📱 CNN Chile Main App cargado');
