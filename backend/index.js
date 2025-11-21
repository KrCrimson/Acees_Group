// Backend completo con autenticación segura
require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const bcrypt = require('bcrypt');

const app = express();

// Configuración CORS optimizada para Railway
const corsOptions = {
  origin: [
    'http://localhost:3000',
    'http://192.168.1.51:3000',
    'http://localhost:8080',
    'http://127.0.0.1:8080',
    'https://acees-group-backend-production.up.railway.app',
    // Permitir cualquier origen en desarrollo
    ...(process.env.NODE_ENV !== 'production' ? ['*'] : [])
  ],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
};

app.use(cors(corsOptions));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Conexión a MongoDB Atlas optimizada para Railway
mongoose.set('strictQuery', false);

const connectDB = async () => {
  try {
    const conn = await mongoose.connect(process.env.MONGODB_URI, {
      dbName: 'ASISTENCIA',
      // Configuraciones optimizadas para Mongoose 8.x
      maxPoolSize: 10,
      serverSelectionTimeoutMS: 5000,
      socketTimeoutMS: 45000,
      family: 4 // Usar IPv4
    });

    console.log(`✅ MongoDB conectado: ${conn.connection.host}`);
  } catch (error) {
    console.error('❌ Error conectando a MongoDB:', error);
    process.exit(1);
  }
};

// Conectar a la base de datos
connectDB();

const db = mongoose.connection;
db.on('error', console.error.bind(console, '❌ Error de conexión MongoDB:'));
db.on('disconnected', () => console.log('⚠️ MongoDB desconectado'));
db.on('reconnected', () => console.log('🔄 MongoDB reconectado'));

// Función helper para obtener hora de Perú (UTC-5)
const getPeruDate = () => {
  const now = new Date();
  // Restar 5 horas (5 * 60 * 60 * 1000 ms)
  return new Date(now.getTime() - (5 * 60 * 60 * 1000));
};

// Endpoint de health check para verificar conectividad
app.get('/api/health', (req, res) => {
  res.status(200).json({
    status: 'OK',
    message: 'Server is running',
    timestamp: getPeruDate().toISOString(),
    database: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected'
  });
});

// Modelo de facultad - EXACTO como en MongoDB Atlas (campos como strings)
const FacultadSchema = new mongoose.Schema({
  _id: String,
  siglas: String,
  nombre: String
}, { collection: 'facultades', strict: false, _id: false });
const Facultad = mongoose.model('facultades', FacultadSchema);

// Modelo de escuela - EXACTO como en MongoDB Atlas
const EscuelaSchema = new mongoose.Schema({
  _id: String,
  nombre: String,
  siglas: String,
  siglas_facultad: String
}, { collection: 'escuelas', strict: false, _id: false });
const Escuela = mongoose.model('escuelas', EscuelaSchema);

// Modelo de asistencias - EXACTO como en MongoDB Atlas con nuevos campos
const AsistenciaSchema = new mongoose.Schema({
  _id: String,
  nombre: { type: String, required: true },
  apellido: { type: String, required: true },
  dni: { type: String, required: true, index: true },
  codigo_universitario: { type: String, required: true, index: true },
  siglas_facultad: { type: String, required: true },
  siglas_escuela: { type: String, required: true },
  tipo: { type: String, required: true, enum: ['entrada', 'salida'] },
  fecha_hora: { type: Date, required: true, default: getPeruDate },
  entrada_tipo: { type: String, required: true, default: 'nfc' },
  puerta: { type: String, required: true, default: 'Principal' },
  // Nuevos campos para US025-US030
  guardia_id: { type: String, required: true },
  guardia_nombre: { type: String, required: true },
  autorizacion_manual: { type: Boolean, default: false },
  razon_decision: String,
  timestamp_decision: Date,
  coordenadas: String,
  descripcion_ubicacion: String,
  estado: { type: String, default: 'autorizado', enum: ['autorizado', 'denegado'] }
}, {
  collection: 'asistencias',
  strict: false,
  _id: false,
  timestamps: false // Ya manejamos fecha_hora manualmente
});
const Asistencia = mongoose.model('asistencias', AsistenciaSchema);

// Modelo para decisiones manuales (US024-US025)
const DecisionManualSchema = new mongoose.Schema({
  _id: String,
  estudiante_id: String,
  estudiante_dni: String,
  estudiante_nombre: String,
  guardia_id: String,
  guardia_nombre: String,
  autorizado: Boolean,
  razon: String,
  timestamp: { type: Date, default: getPeruDate },
  punto_control: String,
  tipo_acceso: String,
  datos_estudiante: Object
}, { collection: 'decisiones_manuales', strict: false, _id: false });
const DecisionManual = mongoose.model('decisiones_manuales', DecisionManualSchema);

// Modelo para control de presencia (US026-US030)
const PresenciaSchema = new mongoose.Schema({
  _id: String,
  estudiante_id: String,
  estudiante_dni: String,
  estudiante_nombre: String,
  facultad: String,
  escuela: String,
  hora_entrada: Date,
  hora_salida: Date,
  punto_entrada: String,
  punto_salida: String,
  esta_dentro: { type: Boolean, default: true },
  guardia_entrada: String,
  guardia_salida: String,
  tiempo_en_campus: Number
}, { collection: 'presencia', strict: false, _id: false });
const Presencia = mongoose.model('presencia', PresenciaSchema);

// Modelo para sesiones activas de guardias (US059 - Múltiples guardias simultáneos)
const SessionGuardSchema = new mongoose.Schema({
  _id: String,
  guardia_id: String,
  guardia_nombre: String,
  punto_control: String,
  session_token: String,
  last_activity: { type: Date, default: getPeruDate },
  is_active: { type: Boolean, default: true },
  device_info: {
    platform: String,
    device_id: String,
    app_version: String
  },
  fecha_inicio: { type: Date, default: getPeruDate },
  fecha_fin: Date
}, { collection: 'sesiones_guardias', strict: false, _id: false });
const SessionGuard = mongoose.model('sesiones_guardias', SessionGuardSchema);

// Modelo de usuarios mejorado con validaciones - EXACTO como MongoDB Atlas
const UserSchema = new mongoose.Schema({
  _id: String,
  nombre: String,
  apellido: String,
  dni: { type: String, unique: true },
  email: { type: String, unique: true },
  password: String,
  rango: { type: String, enum: ['admin', 'guardia'], default: 'guardia' },
  estado: { type: String, enum: ['activo', 'inactivo'], default: 'activo' },
  puerta_acargo: String,
  telefono: String,
  fecha_creacion: { type: Date, default: getPeruDate },
  fecha_actualizacion: { type: Date, default: getPeruDate }
}, { collection: 'usuarios', strict: false, _id: false });

// Middleware para hashear contraseña antes de guardar
UserSchema.pre('save', async function (next) {
  if (!this.isModified('password')) return next();

  try {
    const saltRounds = 10;
    this.password = await bcrypt.hash(this.password, saltRounds);
    next();
  } catch (error) {
    next(error);
  }
});

// Método para comparar contraseñas
UserSchema.methods.comparePassword = async function (candidatePassword) {
  return bcrypt.compare(candidatePassword, this.password);
};

const User = mongoose.model('usuarios', UserSchema);

// Modelo de alumnos - EXACTO como en MongoDB Atlas
const AlumnoSchema = new mongoose.Schema({
  _id: String,
  _identificacion: String,
  nombre: String,
  apellido: String,
  dni: String,
  codigo_universitario: { type: String, unique: true, index: true },
  escuela_profesional: String,
  facultad: String,
  siglas_escuela: String,
  siglas_facultad: String,
  estado: { type: Boolean, default: true }
}, { collection: 'alumnos', strict: false, _id: false });
const Alumno = mongoose.model('alumnos', AlumnoSchema);

// Modelo de externos - EXACTO como en MongoDB Atlas
// Modelo de externos - ACTUALIZADO para registro completo
const ExternoSchema = new mongoose.Schema({
  _id: String,
  nombre_completo: { type: String, required: true },
  dni: { type: String, required: true, index: true },
  razon: { type: String, required: true },
  tipo: { type: String, required: true, enum: ['entrada', 'salida'], default: 'entrada' },
  estado: { type: String, default: 'autorizado' },
  descripcion_ubicacion: String,
  guardia_id: { type: String, required: true },
  guardia_nombre: { type: String, required: true },
  fecha_hora: { type: Date, default: getPeruDate }
}, { collection: 'externos', strict: false, _id: false });
const Externo = mongoose.model('externos', ExternoSchema);

// Modelo de visitas - EXACTO como en MongoDB Atlas
const VisitaSchema = new mongoose.Schema({
  _id: String,
  puerta: String,
  guardia_nombre: String,
  asunto: String,
  fecha_hora: Date,
  nombre: String,
  dni: String,
  facultad: String
}, { collection: 'visitas', strict: false, _id: false });
const Visita = mongoose.model('visitas', VisitaSchema);

// ==================== RUTAS ====================

// Ruta de prueba raíz
app.get('/', (req, res) => {
  res.json({
    message: "API Sistema Control Acceso NFC - FUNCIONANDO ✅",
    endpoints: {
      alumnos: "/alumnos",
      facultades: "/facultades",
      usuarios: "/usuarios",
      asistencias: "/asistencias",
      externos: "/externos",
      visitas: "/visitas",
      login: "/login"
    },
    database: "ASISTENCIA - MongoDB Atlas",
    status: "Sprint 1 Completo 🚀"
  });
});

// Ruta para obtener asistencias
app.get('/asistencias', async (req, res) => {
  try {
    const asistencias = await Asistencia.find();
    res.json(asistencias);
  } catch (err) {
    res.status(500).json({ error: 'Error al obtener asistencias' });
  }
});

