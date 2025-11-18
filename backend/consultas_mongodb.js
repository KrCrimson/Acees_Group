// Script para consultas específicas en MongoDB Atlas
// Usar en MongoDB Compass o en la consola web

// ==================== CONSULTAS PARA ASISTENCIAS ====================

// 1. OBTENER SOLO REGISTROS CON GUARDIA (los nuevos que queremos)
db.asistencias.find({
  "guardia_id": { $exists: true, $ne: null, $ne: "", $ne: "SIN_GUARDIA", $ne: "SIN_GUARDIA_ERROR" },
  "guardia_nombre": { $exists: true, $ne: null, $ne: "", $ne: "Guardia No Identificado", $ne: "GUARDIA_NO_IDENTIFICADO" }
}).sort({ "fecha_hora": -1 });

// 2. OBTENER SOLO REGISTROS SIN GUARDIA (los antiguos)
db.asistencias.find({
  $or: [
    { "guardia_id": { $exists: false } },
    { "guardia_id": null },
    { "guardia_id": "" },
    { "guardia_id": "SIN_GUARDIA" },
    { "guardia_nombre": { $exists: false } },
    { "guardia_nombre": null },
    { "guardia_nombre": "" },
    { "guardia_nombre": "Guardia No Identificado" }
  ]
}).sort({ "fecha_hora": -1 });

// 3. OBTENER REGISTROS DE HOY CON GUARDIA
db.asistencias.find({
  "fecha_hora": {
    $gte: new Date(new Date().setHours(0,0,0,0)),
    $lt: new Date(new Date().setHours(23,59,59,999))
  },
  "guardia_id": { $exists: true, $ne: null, $ne: "", $ne: "SIN_GUARDIA" },
  "guardia_nombre": { $exists: true, $ne: null, $ne: "", $ne: "Guardia No Identificado" }
}).sort({ "fecha_hora": -1 });

// 4. CONTAR REGISTROS POR TIPO
db.asistencias.aggregate([
  {
    $group: {
      _id: {
        tiene_guardia: {
          $cond: [
            {
              $and: [
                { $ne: ["$guardia_id", null] },
                { $ne: ["$guardia_id", ""] },
                { $ne: ["$guardia_id", "SIN_GUARDIA"] },
                { $exists: "$guardia_id" }
              ]
            },
            "con_guardia",
            "sin_guardia"
          ]
        }
      },
      count: { $sum: 1 }
    }
  }
]);

// 5. OBTENER REGISTROS POR GUARDIA ESPECÍFICO
db.asistencias.find({
  "guardia_nombre": "sebastian arce",  // Cambiar por el nombre del guardia
  "fecha_hora": {
    $gte: new Date("2025-11-18T00:00:00.000Z"),
    $lt: new Date("2025-11-19T00:00:00.000Z")
  }
}).sort({ "fecha_hora": -1 });

// 6. LIMPIAR REGISTROS SIN GUARDIA (USAR CON CUIDADO)
// NOTA: Solo ejecutar si estás seguro de que quieres eliminar registros antiguos
/*
db.asistencias.deleteMany({
  $or: [
    { "guardia_id": { $exists: false } },
    { "guardia_id": null },
    { "guardia_id": "" },
    { "guardia_id": "SIN_GUARDIA" }
  ]
});
*/

// 7. OBTENER ESTADÍSTICAS DE ASISTENCIA POR GUARDIA
db.asistencias.aggregate([
  {
    $match: {
      "guardia_id": { $exists: true, $ne: null, $ne: "", $ne: "SIN_GUARDIA" },
      "fecha_hora": {
        $gte: new Date("2025-11-18T00:00:00.000Z"),
        $lt: new Date("2025-11-19T00:00:00.000Z")
      }
    }
  },
  {
    $group: {
      _id: {
        guardia: "$guardia_nombre",
        tipo: "$tipo"
      },
      count: { $sum: 1 }
    }
  },
  {
    $sort: { "_id.guardia": 1, "_id.tipo": 1 }
  }
]);