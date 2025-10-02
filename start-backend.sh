#!/bin/bash

# Script para desarrollo local - Acees Group Backend
echo "🚀 Iniciando Acees Group Backend..."

# Verificar si estamos en la carpeta correcta
if [ ! -f "backend/package.json" ]; then
    echo "❌ Error: Ejecuta este script desde la raíz del proyecto"
    exit 1
fi

# Cambiar a la carpeta backend
cd backend

# Verificar si existe .env
if [ ! -f ".env" ]; then
    echo "⚠️  No se encontró archivo .env"
    echo "📄 Creando .env desde .env.example..."
    cp .env.example .env
    echo "✅ Archivo .env creado. ¡Completa las variables de entorno!"
    echo "📝 Edita backend/.env con tus credenciales de MongoDB Atlas"
    exit 1
fi

# Instalar dependencias si no existen
if [ ! -d "node_modules" ]; then
    echo "📦 Instalando dependencias..."
    npm install
fi

# Verificar si MongoDB URI está configurado
if grep -q "tu_mongodb_uri_aqui" .env; then
    echo "❌ Error: Configura MONGODB_URI en backend/.env"
    echo "📝 Reemplaza 'tu_mongodb_uri_aqui' con tu URI de MongoDB Atlas"
    exit 1
fi

# Mostrar información
echo "📊 Configuración:"
echo "   - Puerto: ${PORT:-3000}"
echo "   - Entorno: ${NODE_ENV:-development}"
echo "   - MongoDB: Configurado ✅"

echo ""
echo "🌐 Servidor estará disponible en:"
echo "   - Local: http://localhost:${PORT:-3000}"
echo "   - Red: http://$(hostname -I | awk '{print $1}'):${PORT:-3000}"

echo ""
echo "📡 Endpoints disponibles:"
echo "   - Health: /api/health"
echo "   - Login: /login" 
echo "   - Alumnos: /alumnos"
echo "   - Asistencias: /asistencias"

echo ""
echo "🔄 Iniciando servidor..."
echo "   (Ctrl+C para detener)"

# Iniciar servidor
npm run dev