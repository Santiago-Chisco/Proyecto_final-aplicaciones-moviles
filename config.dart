// URL de la API en Render. Cambia TU-SERVICIO por el nombre de tu servicio en Render.
// También puedes pasarla al compilar sin tocar el código:
//   flutter run --dart-define=API_URL=https://mi-api.onrender.com/api
// Para probar con backend local en el emulador: http://10.0.2.2:3000/api
const String apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://TU-SERVICIO.onrender.com/api',
);