// Ruta para obtener SOLO asistencias con guardia (registros válidos)
app.get('/asistencias/con-guardia', async (req, res) => {
  try {
    const filtro = {
      guardia_id: {
        $exists: true,
        $ne: null,
        $ne: "",
        $ne: "SIN_GUARDIA",
        $ne: "SIN_GUARDIA_ERROR"
      },
      guardia_nombre: {
        $exists: true,
        $ne: null,
        $ne: "",
        $ne: "Guardia No Identificado",
        $ne: "GUARDIA_NO_IDENTIFICADO"
      }
    };

    const asistencias = await Asistencia.find(filtro).sort({ fecha_hora: -1 });

    console.log(`📊 Asistencias con guardia encontradas: ${asistencias.length}`);

    res.json({
      total: asistencias.length,
      asistencias: asistencias
    });
  } catch (err) {
    console.error('❌ Error al obtener asistencias con guardia:', err);
    res.status(500).json({ error: 'Error al obtener asistencias con guardia' });
  }
});

// Ruta para obtener estadísticas de HOY (entradas vs salidas)
app.get('/asistencias/hoy', async (req, res) => {
  try {
    // Obtener inicio y fin del día actual
    const inicioHoy = new Date();
    inicioHoy.setHours(0, 0, 0, 0);
    
    const finHoy = new Date();
    finHoy.setHours(23, 59, 59, 999);

    // Contar entradas de hoy
    const entradasHoy = await Asistencia.countDocuments({
      tipo: 'entrada',
      fecha_hora: {
        $gte: inicioHoy.toISOString(),
        $lte: finHoy.toISOString()
      }
    });

    // Contar salidas de hoy
    const salidasHoy = await Asistencia.countDocuments({
      tipo: 'salida',
      fecha_hora: {
        $gte: inicioHoy.toISOString(),
        $lte: finHoy.toISOString()
      }
    });

    // Total de hoy
    const totalHoy = entradasHoy + salidasHoy;

    res.json({
      fecha: inicioHoy.toISOString().split('T')[0],
      entradas: entradasHoy,
      salidas: salidasHoy,
      total: totalHoy
    });
  } catch (err) {
    console.error('❌ Error al obtener estadísticas de hoy:', err);
    res.status(500).json({ error: 'Error al obtener estadísticas de hoy' });
  }
});

// Ruta para obtener estadísticas de asistencias
app.get('/asistencias/estadisticas', async (req, res) => {
  try {
    const totalRegistros = await Asistencia.countDocuments();

    const conGuardia = await Asistencia.countDocuments({
      guardia_id: {
        $exists: true,
        $ne: null,
        $ne: "",
        $ne: "SIN_GUARDIA",
        $ne: "SIN_GUARDIA_ERROR"
      }
    });

    const sinGuardia = totalRegistros - conGuardia;

    res.json({
      total_registros: totalRegistros,
      con_guardia: conGuardia,
      sin_guardia: sinGuardia,
      porcentaje_con_guardia: ((conGuardia / totalRegistros) * 100).toFixed(2) + '%'
    });
  } catch (err) {
    console.error('❌ Error al obtener estadísticas:', err);
    res.status(500).json({ error: 'Error al obtener estadísticas' });
  }
});

// Ruta para obtener facultades - FIXED
app.get('/facultades', async (req, res) => {
  try {
    const facultades = await Facultad.find();
    res.json(facultades);
  } catch (err) {
    res.status(500).json({ error: 'Error al obtener facultades' });
  }
});

// Ruta para obtener escuelas por facultad
app.get('/escuelas', async (req, res) => {
  const { siglas_facultad } = req.query;
  try {
    let escuelas;
    if (siglas_facultad) {
      escuelas = await Escuela.find({ siglas_facultad });
    } else {
      escuelas = await Escuela.find();
    }
    res.json(escuelas);
  } catch (err) {
    res.status(500).json({ error: 'Error al obtener escuelas' });
  }
});

// Ruta para obtener usuarios (sin contraseñas)
app.get('/usuarios', async (req, res) => {
  try {
    const users = await User.find().select('-password');
    res.json(users);
  } catch (err) {
    res.status(500).json({ error: 'Error al obtener usuarios' });
  }
});

// Ruta para crear usuario con contraseña encriptada
app.post('/usuarios', async (req, res) => {
  try {
    const { nombre, apellido, dni, email, password, rango, puerta_acargo, telefono } = req.body;

    // Validar campos requeridos
    if (!nombre || !apellido || !dni || !email || !password) {
      return res.status(400).json({ error: 'Faltan campos requeridos' });
    }

    // Generar ID único
    const generateUserId = () => {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
      let result = '';
      for (let i = 0; i < 28; i++) {
        result += chars.charAt(Math.floor(Math.random() * chars.length));
      }
      return result;
    };

    // Crear usuario (la contraseña se hashea automáticamente)
    const user = new User({
      _id: generateUserId(),
      nombre,
      apellido,
      dni,
      email,
      password,
      rango: rango || 'guardia',
      puerta_acargo: puerta_acargo || '',
      telefono: telefono || '',
      estado: 'activo',
      fecha_creacion: new Date(),
      fecha_actualizacion: new Date()
    });

    await user.save();

    // Responder sin la contraseña
    const userResponse = user.toObject();
    delete userResponse.password;

    res.status(201).json(userResponse);
  } catch (err) {
    console.error('Error creando usuario:', err);
    if (err.code === 11000) {
      res.status(400).json({ error: 'DNI o email ya existe' });
    } else {
      res.status(500).json({ error: 'Error al crear usuario: ' + err.message });
    }
  }
});

// Ruta para cambiar contraseña
app.put('/usuarios/:id/password', async (req, res) => {
  try {
    const { password } = req.body;

    if (!password) {
      return res.status(400).json({ error: 'Contraseña requerida' });
    }

    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }

    user.password = password; // Se hashea automáticamente
    user.fecha_actualizacion = new Date();
    await user.save();

    res.json({ message: 'Contraseña actualizada exitosamente' });
  } catch (err) {
    console.error('Error actualizando contraseña:', err);
    res.status(500).json({ error: 'Error al actualizar contraseña: ' + err.message });
  }
});

// Ruta de login segura
app.post('/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    // Buscar usuario por email
    const user = await User.findOne({ email, estado: 'activo' });
    if (!user) {
      return res.status(401).json({ error: 'Credenciales incorrectas' });
    }

    // Verificar contraseña con bcrypt
    const isPasswordValid = await user.comparePassword(password);
    if (!isPasswordValid) {
      return res.status(401).json({ error: 'Credenciales incorrectas' });
    }

    // Enviar datos del usuario (sin contraseña)
    res.json({
      id: user._id,
      nombre: user.nombre,
      apellido: user.apellido,
      email: user.email,
      dni: user.dni,
      rango: user.rango,
      puerta_acargo: user.puerta_acargo,
      estado: user.estado
    });
  } catch (err) {
    res.status(500).json({ error: 'Error en el servidor' });
  }
});

// Ruta para actualizar usuario
app.put('/usuarios/:id', async (req, res) => {
  try {
    const { password, ...updateData } = req.body;

    updateData.fecha_actualizacion = new Date();

    const user = await User.findByIdAndUpdate(
      req.params.id,
      updateData,
      { new: true }
    ).select('-password');

    if (!user) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }

    res.json(user);
  } catch (err) {
    res.status(500).json({ error: 'Error al actualizar usuario' });
  }
});

// Ruta para obtener usuario por ID
app.get('/usuarios/:id', async (req, res) => {
  try {
    const user = await User.findById(req.params.id).select('-password');
    if (!user) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }
    res.json(user);
  } catch (err) {
    res.status(500).json({ error: 'Error al obtener usuario' });
  }
});

// ==================== ENDPOINTS ALUMNOS ====================

// Ruta para buscar alumno por código universitario (CRÍTICO para NFC)
app.get('/alumnos/:codigo', async (req, res) => {
  try {
    const alumno = await Alumno.findOne({
      codigo_universitario: req.params.codigo
    });

    if (!alumno) {
      return res.status(404).json({ error: 'Alumno no encontrado' });
    }

    // Validar que el alumno esté matriculado (estado = true)
    if (!alumno.estado) {
      return res.status(403).json({
        error: 'Alumno no matriculado o inactivo',
        alumno: {
          nombre: alumno.nombre,
          apellido: alumno.apellido,
          codigo_universitario: alumno.codigo_universitario
        }
      });
    }

    res.json(alumno);
  } catch (err) {
    res.status(500).json({ error: 'Error al buscar alumno' });
  }
});

// Ruta para obtener todos los alumnos
app.get('/alumnos', async (req, res) => {
  try {
    const alumnos = await Alumno.find();
    res.json(alumnos);
  } catch (err) {
    res.status(500).json({ error: 'Error al obtener alumnos' });
  }
});

// ==================== ENDPOINTS EXTERNOS ====================

// Ruta para buscar externo por DNI
app.get('/externos/:dni', async (req, res) => {
  try {
    const externo = await Externo.findOne({ dni: req.params.dni });
    if (!externo) {
      return res.status(404).json({ error: 'Externo no encontrado' });
    }
    res.json(externo);
  } catch (err) {
    res.status(500).json({ error: 'Error al buscar externo' });
  }
});

// Ruta para obtener todos los externos
app.get('/externos', async (req, res) => {
  try {
    const externos = await Externo.find();
    res.json(externos);
  } catch (err) {
    res.status(500).json({ error: 'Error al obtener externos' });
  }
});

