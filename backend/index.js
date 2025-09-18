// Backend completo con autenticación segura
require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const bcrypt = require('bcrypt');

const app = express();
app.use(cors());
app.use(express.json());

// Conexión a MongoDB Atlas - ESPECIFICAR BASE DE DATOS ASISTENCIA
mongoose.set('strictQuery', false);
mongoose.connect(process.env.MONGODB_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true,
  dbName: 'ASISTENCIA'
});

const db = mongoose.connection;
db.on('error', console.error.bind(console, 'Error de conexión a MongoDB:'));
db.once('open', () => {
  console.log('Conectado exitosamente a MongoDB> Atlas');
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

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Servidor escuchando en puerto ${PORT}`);
});