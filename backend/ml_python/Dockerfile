# Dockerfile optimizado para ML Python - Sistema ACEES Group
FROM python:3.11-slim

# Variables de entorno para optimización
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONPATH=/app
ENV ML_MODELS_PATH=/app/models/saved_models

# Crear usuario no-root para seguridad
RUN useradd --create-home --shell /bin/bash ml_user

# Instalar dependencias del sistema
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Crear directorio de trabajo
WORKDIR /app

# Copiar requirements e instalar dependencias Python
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt

# Copiar código fuente
COPY . .

# Crear directorios necesarios
RUN mkdir -p models/saved_models models/model_metadata models/backup_models
RUN mkdir -p logs data

# Cambiar propiedad a ml_user
RUN chown -R ml_user:ml_user /app

# Cambiar a usuario no-root
USER ml_user

# Puerto de exposición
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Comando por defecto
CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]