// Función para validar datos completos de asistencia
function validarDatosAsistencia(datos) {
  const camposRequeridos = [
    'dni', 'nombre', 'apellido', 'codigo_universitario',
    'siglas_facultad', 'siglas_escuela', 'tipo',
    'guardia_id', 'guardia_nombre'
  ];

  const camposFaltantes = camposRequeridos.filter(campo => !datos[campo] || datos[campo] === '');

  if (camposFaltantes.length > 0) {
    throw new Error(`Campos requeridos faltantes: ${camposFaltantes.join(', ')}`);
  }

  if (!['entrada', 'salida'].includes(datos.tipo)) {
    throw new Error('Tipo debe ser "entrada" o "salida"');
  }

  // Validar que el guardia no sea un valor de error
  if (datos.guardia_id === 'SIN_GUARDIA' || datos.guardia_id === 'SIN_GUARDIA_ERROR') {
    throw new Error('Error: Guardia no configurado correctamente');
  }

  if (datos.guardia_nombre === 'Guardia No Identificado' || datos.guardia_nombre === 'GUARDIA_NO_IDENTIFICADO') {
    throw new Error('Error: Nombre del guardia no válido');
  }

  return true;
}

// Ruta para registrar asistencia completa (US025-US030)
app.post('/asistencias/completa', async (req, res) => {
  try {
    console.log('📝 Datos recibidos para asistencia:', JSON.stringify(req.body, null, 2));

    // Validar datos completos
    validarDatosAsistencia(req.body);

    // Asegurar que tenga todos los campos necesarios
    const datosCompletos = {
      ...req.body,
      fecha_hora: req.body.fecha_hora || getPeruDate().toISOString(),
      entrada_tipo: req.body.entrada_tipo || 'nfc',
      puerta: req.body.puerta || 'Principal',
      autorizacion_manual: req.body.autorizacion_manual || false,
      version_registro: req.body.version_registro || 'v2_con_guardia',
      version_registro: req.body.version_registro || 'v2_con_guardia',
      // Timestamp de creación para auditoría
      timestamp_creacion: getPeruDate().toISOString(),
      // Asegurar que campos opcionales existan como null si no vienen
      razon_decision: req.body.razon_decision || null,
      timestamp_decision: req.body.timestamp_decision || null,
      coordenadas: req.body.coordenadas || null,
      descripcion_ubicacion: req.body.descripcion_ubicacion || null,
      estado: req.body.estado || 'autorizado'
    };

    console.log('📝 Guardando asistencia con datos completos:', {
      dni: datosCompletos.dni,
      nombre: datosCompletos.nombre,
      apellido: datosCompletos.apellido,
      tipo: datosCompletos.tipo,
      codigo_universitario: datosCompletos.codigo_universitario,
      siglas_facultad: datosCompletos.siglas_facultad,
      siglas_escuela: datosCompletos.siglas_escuela,
      guardia_id: datosCompletos.guardia_id,
      guardia_nombre: datosCompletos.guardia_nombre,
      puerta: datosCompletos.puerta,
      fecha_hora: datosCompletos.fecha_hora
    });

    const asistencia = new Asistencia(datosCompletos);
    const savedAsistencia = await asistencia.save();

    console.log('✅ Asistencia guardada exitosamente con ID:', savedAsistencia._id);
    res.status(201).json(savedAsistencia);
  } catch (err) {
    console.error('❌ Error al registrar asistencia:', err.message);
    res.status(500).json({
      error: 'Error al registrar asistencia completa',
      details: err.message
    });
  }
});

// Verificar estado de asistencias por estudiante
app.get('/asistencias/verificar/:dni', async (req, res) => {
  try {
    const { dni } = req.params;
    const asistencias = await Asistencia.find({ dni }).sort({ fecha_hora: -1 }).limit(10);

    console.log(`🔍 Verificando asistencias para DNI ${dni}:`, asistencias.length, 'registros encontrados');

    res.json({
      dni: dni,
      total_registros: asistencias.length,
      ultima_asistencia: asistencias[0] || null,
      historial_reciente: asistencias
    });
  } catch (err) {
    console.error('❌ Error al verificar asistencias:', err);
    res.status(500).json({ error: 'Error al verificar asistencias' });
  }
});

// Determinar último tipo de acceso para entrada/salida inteligente (US028)
app.get('/asistencias/ultimo-acceso/:dni', async (req, res) => {
  try {
    const { dni } = req.params;
    // MODIFICADO: Ignorar denegados para que el ciclo se reinicie correctamente
    const ultimaAsistencia = await Asistencia.findOne({
      dni,
      estado: { $ne: 'denegado' }
    }).sort({ fecha_hora: -1 });

    console.log(`🔍 Último acceso VÁLIDO para DNI ${dni}:`, ultimaAsistencia ? ultimaAsistencia.tipo : 'sin registros');

    if (ultimaAsistencia) {
      res.json({ ultimo_tipo: ultimaAsistencia.tipo });
    } else {
      res.json({ ultimo_tipo: 'salida' }); // Si no hay registros, próximo debería ser entrada
    }
  } catch (err) {
    console.error('❌ Error al determinar último acceso:', err);
    res.status(500).json({ error: 'Error al determinar último acceso' });
  }
});

// Obtener asistencias de un guardia específico (últimas 24 horas)
app.get('/asistencias/guardia/:guardiaId', async (req, res) => {
  try {
    const { guardiaId } = req.params;
    const hace24Horas = new Date(Date.now() - 24 * 60 * 60 * 1000);

    console.log(`🔍 Buscando asistencias del guardia ${guardiaId} desde ${hace24Horas}`);

    const asistencias = await Asistencia.find({
      guardia_id: guardiaId,
      fecha_hora: { $gte: hace24Horas }
    }).sort({ fecha_hora: -1 });

    console.log(`✅ Encontradas ${asistencias.length} asistencias del guardia ${guardiaId}`);
    res.json(asistencias);
  } catch (err) {
    console.error('❌ Error al obtener asistencias del guardia:', err);
    res.status(500).json({ error: 'Error al obtener asistencias del guardia' });
  }
});

// Actualizar estado de asistencia (Autorizar/Denegar) y Sincronizar Presencia
// Actualizar estado de asistencia (Autorizar/Denegar) y Sincronizar Presencia
app.put('/asistencias/:id/estado', async (req, res) => {
  try {
    const { id } = req.params;
    const { estado, razon_decision } = req.body;

    if (!['autorizado', 'denegado'].includes(estado)) {
      return res.status(400).json({ error: 'Estado inválido' });
    }

    // Buscar asistencia original para validar tiempos
    const asistenciaOriginal = await Asistencia.findById(id);
    if (!asistenciaOriginal) {
      return res.status(404).json({ error: 'Asistencia no encontrada' });
    }

    const ahora = getPeruDate();
    const LIMITE_TIEMPO_MS = 5 * 60 * 1000; // 5 minutos

    // VALIDACIÓN DE TIEMPO PARA DENEGAR
    if (estado === 'denegado') {
      const tiempoTranscurrido = ahora - new Date(asistenciaOriginal.fecha_hora);
      if (tiempoTranscurrido > LIMITE_TIEMPO_MS) {
        return res.status(400).json({
          error: 'Tiempo límite excedido',
          message: 'Solo se puede denegar una entrada dentro de los 5 minutos posteriores al registro.'
        });
      }
    }

    // VALIDACIÓN DE TIEMPO PARA REVERTIR (Denegado -> Autorizado)
    if (estado === 'autorizado' && asistenciaOriginal.estado === 'denegado') {
      if (!asistenciaOriginal.timestamp_decision) {
        // Si no hay timestamp de decisión, asumimos que es antiguo o manual, bloquear por seguridad
        // O permitir si es reciente la fecha_hora. Usaremos fecha_hora como fallback.
      } else {
        const tiempoDesdeDenegacion = ahora - new Date(asistenciaOriginal.timestamp_decision);
        if (tiempoDesdeDenegacion > LIMITE_TIEMPO_MS) {
          return res.status(400).json({
            error: 'Tiempo límite excedido',
            message: 'Solo se puede revertir una denegación dentro de los 5 minutos posteriores a la decisión.'
          });
        }
      }
    }

    const updateData = {
      estado,
      razon_decision: razon_decision || null,
      timestamp_decision: getPeruDate()
    };

    const asistencia = await Asistencia.findByIdAndUpdate(
      id,
      updateData,
      { new: true }
    );

    // --- LÓGICA DE SINCRONIZACIÓN CON PRESENCIA (SOFT DELETE) ---
    if (asistencia.tipo === 'entrada') {
      if (estado === 'denegado') {
        // EN LUGAR DE BORRAR, MARCAR COMO SALIDA ESPECIAL
        // Buscar si está dentro actualmente
        const presencia = await Presencia.findOne({
          estudiante_dni: asistencia.dni,
          esta_dentro: true
        });

        if (presencia) {
          presencia.esta_dentro = false;
          presencia.punto_salida = 'ENTRADA_DENEGADA'; // Marcador especial
          presencia.hora_salida = getPeruDate();
          presencia.guardia_salida = asistencia.guardia_id; // El guardia que denegó
          presencia.tiempo_en_campus = 0; // No contó como tiempo válido

          await presencia.save();
          console.log(`🚫 Presencia invalidada (Soft Delete) para DNI ${asistencia.dni} por denegación de acceso`);
        }
      } else if (estado === 'autorizado') {
        // Si se autoriza (corrección), asegurar que esté en presencia
        const presenciaExiste = await Presencia.findOne({
          estudiante_dni: asistencia.dni,
          esta_dentro: true
        });

        if (!presenciaExiste) {
          // Buscar datos del alumno para crear presencia
          const alumno = await Alumno.findOne({ dni: asistencia.dni });
          if (alumno) {
            const nuevaPresencia = new Presencia({
              _id: new mongoose.Types.ObjectId().toString(),
              estudiante_id: alumno._id,
              estudiante_dni: asistencia.dni,
              estudiante_nombre: `${asistencia.nombre} ${asistencia.apellido}`,
              facultad: asistencia.siglas_facultad,
              escuela: asistencia.siglas_escuela,
              hora_entrada: asistencia.fecha_hora, // Mantener hora original
              punto_entrada: asistencia.puerta,
              esta_dentro: true,
              guardia_entrada: asistencia.guardia_id
            });
            await nuevaPresencia.save();
            console.log(`✅ Presencia restaurada para DNI ${asistencia.dni} por autorización manual`);
          }
        }
      }
    }
    // ----------------------------------------------

    res.json(asistencia);
  } catch (err) {
    console.error('❌ Error al actualizar estado de asistencia:', err);
    res.status(500).json({ error: 'Error al actualizar estado' });
  }
});

