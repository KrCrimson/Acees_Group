const express = require('express');
const { MongoClient } = require('mongodb');
const router = express.Router();

// Configuración MongoDB - Usar la misma variable que index.js
const mongoUrl = process.env.MONGODB_URI || 'mongodb://localhost:27017';
const dbName = process.env.DB_NAME || 'ASISTENCIA';

let db;

// Conectar a MongoDB
MongoClient.connect(mongoUrl, { useUnifiedTopology: true })
  .then(client => {
    console.log('📸 Servicio de fotos conectado a MongoDB');
    console.log('🔗 URL MongoDB:', mongoUrl.replace(/\/\/[^:]+:[^@]+@/, '//***:***@')); // Ocultar credenciales
    console.log('🗃️ Base de datos:', dbName);
    db = client.db(dbName);
  })
  .catch(error => {
    console.error('❌ Error conectando a MongoDB:', error.message);
    console.error('🔗 URL intentada:', mongoUrl.replace(/\/\/[^:]+:[^@]+@/, '//***:***@'));
  });

// 🩺 ENDPOINT DE DIAGNÓSTICO
router.get('/health', async (req, res) => {
  try {
    const health = {
      service: 'fotos',
      timestamp: new Date().toISOString(),
      mongodb: {
        connected: !!db,
        url: mongoUrl.replace(/\/\/[^:]+:[^@]+@/, '//***:***@'),
        database: dbName
      }
    };
    
    if (db) {
      // Test de conexión
      const stats = await db.stats();
      health.mongodb.collections = stats.collections || 0;
    }
    
    res.json(health);
  } catch (error) {
    res.status(500).json({
      service: 'fotos',
      error: error.message,
      mongodb: {
        connected: false,
        url: mongoUrl.replace(/\/\/[^:]+:[^@]+@/, '//***:***@')
      }
    });
  }
});

// 📥 OBTENER FOTO DE ALUMNO
router.get('/alumno/:dni', async (req, res) => {
  try {
    const { dni } = req.params;
    
    console.log(`📷 Solicitando foto para DNI: ${dni}`);
    
    // Verificar conexión a base de datos
    if (!db) {
      console.error('❌ Base de datos no conectada');
      return res.status(503).json({ error: 'Servicio no disponible - DB desconectada' });
    }
    
    // Buscar por _id ya que los documentos usan _id personalizado en lugar de DNI
    const alumno = await db.collection('alumnos').findOne(
      { "_id": dni },
      { projection: { foto: 1, nombre: 1, apellido: 1 } }
    );

    if (!alumno) {
      console.log(`❌ Alumno no encontrado con ID: ${dni}`);
      return res.status(404).json({ error: 'Alumno no encontrado' });
    }

    if (!alumno.foto) {
      console.log(`📷 Sin foto para alumno: ${dni}`);
      return res.status(404).json({ error: 'Foto no encontrada' });
    }

    // Verificar formato Base64
    if (!alumno.foto.startsWith('data:image/')) {
      console.log(`⚠️ Formato de foto inválido para: ${dni}`);
      return res.status(400).json({ error: 'Formato de foto inválido' });
    }

    // Extraer datos base64
    const base64Data = alumno.foto.replace(/^data:image\/[^;]+;base64,/, '');
    const imageBuffer = Buffer.from(base64Data, 'base64');

    // Headers optimizados
    res.setHeader('Content-Type', 'image/jpeg');
    res.setHeader('Content-Length', imageBuffer.length);
    res.setHeader('Cache-Control', 'public, max-age=3600'); // Cache 1 hora
    res.setHeader('ETag', `"${dni}-photo"`);
    
    console.log(`✅ Foto servida para: ${alumno.nombre} ${alumno.apellido} (${dni})`);
    res.send(imageBuffer);

  } catch (error) {
    console.error('❌ Error obteniendo foto:', error);
    res.status(500).json({ 
      error: 'Error interno del servidor', 
      details: error.message,
      timestamp: new Date().toISOString() 
    });
  }
});

// 📊 VERIFICAR SI ALUMNO TIENE FOTO
router.get('/alumno/:dni/exists', async (req, res) => {
  try {
    const { dni } = req.params;
    
    const alumno = await db.collection('alumnos').findOne(
      { "DNI": dni },
      { projection: { foto: 1 } }
    );

    const tienePhoto = !!(alumno && alumno.foto && alumno.foto.length > 0);
    
    res.json({
      dni: dni,
      tiene_foto: tienePhoto,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('❌ Error verificando foto:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// 📈 ESTADÍSTICAS DE FOTOS
router.get('/stats', async (req, res) => {
  try {
    const stats = await db.collection('alumnos').aggregate([
      {
        $group: {
          _id: null,
          total_alumnos: { $sum: 1 },
          con_foto: { 
            $sum: { 
              $cond: [
                { 
                  $and: [
                    { $exists: "$foto" },
                    { $ne: ["$foto", ""] },
                    { $ne: ["$foto", null] }
                  ]
                }, 
                1, 
                0
              ] 
            }
          }
        }
      }
    ]).toArray();

    const result = stats[0] || { total_alumnos: 0, con_foto: 0 };
    const porcentaje = result.total_alumnos > 0 
      ? Math.round((result.con_foto / result.total_alumnos) * 100) 
      : 0;

    res.json({
      total_alumnos: result.total_alumnos,
      con_foto: result.con_foto,
      sin_foto: result.total_alumnos - result.con_foto,
      porcentaje_con_foto: porcentaje,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('❌ Error obteniendo estadísticas:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// 🔍 BUSCAR ALUMNOS CON FOTO
router.get('/alumnos-con-foto', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 50;
    const skip = parseInt(req.query.skip) || 0;

    const alumnos = await db.collection('alumnos').find(
      { 
        foto: { 
          $exists: true, 
          $ne: "", 
          $ne: null 
        } 
      },
      { 
        projection: { 
          DNI: 1, 
          nombre: 1, 
          apellido: 1, 
          siglas_facultad: 1,
          siglas_escuela: 1
        } 
      }
    )
    .limit(limit)
    .skip(skip)
    .toArray();

    res.json({
      alumnos: alumnos,
      total: alumnos.length,
      limit: limit,
      skip: skip,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('❌ Error buscando alumnos con foto:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

module.exports = router;