# Dockerfile para Backend Node.js Acees Group
FROM node:18-alpine

# Metadatos
LABEL maintainer="Acees Group"
LABEL description="Backend API Node.js para control de acceso"

# Directorio de trabajo
WORKDIR /app

# Copiar package files
COPY package*.json ./

# Instalar dependencias
RUN npm ci --only=production

# Instalar axios para comunicación con ML service
RUN npm install axios

# Copiar código fuente
COPY . .

# Crear directorio para uploads
RUN mkdir -p uploads

# Exponer puerto
EXPOSE 3000

# Variables de entorno por defecto
ENV NODE_ENV=production
ENV PORT=3000

# Comando por defecto
CMD ["node", "index.js"]