// ==================== ENDPOINTS DECISIONES MANUALES (US024-US025) ====================

// Registrar decisión manual del guardia
app.post('/decisiones-manuales', async (req, res) => {
  try {
    const decision = new DecisionManual(req.body);
    await decision.save();
    res.status(201).json(decision);
  } catch (err) {
    res.status(500).json({ error: 'Error al registrar decisión manual', details: err.message });
  }
});

// Obtener decisiones de un guardia específico
app.get('/decisiones-manuales/guardia/:guardiaId', async (req, res) => {
  try {
    const { guardiaId } = req.params;
    const decisiones = await DecisionManual.find({ guardia_id: guardiaId }).sort({ timestamp: -1 });
    res.json(decisiones);
  } catch (err) {
    res.status(500).json({ error: 'Error al obtener decisiones del guardia' });
  }
});

// Obtener todas las decisiones manuales (para reportes)
app.get('/decisiones-manuales', async (req, res) => {
  try {
    const decisiones = await DecisionManual.find().sort({ timestamp: -1 });
    res.json(decisiones);
  } catch (err) {
    res.status(500).json({ error: 'Error al obtener decisiones manuales' });
  }
});

// ==================== ENDPOINTS CONTROL DE PRESENCIA (US026-US030) ====================

// Obtener presencia actual en el campus
app.get('/presencia', async (req, res) => {
  try {
    const presencias = await Presencia.find({ esta_dentro: true });
    res.json(presencias);
  } catch (err) {
    res.status(500).json({ error: 'Error al obtener presencia actual' });
  }
});

// Actualizar presencia de un estudiante
app.post('/presencia/actualizar', async (req, res) => {
  try {
    const { estudiante_dni, tipo_acceso, punto_control, guardia_id } = req.body;

    if (tipo_acceso === 'entrada') {
      // Crear nueva presencia o actualizar existente
      const presenciaExistente = await Presencia.findOne({ estudiante_dni, esta_dentro: true });

      if (presenciaExistente) {
        // Ya está dentro, posible error
        res.status(400).json({ error: 'El estudiante ya se encuentra en el campus' });
        return;
      }

      // Obtener datos del estudiante para la presencia
      const estudiante = await Alumno.findOne({ dni: estudiante_dni });
      if (!estudiante) {
        res.status(404).json({ error: 'Estudiante no encontrado' });
        return;
      }

      const nuevaPresencia = new Presencia({
        _id: new mongoose.Types.ObjectId().toString(),
        estudiante_id: estudiante._id,
        estudiante_dni,
        estudiante_nombre: `${estudiante.nombre} ${estudiante.apellido}`,
        facultad: estudiante.siglas_facultad,
        escuela: estudiante.siglas_escuela,
        hora_entrada: getPeruDate(),
        punto_entrada: punto_control,
        esta_dentro: true,
        guardia_entrada: guardia_id
      });

      await nuevaPresencia.save();
      res.json(nuevaPresencia);

    } else if (tipo_acceso === 'salida') {
      // Actualizar presencia existente
      const presencia = await Presencia.findOne({ estudiante_dni, esta_dentro: true });

      if (!presencia) {
        res.status(400).json({ error: 'El estudiante no se encuentra registrado como presente' });
        return;
      }

      const horaSalida = getPeruDate();
      const tiempoEnCampus = horaSalida - presencia.hora_entrada;

      presencia.hora_salida = horaSalida;
      presencia.punto_salida = punto_control;
      presencia.esta_dentro = false;
      presencia.guardia_salida = guardia_id;
      presencia.tiempo_en_campus = tiempoEnCampus;

      await presencia.save();
      res.json(presencia);
    }

  } catch (err) {
    res.status(500).json({ error: 'Error al actualizar presencia', details: err.message });
  }
});

// Obtener historial completo de presencia
app.get('/presencia/historial', async (req, res) => {
  try {
    const historial = await Presencia.find().sort({ hora_entrada: -1 });
    res.json(historial);
  } catch (err) {
    res.status(500).json({ error: 'Error al obtener historial de presencia' });
  }
});

// Obtener personas que llevan mucho tiempo en campus
app.get('/presencia/largo-tiempo', async (req, res) => {
  try {
    const ahora = new Date();
    const hace8Horas = new Date(ahora - 8 * 60 * 60 * 1000);

    const presenciasLargas = await Presencia.find({
      esta_dentro: true,
      hora_entrada: { $lte: hace8Horas }
    });

    res.json(presenciasLargas);
  } catch (err) {
    res.status(500).json({ error: 'Error al obtener presencias de largo tiempo' });
  }
});

// ==================== ENDPOINTS SESIONES GUARDIAS (US059) ====================

// Middleware de concurrencia para verificar conflictos
const concurrencyMiddleware = async (req, res, next) => {
  try {
    const { guardia_id, punto_control } = req.body;

    // Verificar si otro guardia está activo en el mismo punto de control
    const sessionActiva = await SessionGuard.findOne({
      punto_control,
      is_active: true,
      guardia_id: { $ne: guardia_id }
    });

    if (sessionActiva) {
      return res.status(409).json({
        error: 'Otro guardia está activo en este punto de control',
        conflict: true,
        active_guard: {
          guardia_id: sessionActiva.guardia_id,
          guardia_nombre: sessionActiva.guardia_nombre,
          session_start: sessionActiva.fecha_inicio,
          last_activity: sessionActiva.last_activity
        }
      });
    }

    next();
  } catch (err) {
    res.status(500).json({ error: 'Error verificando concurrencia', details: err.message });
  }
};

// Ruta para registrar visita externa
app.post('/externos', async (req, res) => {
  try {
    console.log('🔍 [EXTERNOS] Request recibido:', req.body);

    const {
      nombre_completo,
      dni,
      razon,
      guardia_id,
      guardia_nombre,
      descripcion_ubicacion,
      tipo
    } = req.body;

    // Validación básica
    if (!nombre_completo || !dni || !razon || !guardia_id) {
      console.log('❌ [EXTERNOS] Faltan datos requeridos');
      return res.status(400).json({ error: 'Faltan datos requeridos' });
    }

    const nuevoExterno = new Externo({
      _id: new mongoose.Types.ObjectId().toString(),
      nombre_completo,
      dni,
      razon,
      tipo: tipo || 'entrada',
      estado: 'autorizado',
      descripcion_ubicacion,
      guardia_id,
      guardia_nombre,
      fecha_hora: getPeruDate()
    });

    await nuevoExterno.save();
    console.log('✅ [EXTERNOS] Registrado exitosamente:', nuevoExterno._id);
    res.status(201).json(nuevoExterno);
  } catch (error) {
    console.error('❌ [EXTERNOS] Error:', error);
    res.status(500).json({ error: 'Error al registrar visita externa', details: error.message });
  }
});

// Iniciar sesión de guardia
app.post('/sesiones/iniciar', concurrencyMiddleware, async (req, res) => {
  try {
    console.log('🔍 [SESIONES-INICIAR] Request recibido:', JSON.stringify(req.body, null, 2));
    const { guardia_id, guardia_nombre, punto_control, device_info } = req.body;

    if (!guardia_id || !guardia_nombre || !punto_control) {
      console.log('❌ [SESIONES-INICIAR] Faltan datos requeridos');
      return res.status(400).json({ error: 'Faltan datos requeridos: guardia_id, guardia_nombre, punto_control' });
    }

    console.log(`🔍 [SESIONES-INICIAR] Finalizando sesiones anteriores del guardia: ${guardia_id}`);
    // Finalizar cualquier sesión anterior del mismo guardia
    const sesionesAnteriores = await SessionGuard.updateMany(
      { guardia_id, is_active: true },
      {
        is_active: false,
        fecha_fin: getPeruDate()
      }
    );
    console.log(`✅ [SESIONES-INICIAR] Sesiones anteriores finalizadas: ${sesionesAnteriores.modifiedCount}`);

    // Crear nueva sesión
    const sessionToken = require('crypto').randomUUID();
    const ahora = getPeruDate();
    const nuevaSesion = new SessionGuard({
      _id: sessionToken,
      guardia_id,
      guardia_nombre,
      punto_control,
      session_token: sessionToken,
      device_info: device_info || {},
      last_activity: ahora,
      is_active: true,
      fecha_inicio: ahora
    });

    await nuevaSesion.save();
    console.log(`✅ [SESIONES-INICIAR] Nueva sesión creada:`, {
      session_token: sessionToken,
      guardia_id,
      guardia_nombre,
      punto_control,
      fecha_inicio: ahora,
      is_active: true
    });

    res.status(201).json({
      session_token: sessionToken,
      message: 'Sesión iniciada exitosamente',
      session: nuevaSesion
    });
  } catch (err) {
    console.error('❌ [SESIONES-INICIAR] Error:', err);
    res.status(500).json({ error: 'Error al iniciar sesión', details: err.message });
  }
});

// Actualizar actividad de sesión (heartbeat)
app.post('/sesiones/heartbeat', async (req, res) => {
  try {
    console.log('🔍 [SESIONES-HEARTBEAT] Request:', req.body);
    const { session_token } = req.body;

    if (!session_token) {
      console.log('❌ [SESIONES-HEARTBEAT] Falta session_token');
      return res.status(400).json({ error: 'session_token es requerido' });
    }

    const ahora = getPeruDate();
    const sesion = await SessionGuard.findOneAndUpdate(
      { session_token, is_active: true },
      { last_activity: ahora },
      { new: true }
    );

    if (!sesion) {
      console.log('❌ [SESIONES-HEARTBEAT] Sesión no encontrada:', session_token);
      return res.status(404).json({ error: 'Sesión no encontrada' });
    }

    console.log(`✅ [SESIONES-HEARTBEAT] Actividad actualizada para sesión: ${session_token}`);
    res.json({
      message: 'Actividad actualizada',
      last_activity: sesion.last_activity
    });
  } catch (err) {
    console.error('❌ [SESIONES-HEARTBEAT] Error:', err);
    res.status(500).json({ error: 'Error al actualizar actividad', details: err.message });
  }
});

