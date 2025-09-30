import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';

class NfcService {
  static final NfcService _instance = NfcService._internal();
  factory NfcService() => _instance;
  NfcService._internal();

  // Verificar disponibilidad de NFC
  Future<bool> isNfcAvailable() async {
    try {
      NFCAvailability availability = await FlutterNfcKit.nfcAvailability;
      return availability == NFCAvailability.available;
    } catch (e) {
      return false;
    }
  }

  // Leer pulsera NFC y obtener código universitario
  Future<String> readNfcCard() async {
    try {
      // Verificar disponibilidad
      bool available = await isNfcAvailable();
      if (!available) {
        throw Exception('NFC no está disponible en este dispositivo');
      }

      // Iniciar sesión NFC
      NFCTag tag = await FlutterNfcKit.poll(
        timeout: Duration(seconds: 10),
        iosMultipleTagMessage:
            "Múltiples tags detectados, por favor acerque solo una pulsera",
        iosAlertMessage: "Acerque la pulsera al dispositivo",
      );

      // Verificar que es un tag válido
      if (tag.id.isEmpty) {
        throw Exception('Tag NFC inválido');
      }

      // Leer datos del tag
      String codigoUniversitario = await _extractCodigoFromTag(tag);

      return codigoUniversitario;
    } catch (e) {
      throw Exception('Error al leer NFC: $e');
    } finally {
      // Finalizar sesión NFC
      await FlutterNfcKit.finish(iosAlertMessage: "Lectura completada");
    }
  }

  // Extraer código universitario del tag NFC
  Future<String> _extractCodigoFromTag(NFCTag tag) async {
    try {
      // Aquí implementaremos la lógica específica para extraer el código
      // de la pulsera NFC según el formato que uses

      // Por ahora, simulamos que el ID del tag contiene el código
      // Esto debe ajustarse según el formato real de las pulseras
      String tagId = tag.id;

      // Si el tag tiene datos NDEF, intentar leerlos
      if (tag.ndefAvailable == true) {
        var ndefRecords = await FlutterNfcKit.readNDEFRecords();
        if (ndefRecords.isNotEmpty) {
          // Buscar record con el código universitario
          for (var record in ndefRecords) {
            if (record.type != null && record.payload != null) {
              String payload = String.fromCharCodes(record.payload!);
              // Aplicar lógica de extracción según el formato
              if (payload.contains('codigo:')) {
                return payload.split('codigo:')[1].trim();
              }
            }
          }
        }
      }

      // Si no hay datos NDEF, usar el ID del tag como código
      // Esto debe adaptarse según el formato real
      if (tagId.length >= 8) {
        // Tomar los últimos 8 caracteres como código universitario
        return tagId.substring(tagId.length - 8);
      }

      return tagId; // Retornar ID completo si es muy corto
    } catch (e) {
      throw Exception('Error al extraer código del tag: $e');
    }
  }

  // Escribir código universitario a una pulsera NFC (para configuración)
  Future<void> writeCodigoToNfc(String codigoUniversitario) async {
    try {
      // Verificar disponibilidad
      bool available = await isNfcAvailable();
      if (!available) {
        throw Exception('NFC no está disponible en este dispositivo');
      }

      // Por ahora, esta funcionalidad está pendiente de implementar
      // según el formato específico de las pulseras NFC
      throw Exception('Funcionalidad de escritura NFC en desarrollo');
    } catch (e) {
      throw Exception('Error al escribir NFC: $e');
    }
  }

  // Detener cualquier operación NFC en curso
  Future<void> stopNfcSession() async {
    try {
      await FlutterNfcKit.finish();
    } catch (e) {
      // Ignorar errores al finalizar
    }
  }
}
