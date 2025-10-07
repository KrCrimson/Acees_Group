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
      useNewUrlParser: true,
      useUnifiedTopology: true,
      dbName: 'ASISTENCIA',
      // Configuraciones adicionales para Railway
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

// Endpoint de health check para verificar conectividad
app.get('/api/health', (req, res) => {
  res.status(200).json({
    status: 'OK',
    message: 'Server is running',
    timestamp: new Date().toISOString(),
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
  nombre: String,
  apellido: String,
  dni: String,
  codigo_universitario: String,
  siglas_facultad: String,
  siglas_escuela: String,
  tipo: String,
  fecha_hora: Date,
  entrada_tipo: String,
  puerta: String,
  // Nuevos campos para US025-US030
  guardia_id: String,
  guardia_nombre: String,
  autorizacion_manual: Boolean,
  razon_decision: String,
  timestamp_decision: Date,
  coordenadas: String,
  descripcion_ubicacion: String
}, { collection: 'asistencias', strict: false, _id: false });
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
  timestamp: { type: Date, default: Date.now },
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
  last_activity: { type: Date, default: Date.now },
  is_active: { type: Boolean, default: true },
  device_info: {
    platform: String,
    device_id: String,
    app_version: String
  },
  fecha_inicio: { type: Date, default: Date.now },
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
  fecha_creacion: { type: Date, default: Date.now },
  fecha_actualizacion: { type: Date, default: Date.now }
}, { collection: 'usuarios', strict: false, _id: false });

// Middleware para hashear contraseña antes de guardar
UserSchema.pre('save', async function(next) {
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
UserSchema.methods.comparePassword = async function(candidatePassword) {
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
const ExternoSchema = new mongoose.Schema({
  _id: String,
  nombre: String,
  dni: { type: String, unique: true, index: true }
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

    // Crear usuario (la contraseña se hashea automáticamente)
    const user = new User({
      nombre,
      apellido,
      dni,
      email,
      password,
      rango: rango || 'guardia',
      puerta_acargo,
      telefono
    });

    await user.save();
    
    // Responder sin la contraseña
    const userResponse = user.toObject();
    delete userResponse.password;
    
    res.status(201).json(userResponse);
  } catch (err) {
    if (err.code === 11000) {
      res.status(400).json({ error: 'DNI o email ya existe' });
    } else {
      res.status(500).json({ error: 'Error al crear usuario' });
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
    res.status(500).json({ error: 'Error al actualizar contraseña' });
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

// Ruta para registrar asistencia completa (US025-US030)
app.post('/asistencias/completa', async (req, res) => {
  try {
    const asistencia = new Asistencia(req.body);
    await asistencia.save();
    res.status(201).json(asistencia);
  } catch (err) {
    res.status(500).json({ error: 'Error al registrar asistencia completa', details: err.message });
  }
});

// Determinar último tipo de acceso para entrada/salida inteligente (US028)
app.get('/asistencias/ultimo-acceso/:dni', async (req, res) => {
  try {
    const { dni } = req.params;
    const ultimaAsistencia = await Asistencia.findOne({ dni }).sort({ fecha_hora: -1 });
    
    if (ultimaAsistencia) {
      res.json({ ultimo_tipo: ultimaAsistencia.tipo });
    } else {
      res.json({ ultimo_tipo: 'salida' }); // Si no hay registros, próximo debería ser entrada
    }
  } catch (err) {
    res.status(500).json({ error: 'Error al determinar último acceso' });
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
        hora_entrada: new Date(),
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
      
      const horaSalida = new Date();
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

// Iniciar sesión de guardia
app.post('/sesiones/iniciar', concurrencyMiddleware, async (req, res) => {
  try {
    const { guardia_id, guardia_nombre, punto_control, device_info } = req.body;
    
    // Finalizar cualquier sesión anterior del mismo guardia
    await SessionGuard.updateMany(
      { guardia_id, is_active: true },
      { 
        is_active: false, 
        fecha_fin: new Date() 
      }
    );
    
    // Crear nueva sesión
    const sessionToken = require('crypto').randomUUID();
    const nuevaSesion = new SessionGuard({
      _id: sessionToken,
      guardia_id,
      guardia_nombre,
      punto_control,
      session_token: sessionToken,
      device_info: device_info || {},
      last_activity: new Date(),
      is_active: true
    });
    
    await nuevaSesion.save();
    
    res.status(201).json({
      session_token: sessionToken,
      message: 'Sesión iniciada exitosamente',
      session: nuevaSesion
    });
  } catch (err) {
    res.status(500).json({ error: 'Error al iniciar sesión', details: err.message });
  }
});

// Heartbeat - Mantener sesión activa
app.post('/sesiones/heartbeat', async (req, res) => {
  try {
    const { session_token } = req.body;
    
    const sesion = await SessionGuard.findOneAndUpdate(
      { session_token, is_active: true },
      { last_activity: new Date() },
      { new: true }
    );
    
    if (!sesion) {
      return res.status(404).json({ 
        error: 'Sesión no encontrada o inactiva',
        session_expired: true
      });
    }
    
    res.json({ 
      message: 'Heartbeat registrado',
      last_activity: sesion.last_activity
    });
  } catch (err) {
    res.status(500).json({ error: 'Error en heartbeat', details: err.message });
  }
});

// Finalizar sesión
app.post('/sesiones/finalizar', async (req, res) => {
  try {
    const { session_token } = req.body;
    
    const sesion = await SessionGuard.findOneAndUpdate(
      { session_token, is_active: true },
      { 
        is_active: false,
        fecha_fin: new Date()
      },
      { new: true }
    );
    
    if (!sesion) {
      return res.status(404).json({ error: 'Sesión no encontrada' });
    }
    
    res.json({ message: 'Sesión finalizada exitosamente' });
  } catch (err) {
    res.status(500).json({ error: 'Error al finalizar sesión', details: err.message });
  }
});

// Obtener sesiones activas
app.get('/sesiones/activas', async (req, res) => {
  try {
    const sesionesActivas = await SessionGuard.find({ is_active: true });
    res.json(sesionesActivas);
  } catch (err) {
    res.status(500).json({ error: 'Error al obtener sesiones activas' });
  }
});

// Forzar finalización de sesión (para administradores)
app.post('/sesiones/forzar-finalizacion', async (req, res) => {
  try {
    const { guardia_id, admin_id } = req.body;
    
    // Verificar que quien hace la petición es admin
    const admin = await User.findOne({ _id: admin_id, rango: 'admin' });
    if (!admin) {
      return res.status(403).json({ error: 'Solo administradores pueden forzar finalización' });
    }
    
    const resultado = await SessionGuard.updateMany(
      { guardia_id, is_active: true },
      { 
        is_active: false,
        fecha_fin: new Date()
      }
    );
    
    res.json({ 
      message: 'Sesiones finalizadas por administrador',
      sessions_affected: resultado.modifiedCount
    });
  } catch (err) {
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
      hora_entrada: filtroFecha.fecha_hora || { $gte: new Date(Date.now() - 30*24*60*60*1000) }
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

// Configuración de puerto para Railway
const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';

app.listen(PORT, HOST, () => {
  console.log(`🚀 Servidor ejecutándose en ${HOST}:${PORT}`);
  console.log(`📡 Ambiente: ${process.env.NODE_ENV || 'development'}`);
  console.log(`💾 Base de datos: ${mongoose.connection.readyState === 1 ? 'Conectada' : 'Desconectada'}`);
});