// Finalizar sesión
app.post('/sesiones/finalizar', async (req, res) => {
  try {
    console.log('🔍 [SESIONES] Request finalizar:', req.body);
    const { session_token } = req.body;

    if (!session_token) {
      console.log('❌ [SESIONES] Falta session_token');
      return res.status(400).json({ error: 'session_token es requerido' });
    }

    const sesion = await SessionGuard.findOneAndUpdate(
      { session_token, is_active: true },
      {
        is_active: false,
        fecha_fin: getPeruDate()
      },
      { new: true }
    );

    if (!sesion) {
      console.log('❌ [SESIONES] Sesión no encontrada:', session_token);
      return res.status(404).json({ error: 'Sesión no encontrada o ya finalizada' });
    }

    console.log('✅ [SESIONES] Sesión finalizada:', sesion._id);
    res.json({ message: 'Sesión finalizada exitosamente', sesion });
  } catch (err) {
    console.error('❌ [SESIONES] Error:', err);
    res.status(500).json({ error: 'Error al finalizar sesión', details: err.message });
  }
});

// Obtener sesiones activas
app.get('/sesiones/activas', async (req, res) => {
  try {
    console.log('🔍 [SESIONES-ACTIVAS] Consultando sesiones activas...');
    const sesionesActivas = await SessionGuard.find({ is_active: true });
    console.log(`✅ [SESIONES-ACTIVAS] Encontradas ${sesionesActivas.length} sesiones activas`);
    res.json(sesionesActivas);
  } catch (err) {
    console.error('❌ [SESIONES-ACTIVAS] Error:', err);
    res.status(500).json({ error: 'Error al obtener sesiones activas', details: err.message });
  }
});

// Forzar finalización de sesión (admin)
app.post('/sesiones/forzar-finalizacion', async (req, res) => {
  try {
    console.log('🔍 [SESIONES-FORZAR] Request:', req.body);
    const { session_token, admin_id } = req.body;

    if (!session_token) {
      console.log('❌ [SESIONES-FORZAR] Falta session_token');
      return res.status(400).json({ error: 'session_token es requerido' });
    }

    // Si no se proporciona session_token específico, finalizar todas las activas
    const filter = session_token === 'all' ? { is_active: true } : { session_token, is_active: true };
    console.log('🔍 [SESIONES-FORZAR] Filtro:', filter);

    const ahora = getPeruDate();
    const resultado = await SessionGuard.updateMany(
      filter,
      {
        is_active: false,
        fecha_fin: ahora,
        forced_by_admin: admin_id || 'unknown'
      }
    );

    console.log(`✅ [SESIONES-FORZAR] ${resultado.modifiedCount} sesión(es) finalizada(s)`);
    res.json({ message: `${resultado.modifiedCount} sesión(es) finalizada(s)` });
  } catch (err) {
    console.error('❌ [SESIONES-FORZAR] Error:', err);
    res.status(500).json({ error: 'Error al forzar finalización', details: err.message });
  }
});

// ==================== ENDPOINTS ASISTENCIAS EXISTENTES ====================

// Ruta para crear nueva asistencia (CRÍTICO para registrar accesos)
app.post('/asistencias', async (req, res) => {
  try {
    const asistencia = new Asistencia(req.body);
    await asistencia.save();
    res.status(201).json(asistencia);
  } catch (err) {
    res.status(500).json({ error: 'Error al registrar asistencia', details: err.message });
  }
});

// ==================== ENDPOINTS VISITAS ====================

// Ruta para crear nueva visita
app.post('/visitas', async (req, res) => {
  try {
    const visita = new Visita(req.body);
    await visita.save();
    res.status(201).json(visita);
  } catch (err) {
    res.status(500).json({ error: 'Error al registrar visita', details: err.message });
  }
});

// Ruta para obtener todas las visitas
app.get('/visitas', async (req, res) => {
  try {
    const visitas = await Visita.find();
    res.json(visitas);
  } catch (err) {
    res.status(500).json({ error: 'Error al obtener visitas' });
  }
});

// ==================== MACHINE LEARNING & ANÁLISIS DE BUSES NOCTURNOS ====================

// Modelo para almacenar recomendaciones de buses nocturnos
const RecomendacionBusSchema = new mongoose.Schema({
  _id: String,
  fecha_analisis: { type: Date, default: Date.now },
  horario_recomendado: String, // "20:00", "21:00", "22:00", etc.
  numero_buses_sugeridos: Number,
  capacidad_estimada: Number,
  estudiantes_esperados: Number,
  porcentaje_ocupacion: Number,
  facultades_principales: [String],
  justificacion: String,
  datos_historicos_utilizados: Object,
  modelo_version: String,
  confianza_prediccion: Number
}, { collection: 'recomendaciones_buses', strict: false, _id: false });
const RecomendacionBus = mongoose.model('recomendaciones_buses', RecomendacionBusSchema);

// 🔍 ENDPOINT 1: Obtener datos históricos para el modelo ML
app.get('/ml/datos-historicos', async (req, res) => {
  try {
    const { fecha_inicio, fecha_fin, dias_semana } = req.query;

    // Construir filtro de fechas
    let filtroFecha = {};
    if (fecha_inicio && fecha_fin) {
      filtroFecha = {
        fecha_hora: {
          $gte: new Date(fecha_inicio),
          $lte: new Date(fecha_fin)
        }
      };
    } else {
      // Por defecto, últimos 30 días
      const hace30Dias = new Date();
      hace30Dias.setDate(hace30Dias.getDate() - 30);
      filtroFecha = {
        fecha_hora: { $gte: hace30Dias }
      };
    }

    // Obtener datos de asistencias (entradas y salidas)
    const asistencias = await Asistencia.find(filtroFecha).sort({ fecha_hora: 1 });

    // Obtener datos de presencia para análisis de tiempo en campus
    const presencias = await Presencia.find({
      hora_entrada: filtroFecha.fecha_hora || { $gte: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) }
    });

    // 📊 Procesar datos para análisis ML
    const datosParaML = {
      total_registros: asistencias.length,
      rango_fechas: {
        inicio: fecha_inicio || hace30Dias.toISOString(),
        fin: fecha_fin || new Date().toISOString()
      },

      // Análisis por horas para identificar patrones de salida
      salidas_por_hora: {},
      entradas_por_hora: {},

      // Análisis por días de la semana
      patrones_semanales: {},

      // Análisis por facultad para distribución de buses
      salidas_por_facultad: {},

      // Tiempos promedio en campus
      tiempo_promedio_campus: 0,

      // Datos de presencia actual
      estudiantes_presentes: 0
    };

    // Procesar asistencias por hora y tipo
    asistencias.forEach(asistencia => {
      const fecha = new Date(asistencia.fecha_hora);
      const hora = fecha.getHours();
      const diaSemana = fecha.getDay(); // 0=domingo, 1=lunes, etc.
      const tipo = asistencia.tipo || asistencia.entrada_tipo;

      // Contar por horas
      if (tipo === 'salida') {
        datosParaML.salidas_por_hora[hora] = (datosParaML.salidas_por_hora[hora] || 0) + 1;

        // Contar por facultad
        const facultad = asistencia.siglas_facultad || 'SIN_FACULTAD';
        datosParaML.salidas_por_facultad[facultad] = (datosParaML.salidas_por_facultad[facultad] || 0) + 1;
      } else if (tipo === 'entrada') {
        datosParaML.entradas_por_hora[hora] = (datosParaML.entradas_por_hora[hora] || 0) + 1;
      }

      // Patrones semanales
      const diaKey = `dia_${diaSemana}`;
      if (!datosParaML.patrones_semanales[diaKey]) {
        datosParaML.patrones_semanales[diaKey] = { entradas: 0, salidas: 0 };
      }
      datosParaML.patrones_semanales[diaKey][tipo === 'entrada' ? 'entradas' : 'salidas']++;
    });

    // Calcular tiempo promedio en campus
    const tiemposValidos = presencias.filter(p => p.tiempo_en_campus && p.tiempo_en_campus > 0);
    if (tiemposValidos.length > 0) {
      const sumaHoras = tiemposValidos.reduce((suma, p) => suma + (p.tiempo_en_campus / (1000 * 60 * 60)), 0);
      datosParaML.tiempo_promedio_campus = sumaHoras / tiemposValidos.length;
    }

    // Contar estudiantes actualmente presentes
    const estudiantesPresentes = await Presencia.countDocuments({ esta_dentro: true });
    datosParaML.estudiantes_presentes = estudiantesPresentes;

    res.json({
      success: true,
      datos_ml: datosParaML,
      metadata: {
        generado_en: new Date().toISOString(),
        version_api: "1.0",
        descripcion: "Datos históricos procesados para análisis ML de buses nocturnos"
      }
    });

  } catch (err) {
    res.status(500).json({
      error: 'Error al obtener datos históricos para ML',
      details: err.message
    });
  }
});

