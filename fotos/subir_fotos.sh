#!/bin/bash

# Script para convertir fotos existentes a Base64 y subirlas a MongoDB
echo "🚀 Subiendo fotos existentes a MongoDB para todos los alumnos..."

# Configuración
MONGODB_URI="mongodb+srv://Angel:angel12345@cluster0.pas0twe.mongodb.net/ASISTENCIA?retryWrites=true&w=majority&appName=Cluster0"
FOTOS_DIR="/home/desci/Documentos/Acees_Group/fotos"

# Función para convertir imagen a Base64
convert_to_base64() {
    local file="$1"
    echo "data:image/jpeg;base64,$(base64 -w 0 "$file")"
}

echo "📸 Convirtiendo fotos a Base64..."

# Convertir todas las fotos a Base64
FOTO1=$(convert_to_base64 "$FOTOS_DIR/test1.jpg")
FOTO2=$(convert_to_base64 "$FOTOS_DIR/test2.jpg")
FOTO3=$(convert_to_base64 "$FOTOS_DIR/test3.jpg")
FOTO4=$(convert_to_base64 "$FOTOS_DIR/test4.jpg")
FOTO5=$(convert_to_base64 "$FOTOS_DIR/test5.jpg")
FOTO6=$(convert_to_base64 "$FOTOS_DIR/test6.jpg")
FOTO7=$(convert_to_base64 "$FOTOS_DIR/test7.jpg")

echo "✅ Fotos convertidas a Base64"

# Crear array de fotos para MongoDB
cat > /tmp/mongo_script.js << EOF
use('ASISTENCIA');

// Array de fotos Base64
const fotos = [
    '${FOTO1}',
    '${FOTO2}',
    '${FOTO3}',
    '${FOTO4}',
    '${FOTO5}',
    '${FOTO6}',
    '${FOTO7}'
];

// Obtener todos los alumnos
const alumnos = db.alumnos.find().toArray();
print('📋 Total alumnos encontrados: ' + alumnos.length);

let fotosAgregadas = 0;
let indicePhoto = 0;

alumnos.forEach(function(alumno) {
    try {
        // Asignar foto cíclicamente (test1, test2, ..., test7, test1, ...)
        const fotoAsignada = fotos[indicePhoto % fotos.length];
        
        const resultado = db.alumnos.updateOne(
            { "_id": alumno._id },
            { 
                \$set: { 
                    "foto": fotoAsignada,
                    "foto_info": {
                        "nombre_archivo": "test" + ((indicePhoto % 7) + 1) + ".jpg",
                        "upload_date": new Date(),
                        "size": fotoAsignada.length
                    }
                } 
            }
        );
        
        if (resultado.modifiedCount > 0) {
            const nombreFoto = "test" + ((indicePhoto % 7) + 1) + ".jpg";
            print("✅ " + nombreFoto + " → " + alumno.nombre + " " + alumno.apellido + " (DNI: " + alumno.DNI + ")");
            fotosAgregadas++;
        }
        
        indicePhoto++;
    } catch (error) {
        print("❌ Error con DNI " + alumno.DNI + ": " + error);
    }
});

print("");
print("🎉 PROCESO COMPLETADO");
print("📊 Fotos asignadas: " + fotosAgregadas + "/" + alumnos.length);

// Verificación final
const totalConFoto = db.alumnos.countDocuments({ "foto": { \$exists: true, \$ne: null, \$ne: "" } });
print("📸 Total alumnos con foto: " + totalConFoto);

EOF

echo "🔧 Ejecutando en MongoDB..."
mongosh "$MONGODB_URI" --file /tmp/mongo_script.js

# Limpiar archivo temporal
rm /tmp/mongo_script.js

echo ""
echo "✨ ¡COMPLETADO!"
echo "📱 Ahora todos los alumnos tienen foto asignada"
echo "🎯 Puedes probar la app Flutter escaneando cualquier tarjeta NFC"