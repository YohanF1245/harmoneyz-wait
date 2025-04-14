# Étape 1: Construction de l'application
FROM node:18-alpine AS build

# Ajout de labels pour la maintenance
LABEL maintainer="Harmoneyz Team"
LABEL description="Page d'attente pour l'application Harmoneyz"
LABEL version="1.0"

# Définir des variables d'environnement pour npm
ENV NODE_ENV=development

WORKDIR /app

# Copie uniquement des fichiers de dépendances pour optimiser le cache Docker
COPY package.json package-lock.json ./

# Installation des dépendances avec npm ci pour respecter exactement le package-lock.json
RUN npm ci && \
    # Nettoyer le cache npm pour réduire la taille de l'image
    npm cache clean --force

# Copie du reste des fichiers du projet (sauf ceux dans .dockerignore)
COPY . .

# Construction de l'application
RUN ./node_modules/.bin/vite build

# Étape 2: Servir l'application avec Nginx
FROM nginx:alpine

# Labels pour l'image finale
LABEL maintainer="Harmoneyz Team"
LABEL description="Page d'attente pour l'application Harmoneyz"
LABEL version="1.0"

# Copie des fichiers de build depuis l'étape précédente
COPY --from=build /app/dist /usr/share/nginx/html

# Copie de la configuration Nginx personnalisée
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Configuration des permissions (sécurité)
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chmod -R 755 /usr/share/nginx/html && \
    # Créer un utilisateur nginx non privilégié
    # Créer les répertoires nécessaires de logs et de cache
    mkdir -p /var/cache/nginx /var/log/nginx && \
    chmod -R 777 /var/cache/nginx /var/log/nginx && \
    chown -R nginx:nginx /var/cache/nginx /var/log/nginx

# Supprimer la directive user de nginx.conf pour éviter les problèmes de permissions
RUN sed -i '/^user/d' /etc/nginx/nginx.conf

# S'assurer que les fichiers de configuration sont modifiables
RUN chmod -R 755 /etc/nginx/conf.d && \
    chown -R nginx:nginx /etc/nginx

# S'assurer que /var/run est accessible
RUN mkdir -p /var/run && chmod 755 /var/run

# Créer un répertoire spécifique pour nginx avec les bonnes permissions
RUN mkdir -p /tmp/nginx && \
    chmod 777 /tmp/nginx

# Modifier la configuration de nginx pour utiliser le répertoire temporaire pour les fichiers PID
RUN sed -i 's|pid.*|pid /tmp/nginx/nginx.pid;|' /etc/nginx/nginx.conf && \
    # Vérifier que le fichier a bien été modifié
    grep -q "pid /tmp/nginx/nginx.pid" /etc/nginx/nginx.conf || echo "pid /tmp/nginx/nginx.pid;" >> /etc/nginx/nginx.conf

# Exposition du port 80
EXPOSE 80

# Utilisation de HEALTHCHECK pour permettre à Docker de vérifier l'état du conteneur
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:80/ || exit 1

# Démarrage de Nginx en mode foreground et en tant que root
CMD ["nginx", "-g", "daemon off;"] 