// 🤖 ENDPOINT 2: Recibir predicciones del modelo ML y almacenar recomendaciones
app.post('/ml/recomendaciones-buses', async (req, res) => {
  try {
    const {
      horario_recomendado,
      numero_buses_sugeridos,
      capacidad_estimada,
      estudiantes_esperados,
      porcentaje_ocupacion,
      facultades_principales,
      justificacion,
      datos_historicos_utilizados,
      modelo_version,
      confianza_prediccion
    } = req.body;

    // Validar datos requeridos
    if (!horario_recomendado || !numero_buses_sugeridos || !estudiantes_esperados) {
      return res.status(400).json({
        error: 'Faltan campos requeridos',
        campos_requeridos: ['horario_recomendado', 'numero_buses_sugeridos', 'estudiantes_esperados']
      });
    }

    // Crear nueva recomendación
    const nuevaRecomendacion = new RecomendacionBus({
      _id: new mongoose.Types.ObjectId().toString(),
      horario_recomendado,
      numero_buses_sugeridos,
      capacidad_estimada: capacidad_estimada || numero_buses_sugeridos * 40, // Asumiendo 40 estudiantes por bus
      estudiantes_esperados,
      porcentaje_ocupacion: porcentaje_ocupacion || Math.round((estudiantes_esperados / (numero_buses_sugeridos * 40)) * 100),
      facultades_principales: facultades_principales || [],
      justificacion: justificacion || 'Recomendación generada por modelo ML',
      datos_historicos_utilizados: datos_historicos_utilizados || {},
      modelo_version: modelo_version || '1.0',
      confianza_prediccion: confianza_prediccion || 0.85
    });

    await nuevaRecomendacion.save();

    // Respuesta exitosa
    res.status(201).json({
      success: true,
      message: 'Recomendación de buses almacenada exitosamente',
      recomendacion: nuevaRecomendacion,
      resumen: {
        horario: horario_recomendado,
        buses: numero_buses_sugeridos,
        estudiantes: estudiantes_esperados,
        ocupacion: `${nuevaRecomendacion.porcentaje_ocupacion}%`,
        confianza: `${Math.round(confianza_prediccion * 100)}%`
      }
    });

  } catch (err) {
    res.status(500).json({
      error: 'Error al almacenar recomendación de buses',
      details: err.message
    });
  }
});

// 📈 ENDPOINT 3: Obtener recomendaciones almacenadas (para dashboards y reportes)
app.get('/ml/recomendaciones-buses', async (req, res) => {
  try {
    const { fecha_desde, limite, solo_recientes } = req.query;

    let filtro = {};
    let opciones = { sort: { fecha_analisis: -1 } };

    // Filtrar por fecha si se especifica
    if (fecha_desde) {
      filtro.fecha_analisis = { $gte: new Date(fecha_desde) };
    }

    // Solo recomendaciones recientes (últimas 24 horas)
    if (solo_recientes === 'true') {
      const hace24h = new Date();
      hace24h.setHours(hace24h.getHours() - 24);
      filtro.fecha_analisis = { $gte: hace24h };
    }

    // Limitar resultados
    if (limite) {
      opciones.limit = parseInt(limite);
    } else {
      opciones.limit = 50; // Límite por defecto
    }

    const recomendaciones = await RecomendacionBus.find(filtro, null, opciones);

    // Estadísticas rápidas
    const estadisticas = {
      total_recomendaciones: recomendaciones.length,
      horarios_mas_recomendados: {},
      promedio_buses: 0,
      promedio_estudiantes: 0,
      confianza_promedio: 0
    };

    if (recomendaciones.length > 0) {
      // Calcular estadísticas
      let sumaBuses = 0, sumaEstudiantes = 0, sumaConfianza = 0;

      recomendaciones.forEach(rec => {
        // Horarios más recomendados
        const horario = rec.horario_recomendado;
        estadisticas.horarios_mas_recomendados[horario] =
          (estadisticas.horarios_mas_recomendados[horario] || 0) + 1;

        // Promedios
        sumaBuses += rec.numero_buses_sugeridos;
        sumaEstudiantes += rec.estudiantes_esperados;
        sumaConfianza += rec.confianza_prediccion;
      });

      estadisticas.promedio_buses = Math.round(sumaBuses / recomendaciones.length);
      estadisticas.promedio_estudiantes = Math.round(sumaEstudiantes / recomendaciones.length);
      estadisticas.confianza_promedio = Math.round((sumaConfianza / recomendaciones.length) * 100) / 100;
    }

    res.json({
      success: true,
      recomendaciones,
      estadisticas,
      metadata: {
        total_resultados: recomendaciones.length,
        consultado_en: new Date().toISOString(),
        filtros_aplicados: {
          fecha_desde: fecha_desde || 'todas',
          limite: opciones.limit,
          solo_recientes: solo_recientes === 'true'
        }
      }
    });

  } catch (err) {
    res.status(500).json({
      error: 'Error al obtener recomendaciones de buses',
      details: err.message
    });
  }
});

// 🎯 ENDPOINT 4: Análisis en tiempo real para ML (datos actuales del campus)
app.get('/ml/estado-actual', async (req, res) => {
  try {
    const ahora = new Date();
    const horaActual = ahora.getHours();
    const diaActual = ahora.getDay();

    // Estudiantes actualmente en campus
    const estudiantesPresentes = await Presencia.find({ esta_dentro: true });

    // Patrones de salida de la última hora
    const haceUnaHora = new Date(ahora - 60 * 60 * 1000);
    const salidasUltimaHora = await Asistencia.find({
      tipo: 'salida',
      fecha_hora: { $gte: haceUnaHora }
    });

    // Distribución por facultades de estudiantes presentes
    const distribucionFacultades = {};
    estudiantesPresentes.forEach(estudiante => {
      const facultad = estudiante.facultad || 'SIN_FACULTAD';
      distribucionFacultades[facultad] = (distribucionFacultades[facultad] || 0) + 1;
    });

    // Estudiantes que llevan más de 6 horas en campus (candidatos a salir pronto)
    const hace6Horas = new Date(ahora - 6 * 60 * 60 * 1000);
    const candidatosSalida = estudiantesPresentes.filter(est =>
      est.hora_entrada && new Date(est.hora_entrada) <= hace6Horas
    );

    const estadoActual = {
      timestamp: ahora.toISOString(),
      hora_actual: horaActual,
      dia_semana: diaActual,

      presencia: {
        total_estudiantes: estudiantesPresentes.length,
        distribucion_facultades: distribucionFacultades,
        candidatos_salida_pronta: candidatosSalida.length
      },

      actividad_reciente: {
        salidas_ultima_hora: salidasUltimaHora.length,
        tendencia_salida: salidasUltimaHora.length > 0 ? 'activa' : 'baja'
      },

      // Información contextual para el modelo
      contexto: {
        es_hora_pico_salida: horaActual >= 17 && horaActual <= 22,
        es_dia_laboral: diaActual >= 1 && diaActual <= 5,
        categoria_horario: this.categorizarHorario(horaActual)
      },

      // Métricas para predicción
      metricas_prediccion: {
        densidad_actual: estudiantesPresentes.length,
        velocidad_salida: salidasUltimaHora.length,
        tiempo_promedio_permanencia: this.calcularTiempoPromedio(estudiantesPresentes)
      }
    };

    res.json({
      success: true,
      estado_actual: estadoActual,
      mensaje: 'Estado actual del campus para análisis ML'
    });

  } catch (err) {
    res.status(500).json({
      error: 'Error al obtener estado actual para ML',
      details: err.message
    });
  }
});

// 🔄 ENDPOINT 5: Feedback del sistema (para mejorar el modelo)
app.post('/ml/feedback', async (req, res) => {
  try {
    const {
      recomendacion_id,
      horario_real_utilizado,
      buses_reales_utilizados,
      estudiantes_reales,
      efectividad_recomendacion,
      comentarios
    } = req.body;

    // Buscar la recomendación original
    const recomendacionOriginal = await RecomendacionBus.findById(recomendacion_id);
    if (!recomendacionOriginal) {
      return res.status(404).json({ error: 'Recomendación no encontrada' });
    }

    // Crear registro de feedback
    const feedbackSchema = new mongoose.Schema({
      _id: String,
      recomendacion_id: String,
      fecha_feedback: { type: Date, default: Date.now },
      recomendacion_original: Object,
      datos_reales: {
        horario_utilizado: String,
        buses_utilizados: Number,
        estudiantes_reales: Number
      },
      efectividad: Number,
      diferencias: Object,
      comentarios: String
    }, { collection: 'feedback_ml', strict: false, _id: false });

    const Feedback = mongoose.model('feedback_ml', feedbackSchema);

    // Calcular diferencias
    const diferencias = {
      diferencia_buses: buses_reales_utilizados - recomendacionOriginal.numero_buses_sugeridos,
      diferencia_estudiantes: estudiantes_reales - recomendacionOriginal.estudiantes_esperados,
      precision_horario: horario_real_utilizado === recomendacionOriginal.horario_recomendado
    };

    const nuevoFeedback = new Feedback({
      _id: new mongoose.Types.ObjectId().toString(),
      recomendacion_id,
      recomendacion_original: recomendacionOriginal.toObject(),
      datos_reales: {
        horario_utilizado: horario_real_utilizado,
        buses_utilizados: buses_reales_utilizados,
        estudiantes_reales: estudiantes_reales
      },
      efectividad: efectividad_recomendacion,
      diferencias,
      comentarios: comentarios || ''
    });

    await nuevoFeedback.save();

    res.json({
      success: true,
      message: 'Feedback registrado exitosamente',
      feedback_id: nuevoFeedback._id,
      analisis: {
        precision_prediccion: efectividad_recomendacion,
        diferencias_detectadas: diferencias,
        mejora_modelo: 'Datos incorporados para entrenamiento futuro'
      }
    });

  } catch (err) {
    res.status(500).json({
      error: 'Error al registrar feedback ML',
      details: err.message
    });
  }
});

// Funciones auxiliares para análisis ML
function categorizarHorario(hora) {
  if (hora >= 6 && hora < 12) return 'mañana';
  if (hora >= 12 && hora < 17) return 'tarde';
  if (hora >= 17 && hora < 22) return 'noche';
  return 'madrugada';
}

