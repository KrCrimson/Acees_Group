# Dockerfile para Railway - Solo Backend Node.js
FROM node:18-alpine

# Crear directorio de trabajo
WORKDIR /app

# Copiar package.json y package-lock.json del backend
COPY backend/package*.json ./

# Instalar dependencias
RUN npm install --production

# Copiar código del backend
COPY backend/ ./

# Exponer puerto
EXPOSE 3000

# Variables de entorno
ENV NODE_ENV=production
ENV HOST=0.0.0.0
ENV PORT=3000

# Comando para iniciar
CMD ["npm", "start"]