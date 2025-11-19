const mongoose = require('mongoose');

// Connection string provided by user
const MONGODB_URI = 'mongodb+srv://Angel:angel12345@cluster0.pas0twe.mongodb.net/ASISTENCIA?retryWrites=true&w=majority&appName=Cluster0';

async function limpiarAsistencias() {
    try {
        console.log('Conectando a MongoDB...');
        await mongoose.connect(MONGODB_URI);
        console.log('Conexión exitosa.');

        const collection = mongoose.connection.collection('asistencias');

        // Count before
        const countBefore = await collection.countDocuments();
        console.log(`Documentos encontrados antes de limpiar: ${countBefore}`);

        if (countBefore === 0) {
            console.log('La colección ya está vacía.');
        } else {
            // Delete all
            const result = await collection.deleteMany({});
            console.log(`✅ Se eliminaron ${result.deletedCount} documentos de la colección 'asistencias'.`);
        }

        // Insert sample document with strict schema
        console.log('Insertando documento de ejemplo con esquema estricto...');
        const sampleDoc = {
            _id: new mongoose.Types.ObjectId().toString(),
            nombre: "Andree Sebastian",
            apellido: "FLORES MELENDEZ",
            dni: "12345678",
            codigo_universitario: "3ACA54CC",
            siglas_facultad: "facem",
            siglas_escuela: "epici",
            tipo: "salida",
            fecha_hora: new Date("2025-11-19T15:55:14.000+00:00"),
            entrada_tipo: "nfc",
            puerta: "faing",
            guardia_id: "UMGxDysJWTXHEDHeCZshEFlhAAK2",
            guardia_nombre: "sebastian arce",
            autorizacion_manual: false,
            razon_decision: null,
            timestamp_decision: null,
            coordenadas: null,
            descripcion_ubicacion: "Acceso salida - Punto: faing - Guardia: sebastian arce",
            version_registro: "v2_con_guardia",
            timestamp_creacion: new Date("2025-11-19T20:55:16.051Z"),
            estado: "autorizado",
            __v: 0
        };

        await collection.insertOne(sampleDoc);
        console.log('✅ Documento de ejemplo insertado correctamente.');
        console.log(JSON.stringify(sampleDoc, null, 2));

    } catch (error) {
        console.error('❌ Error:', error);
    } finally {
        await mongoose.disconnect();
        console.log('Desconectado de MongoDB.');
        process.exit(0);
    }
}

limpiarAsistencias();