function calcularTiempoPromedio(estudiantesPresentes) {
  if (estudiantesPresentes.length === 0) return 0;

  const ahora = new Date();
  const tiempos = estudiantesPresentes.map(est => {
    if (est.hora_entrada) {
      return (ahora - new Date(est.hora_entrada)) / (1000 * 60 * 60); // en horas
    }
    return 0;
  }).filter(t => t > 0);

  return tiempos.length > 0 ? tiempos.reduce((a, b) => a + b) / tiempos.length : 0;
}

// ==================== ENDPOINTS MACHINE LEARNING ====================

// Importar servicios ML
const MLETLService = require('./ml/ml_etl_service');
const PeakHoursPredictiveModel = require('./ml/peak_hours_predictive_model');
const CongestionAlertSystem = require('./ml/congestion_alert_system');
const DatasetCollector = require('./ml/dataset_collector');
const WeeklyModelUpdateService = require('./ml/weekly_model_update_service');

// Inicializar servicios ML
let etlService = null;
let peakModel = null;
let alertSystem = null;
let datasetCollector = null;
let updateService = null;

// Función para inicializar servicios ML
async function initializeMLServices() {
  try {
    etlService = new MLETLService(Asistencia);
    peakModel = new PeakHoursPredictiveModel(Asistencia);
    alertSystem = new CongestionAlertSystem(Asistencia);
    datasetCollector = new DatasetCollector(Asistencia);
    updateService = new WeeklyModelUpdateService(Asistencia);
    
    await alertSystem.initialize();
    await updateService.initialize();
    console.log('🤖 Servicios ML inicializados correctamente');
  } catch (error) {
    console.error('❌ Error inicializando servicios ML:', error.message);
  }
}

