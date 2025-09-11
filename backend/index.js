// ...existing code...
require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

// Conexión a MongoDB Atlas
mongoose.connect(process.env.MONGODB_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true,
});

const db = mongoose.connection;
db.on('error', console.error.bind(console, 'Error de conexión a MongoDB:'));
db.once('open', () => {
  console.log('Conectado exitosamente a MongoDB Atlas');
});

// Modelo de facultad
const FacultadSchema = new mongoose.Schema({
  nombre: String,
  siglas: String
});
const Facultad = mongoose.model('facultades', FacultadSchema);

// Modelo de escuela
const EscuelaSchema = new mongoose.Schema({
  nombre: String,
  siglas: String,
  siglas_facultad: String
});
const Escuela = mongoose.model('escuelas', EscuelaSchema);

// Modelo de asistencias
const AsistenciaSchema = new mongoose.Schema({
  nombre: String,
  apellido: String,
  dni: String,
  codigo_universitario: String,
  siglas_facultad: String,
  siglas_escuela: String,
  tipo: String,
  fecha_hora: Date,
  entrada_tipo: String,
  puerta: String
});
const Asistencia = mongoose.model('asistencias', AsistenciaSchema);

// Ruta para obtener asistencias
app.get('/asistencias', async (req, res) => {
  try {
    const asistencias = await Asistencia.find();
    res.json(asistencias);
  } catch (err) {
    res.status(500).json({ error: 'Error al obtener asistencias' });
  }
});

// Modelo de ejemplo
const UserSchema = new mongoose.Schema({
  name: String,
  email: String,
  password: String, // Asegúrate de tener este campo
  rango: String     // Opcional, para roles
});
const User = mongoose.model('usuarios', UserSchema);

// Ruta para obtener facultades
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
app.get('/usuarios', async (req, res) => {
  const users = await User.find();
  res.json(users);
});

app.post('/usuarios', async (req, res) => {
  const user = new User(req.body);
  await user.save();
  res.json(user);
});

// Ruta de login para autenticación con MongoDB
app.post('/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    // Buscar usuario por email
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(401).json({ error: 'Usuario no encontrado' });
    }
    // Validar contraseña (en producción, usar hash)
    if (user.password !== password) {
      return res.status(401).json({ error: 'Contraseña incorrecta' });
    }
    // Enviar datos relevantes
    res.json({
      id: user._id,
      name: user.name,
      email: user.email,
      rango: user.rango || 'user', // Ajusta según tu modelo
    });
  } catch (err) {
    res.status(500).json({ error: 'Error en el servidor' });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Servidor escuchando en puerto ${PORT}`);
});