const bcrypt = require('bcrypt');

async function generatePassword() {
  try {
    const password = '123456';
    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash(password, saltRounds);
    
    console.log('Contraseña original:', password);
    console.log('Contraseña encriptada:', hashedPassword);
    
    // Verificar que la encriptación funciona
    const isValid = await bcrypt.compare(password, hashedPassword);
    console.log('Verificación exitosa:', isValid);
    
  } catch (error) {
    console.error('Error:', error);
  }
}

generatePassword();