// DATASET ENDPOINTS
app.post('/ml/dataset/collect', async (req, res) => {
  try {
    if (!datasetCollector) {
      return res.status(500).json({ error: 'Servicio ML no inicializado' });
    }
    
    const { months = 3, outputFormat = 'json' } = req.body;
    const result = await datasetCollector.collectHistoricalDataset({ months, outputFormat });
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/ml/dataset/validate', async (req, res) => {
  try {
    if (!datasetCollector) {
      return res.status(500).json({ error: 'Servicio ML no inicializado' });
    }
    
    const validation = await datasetCollector.validateDatasetAvailability();
    res.json(validation);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/ml/dataset/statistics', async (req, res) => {
  try {
    if (!datasetCollector) {
      return res.status(500).json({ error: 'Servicio ML no inicializado' });
    }
    
    const stats = await datasetCollector.getDatasetStatistics();
    res.json(stats);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ETL ENDPOINTS
app.post('/ml/etl/run-pipeline', async (req, res) => {
  try {
    if (!etlService) {
      return res.status(500).json({ error: 'Servicio ETL no inicializado' });
    }
    
    const { months = 3, validateData = true, cleanData = true } = req.body;
    const result = await etlService.runETLPipeline({ months, validateData, cleanData });
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// PREDICTION ENDPOINTS
app.post('/ml/prediction/peak-hours/train', async (req, res) => {
  try {
    if (!peakModel) {
      return res.status(500).json({ error: 'Modelo predictivo no inicializado' });
    }
    
    const { months = 3, testSize = 0.2 } = req.body;
    const result = await peakModel.trainPeakHoursModel({ months, testSize });
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/ml/prediction/peak-hours/next-24h', async (req, res) => {
  try {
    if (!peakModel) {
      return res.status(500).json({ error: 'Modelo predictivo no inicializado' });
    }
    
    const predictions = await peakModel.predictNext24Hours();
    res.json(predictions);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// RECOMMENDATIONS FOR BUSES (VERSIÓN SIMPLIFICADA - SIN ML)
app.get('/ml/bus-recommendations', async (req, res) => {
  try {
    const capacidadBus = 50; // Capacidad fija de cada bus
    
    // Analizar asistencias de las últimas 4 semanas
    const fechaLimite = new Date();
    fechaLimite.setDate(fechaLimite.getDate() - 28); // 4 semanas
    
    // Agrupar asistencias por hora
    const asistenciasPorHora = await Asistencia.aggregate([
      {
        $match: {
          fecha_hora: { $exists: true }
        }
      },
      {
        $addFields: {
          fechaObj: { $toDate: "$fecha_hora" }
        }
      },
      {
        $group: {
          _id: {
            hora: { $hour: "$fechaObj" },
            tipo: "$tipo"
          },
          cantidad: { $sum: 1 }
        }
      },
      {
        $sort: { "_id.hora": 1 }
      }
    ]);
    
    // Crear resumen por hora (0-23)
    const horarios = [];
    for (let hora = 6; hora <= 20; hora++) {
      const entradas = asistenciasPorHora.find(
        a => a._id.hora === hora && a._id.tipo === 'entrada'
      )?.cantidad || 0;
      
      const salidas = asistenciasPorHora.find(
        a => a._id.hora === hora && a._id.tipo === 'salida'
      )?.cantidad || 0;
      
      const total = entradas + salidas;
      const busesRecomendados = Math.ceil(total / capacidadBus);
      
      horarios.push({
        hora: hora,
        entradas: entradas,
        salidas: salidas,
        total: total,
        buses_recomendados: busesRecomendados,
        es_hora_pico: total > (capacidadBus * 2) // Más de 2 buses
      });
    }
    
    // Asegurar que siempre haya datos
    if (horarios.length === 0) {
      return res.json({
        success: true,
        capacidad_por_bus: capacidadBus,
        periodo_analizado: "Sin datos suficientes",
        horarios: [],
        resumen: {
          hora_mas_congestionada: null,
          buses_maximos_requeridos: 0
        },
        mensaje: "No hay suficientes datos de asistencias para generar recomendaciones"
      });
    }
    
    res.json({
      success: true,
      capacidad_por_bus: capacidadBus,
      periodo_analizado: "Últimas 4 semanas",
      horarios: horarios,
      resumen: {
        hora_mas_congestionada: horarios.reduce((max, h) => h.total > max.total ? h : max, horarios[0]),
        buses_maximos_requeridos: Math.max(...horarios.map(h => h.buses_recomendados))
      }
    });
    
  } catch (error) {
    console.error('❌ Error generando recomendaciones:', error);
    res.status(500).json({ 
      error: error.message,
      details: 'Error al analizar datos de asistencias',
      horarios: [] // Asegurar que siempre retorne un array
    });
  }
});

// GENERATE TEST DATA ENDPOINT
app.post('/ml/generate-test-data', async (req, res) => {
  try {
    const { days = 120, recordsPerDay = 50 } = req.body;
    
    console.log('🎲 Generando datos de prueba...');
    
    // Generar datos de prueba
    const testData = [];
    const facultades = ['Ingeniería', 'Ciencias', 'Medicina', 'Derecho', 'Administración'];
    const carreras = {
      'Ingeniería': ['Sistemas', 'Civil', 'Industrial', 'Electrónica'],
      'Ciencias': ['Matemáticas', 'Física', 'Química', 'Biología'],
      'Medicina': ['Medicina General', 'Enfermería', 'Odontología'],
      'Derecho': ['Derecho', 'Ciencias Políticas'],
      'Administración': ['Administración', 'Contabilidad', 'Marketing']
    };
    const puertas = ['Puerta A', 'Puerta B', 'Puerta C', 'Puerta Principal'];
    const nombres = [
      'Juan Pérez', 'María García', 'Carlos López', 'Ana Martínez',
      'Luis Rodríguez', 'Elena Fernández', 'Diego Silva', 'Carmen Ruiz'
    ];

    const alumnoIds = [];
    for (let i = 0; i < 50; i++) {
      alumnoIds.push(new mongoose.Types.ObjectId());
    }

    for (let day = 0; day < days; day++) {
      const fecha = new Date(Date.now() - (day * 24 * 60 * 60 * 1000));
      
      // Skip some weekends
      if (fecha.getDay() === 0 || fecha.getDay() === 6) {
        if (Math.random() > 0.3) continue;
      }

      const dailyRecords = Math.floor(Math.random() * recordsPerDay) + 20;
      
      for (let i = 0; i < dailyRecords; i++) {
        const peakHours = [7, 8, 9, 12, 13, 14, 17, 18, 19];
        const normalHours = [10, 11, 15, 16, 20];
        const hour = Math.random() < 0.7 
          ? peakHours[Math.floor(Math.random() * peakHours.length)]
          : normalHours[Math.floor(Math.random() * normalHours.length)];
        const minute = Math.floor(Math.random() * 60);
        
        const facultad = facultades[Math.floor(Math.random() * facultades.length)];
        
        testData.push({
          alumno_id: alumnoIds[Math.floor(Math.random() * alumnoIds.length)],
          nombre_completo: nombres[Math.floor(Math.random() * nombres.length)],
          carrera: carreras[facultad][Math.floor(Math.random() * carreras[facultad].length)],
          facultad,
          fecha,
          hora: `${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}`,
          tipo: Math.random() > 0.5 ? 'entrada' : 'salida',
          puerta: puertas[Math.floor(Math.random() * puertas.length)],
          metodo_acceso: 'NFC'
        });
      }
    }

    // Insertar datos
    await Asistencia.insertMany(testData);
    
    const totalCount = await Asistencia.countDocuments();
    const entradaCount = await Asistencia.countDocuments({ tipo: 'entrada' });
    const salidaCount = await Asistencia.countDocuments({ tipo: 'salida' });

    res.json({
      success: true,
      message: 'Datos de prueba generados exitosamente',
      generated: testData.length,
      totals: {
        total: totalCount,
        entradas: entradaCount,
        salidas: salidaCount
      }
    });
  } catch (error) {
    console.error('❌ Error generando datos:', error);
    res.status(500).json({ error: error.message });
  }
});

// DEBUG: Verificar datos en BD
app.get('/ml/debug/data-count', async (req, res) => {
  try {
    const totalAsistencias = await Asistencia.countDocuments();
    const entradas = await Asistencia.countDocuments({ tipo: 'entrada' });
    const salidas = await Asistencia.countDocuments({ tipo: 'salida' });
    
    // Verificar datos recientes (últimos 90 días)
    const fechaInicio = new Date();
    fechaInicio.setMonth(fechaInicio.getMonth() - 3);
    
    const recentTotal = await Asistencia.countDocuments({
      fecha_hora: { $gte: fechaInicio }
    });
    
    const recentEntradas = await Asistencia.countDocuments({
      fecha_hora: { $gte: fechaInicio },
      tipo: 'entrada'
    });
    
    const recentSalidas = await Asistencia.countDocuments({
      fecha_hora: { $gte: fechaInicio },
      tipo: 'salida'
    });

    // Mostrar algunos ejemplos
    const ejemplos = await Asistencia.find()
      .limit(5)
      .select('fecha_hora tipo siglas_facultad siglas_escuela');

    res.json({
      success: true,
      data: {
        total: {
          asistencias: totalAsistencias,
          entradas: entradas,
          salidas: salidas
        },
        recent3Months: {
          total: recentTotal,
          entradas: recentEntradas,
          salidas: recentSalidas,
          fechaInicio: fechaInicio.toISOString()
        },
        ejemplos: ejemplos
      }
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// DEBUG: VERIFICAR DATOS DE LA BD
app.get('/ml/debug/verificar-datos', async (req, res) => {
  try {
    // Contar todos los registros
    const totalAsistencias = await Asistencia.countDocuments();
    
    // Contar por tipo
    const entradas = await Asistencia.countDocuments({ tipo: 'entrada' });
    const salidas = await Asistencia.countDocuments({ tipo: 'salida' });
    
    // Contar registros recientes (últimos 3 meses)
    const fechaLimite = new Date();
    fechaLimite.setMonth(fechaLimite.getMonth() - 3);
    const fechaLimiteISO = fechaLimite.toISOString();
    
    const recientes = await Asistencia.countDocuments({
      fecha_hora: { $gte: fechaLimiteISO }
    });
    
    // Obtener algunos ejemplos
    const ejemplos = await Asistencia.find().limit(3);
    
    // Verificar estructura de fechas (simplificado)
    const fechaStats = await Asistencia.aggregate([
      {
        $project: {
          fecha_hora: 1,
          tipo: 1,
          fecha_tipo: { $type: "$fecha_hora" }
        }
      },
      {
        $group: {
          _id: "$fecha_tipo",
          count: { $sum: 1 },
          ejemplos: { $push: "$fecha_hora" }
        }
      },
      {
        $project: {
          _id: 1,
          count: 1,
          ejemplos: { $slice: ["$ejemplos", 3] }
        }
      }
    ]);

    res.json({
      success: true,
      datos: {
        total_asistencias: totalAsistencias,
        entradas: entradas,
        salidas: salidas,
        recientes_3_meses: recientes,
        fecha_limite_consulta: fechaLimiteISO,
        tipos_de_fecha: fechaStats,
        ejemplos_registros: ejemplos.map(a => ({
          _id: a._id,
          tipo: a.tipo,
          fecha_hora: a.fecha_hora,
          nombre: a.nombre,
          siglas_facultad: a.siglas_facultad,
          siglas_escuela: a.siglas_escuela
        }))
      }
    });
  } catch (error) {
    console.error('❌ Error verificando datos:', error);
    res.status(500).json({ error: error.message });
  }
});

// AUTO-TRAIN MODEL IF NOT TRAINED (simplified endpoint)
app.post('/ml/bus-recommendations/auto-train', async (req, res) => {
  try {
    if (!peakModel) {
      return res.status(500).json({ error: 'Modelo predictivo no inicializado' });
    }

    console.log('🚀 Iniciando entrenamiento automático del modelo...');
    
    // Primero verificar datos disponibles
    const totalAsistencias = await Asistencia.countDocuments();
    const entradas = await Asistencia.countDocuments({ tipo: 'entrada' });
    const salidas = await Asistencia.countDocuments({ tipo: 'salida' });
    
    console.log(`📊 Total asistencias: ${totalAsistencias}`);
    console.log(`📊 Entradas: ${entradas}, Salidas: ${salidas}`);
    
    if (totalAsistencias < 50) {
      return res.status(400).json({ 
        error: `Datos insuficientes: solo ${totalAsistencias} registros. Se necesitan al menos 50.`,
        totalAsistencias,
        entradas,
        salidas
      });
    }
    
    const result = await peakModel.trainPeakHoursModel({ months: 3, testSize: 0.2 });
    
    res.json({
      success: true,
      message: 'Modelo entrenado exitosamente',
      dataUsed: { totalAsistencias, entradas, salidas },
      result
    });
  } catch (error) {
    console.error('❌ Error entrenando modelo:', error);
    res.status(500).json({ error: error.message });
  }
});

// CONGESTION ALERTS ENDPOINTS
app.post('/ml/congestion-alerts/configure', async (req, res) => {
  try {
    if (!alertSystem) {
      return res.status(500).json({ error: 'Sistema de alertas no inicializado' });
    }
    
    const { thresholds } = req.body;
    if (!thresholds) {
      return res.status(400).json({ error: 'Thresholds requeridos' });
    }
    
    const result = await alertSystem.configureThresholds(thresholds);
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/ml/congestion-alerts/check', async (req, res) => {
  try {
    if (!alertSystem) {
      return res.status(500).json({ error: 'Sistema de alertas no inicializado' });
    }
    
    const result = await alertSystem.checkAndGenerateAlerts();
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// TRAINING PIPELINE ENDPOINT
app.post('/ml/pipeline/train', async (req, res) => {
  try {
    if (!etlService || !peakModel || !alertSystem) {
      return res.status(500).json({ error: 'Servicios ML no inicializados completamente' });
    }
    
    console.log('🚀 Iniciando pipeline completo de entrenamiento ML...');
    
    // 1. Ejecutar ETL
    const etlResult = await etlService.runETLPipeline({
      months: 3,
      validateData: true,
      cleanData: true
    });
    
    // 2. Entrenar modelo
    const trainingResult = await peakModel.trainPeakHoursModel({
      months: 3,
      testSize: 0.2
    });
    
    // 3. Verificar alertas
    const alertCheck = await alertSystem.checkAndGenerateAlerts();
    
    const overallAccuracy = trainingResult.metrics.overall.accuracy;
    const meetsRequirement = overallAccuracy > 0.8;
    
    res.json({
      success: true,
      pipeline: {
        etl: {
          records: etlResult.transform.records,
          features: etlResult.transform.features
        },
        training: {
          accuracy: overallAccuracy,
          meetsRequirement: meetsRequirement,
          metrics: trainingResult.metrics
        },
        alerts: {
          generated: alertCheck.alertsGenerated
        }
      },
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// WEEKLY UPDATE ENDPOINTS
app.post('/ml/update/schedule', async (req, res) => {
  try {
    if (!updateService) {
      return res.status(500).json({ error: 'Servicio de actualización no inicializado' });
    }
    
    const result = await updateService.startScheduler();
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/ml/update/schedule/status', async (req, res) => {
  try {
    if (!updateService) {
      return res.status(500).json({ error: 'Servicio de actualización no inicializado' });
    }
    
    const status = updateService.getSchedulerStatus();
    res.json({ success: true, status });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/ml/update/schedule/stop', async (req, res) => {
  try {
    if (!updateService) {
      return res.status(500).json({ error: 'Servicio de actualización no inicializado' });
    }
    
    const result = await updateService.stopScheduler();
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/ml/update/weekly', async (req, res) => {
  try {
    if (!updateService) {
      return res.status(500).json({ error: 'Servicio de actualización no inicializado' });
    }
    
    const result = await updateService.executeManualUpdate();
    res.json({ success: true, result });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/ml/update/history', async (req, res) => {
  try {
    if (!updateService) {
      return res.status(500).json({ error: 'Servicio de actualización no inicializado' });
    }
    
    const { limit = 20 } = req.query;
    const history = updateService.getUpdateHistory(parseInt(limit));
    res.json({ success: true, history });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/ml/update/configure', async (req, res) => {
  try {
    if (!updateService) {
      return res.status(500).json({ error: 'Servicio de actualización no inicializado' });
    }
    
    const { config } = req.body;
    if (!config) {
      return res.status(400).json({ error: 'Configuración requerida' });
    }
    
    const result = await updateService.configureScheduler(config);
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ML STATUS ENDPOINT
app.get('/ml/status', async (req, res) => {
  try {
    const status = {
      services: {
        etl: !!etlService,
        peakModel: !!peakModel,
        alertSystem: !!alertSystem,
        datasetCollector: !!datasetCollector,
        updateService: !!updateService
      },
      scheduler: updateService ? updateService.getSchedulerStatus() : null,
      database: {
        connected: mongoose.connection.readyState === 1,
        collections: {
          asistencias: await Asistencia.countDocuments(),
          alumnos: await Alumno.countDocuments(),
          usuarios: await User.countDocuments()
        }
      },
      lastUpdated: new Date().toISOString()
    };
    
    res.json({
      success: true,
      status: status,
      message: 'Sistema ML operativo'
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Configuración de puerto para Railway
const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';

app.listen(PORT, HOST, async () => {
  console.log(`🚀 Servidor ejecutándose en ${HOST}:${PORT}`);
  console.log(`📡 Ambiente: ${process.env.NODE_ENV || 'development'}`);
  console.log(`💾 Base de datos: ${mongoose.connection.readyState === 1 ? 'Conectada' : 'Desconectada'}`);
  console.log(`🤖 Sistema ML: Endpoints disponibles en /ml/*`);
  
  // Inicializar servicios ML después de que el servidor esté en funcionamiento
  setTimeout(() => {
    initializeMLServices();
  }, 2000);
});


