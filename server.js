const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 3000;
const SECRET = process.env.JWT_SECRET || 'uniminuto-secret-cambiar';
const IVA = 0.19, ENVIO = 8000;

if (!process.env.JWT_SECRET) console.warn('[AVISO] JWT_SECRET no está definido: usa una clave propia en producción.');

// ---------- Persistencia ----------
// 1) MONGODB_URI definido -> guarda en MongoDB (recomendado en Render gratis: no se pierde nada).
// 2) Si no -> archivo db.json en DATA_DIR (en Render solo persiste si montas un Disk).
const DATA_DIR = process.env.DATA_DIR || __dirname;
const DB_FILE = path.join(DATA_DIR, 'db.json');
let db = { users: [], resets: [], orders: [] };
let mongoCol = null;

async function loadDb() {
  if (process.env.MONGODB_URI) {
    const { MongoClient } = require('mongodb');
    const client = new MongoClient(process.env.MONGODB_URI);
    await client.connect();
    mongoCol = client.db(process.env.MONGODB_DB || 'tienda').collection('state');
    const doc = await mongoCol.findOne({ _id: 'db' });
    if (doc) db = { users: doc.users || [], resets: doc.resets || [], orders: doc.orders || [] };
    console.log('Persistencia: MongoDB');
  } else {
    fs.mkdirSync(DATA_DIR, { recursive: true });
    if (fs.existsSync(DB_FILE)) db = JSON.parse(fs.readFileSync(DB_FILE, 'utf8'));
    console.log(`Persistencia: archivo ${DB_FILE} (se pierde en Render sin Disk)`);
  }
}

let pending = Promise.resolve();
function save() {
  if (mongoCol) {
    const snapshot = JSON.parse(JSON.stringify(db));
    pending = pending
      .then(() => mongoCol.replaceOne({ _id: 'db' }, snapshot, { upsert: true }))
      .catch((e) => console.error('Error guardando en MongoDB:', e.message));
  } else {
    fs.writeFileSync(DB_FILE, JSON.stringify(db, null, 2));
  }
}

const P = (id, name, category, price, description) => ({
  id, name, category, price, description,
  image: `https://picsum.photos/seed/prod${id}/600/600`,
});
const products = [
  P(1, 'Camiseta básica', 'Ropa', 39900, 'Camiseta de algodón 100% suave y cómoda, ideal para el día a día.'),
  P(2, 'Chaqueta jean', 'Ropa', 129900, 'Chaqueta de jean clásica con cierre de botones y bolsillos frontales.'),
  P(3, 'Zapatillas urbanas', 'Ropa', 189900, 'Zapatillas ligeras con suela antideslizante para uso diario.'),
  P(4, 'Audífonos Bluetooth', 'Electrónica', 149900, 'Audífonos inalámbricos con cancelación de ruido y 20 h de batería.'),
  P(5, 'Smartwatch Fit', 'Electrónica', 219900, 'Reloj inteligente con monitor cardíaco, GPS y resistencia al agua.'),
  P(6, 'Parlante portátil', 'Electrónica', 99900, 'Parlante Bluetooth resistente al agua con sonido de 360°.'),
  P(7, 'Cargador rápido 30W', 'Electrónica', 59900, 'Cargador USB-C de carga rápida compatible con celulares y tablets.'),
  P(8, 'Lámpara de escritorio', 'Hogar', 69900, 'Lámpara LED con tres niveles de brillo y brazo flexible.'),
  P(9, 'Set de sábanas', 'Hogar', 119900, 'Set de sábanas de microfibra para cama doble, 4 piezas.'),
  P(10, 'Cafetera eléctrica', 'Hogar', 159900, 'Cafetera de goteo con capacidad para 12 tazas y temporizador.'),
  P(11, 'Balón de fútbol', 'Deportes', 79900, 'Balón profesional tamaño 5, costuras reforzadas.'),
  P(12, 'Mat de yoga', 'Deportes', 54900, 'Mat antideslizante de 6 mm con correa para transporte.'),
];

const app = express();
app.use(cors());
app.use(express.json());

// Health check (Render) y ping para evitar el "sueño" del plan gratis
app.get('/', (req, res) => res.json({ ok: true, service: 'tienda-api' }));
app.get('/api/health', (req, res) => res.json({ ok: true }));

const fail = (res, code, error, field) => res.status(code).json({ error, field });
const emailRx = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const pub = (u) => ({ id: u.id, nombre: u.nombre, apellidos: u.apellidos, username: u.username, email: u.email });
const sign = (u) => jwt.sign({ id: u.id }, SECRET, { expiresIn: '7d' });
const s = (v) => (typeof v === 'string' ? v.trim() : '');

function auth(req, res, next) {
  try {
    const token = (req.headers.authorization || '').replace('Bearer ', '');
    const { id } = jwt.verify(token, SECRET);
    req.user = db.users.find((u) => u.id === id);
    if (!req.user) throw new Error('no user');
    next();
  } catch (e) {
    fail(res, 401, 'Sesión inválida o expirada');
  }
}

// ---------- Autenticación ----------
app.post('/api/auth/register', (req, res) => {
  const nombre = s(req.body.nombre), apellidos = s(req.body.apellidos);
  const username = s(req.body.username), email = s(req.body.email).toLowerCase();
  const password = req.body.password || '';
  if (!nombre || !apellidos || !username || !email || !password) return fail(res, 400, 'Todos los campos son obligatorios');
  if (!emailRx.test(email)) return fail(res, 400, 'Correo no válido', 'email');
  if (password.length < 8) return fail(res, 400, 'La contraseña debe tener mínimo 8 caracteres', 'password');
  if (db.users.some((u) => u.username.toLowerCase() === username.toLowerCase())) return fail(res, 409, 'El username ya está en uso', 'username');
  if (db.users.some((u) => u.email === email)) return fail(res, 409, 'El correo ya está registrado', 'email');
  const user = { id: String(Date.now()), nombre, apellidos, username, email, hash: bcrypt.hashSync(password, 10) };
  db.users.push(user);
  save();
  res.status(201).json({ user: pub(user) });
});

app.get('/api/auth/check-username', (req, res) => {
  const u = s(req.query.username).toLowerCase();
  res.json({ available: !db.users.some((x) => x.username.toLowerCase() === u) });
});

app.post('/api/auth/login', (req, res) => {
  const id = s(req.body.identifier).toLowerCase();
  const user = db.users.find((u) => u.username.toLowerCase() === id || u.email === id);
  if (!user || !bcrypt.compareSync(req.body.password || '', user.hash)) return fail(res, 401, 'Credenciales incorrectas');
  res.json({ token: sign(user), user: pub(user) });
});

// ---------- Recuperación de contraseña ----------
// Genera un token (para el enlace) y un código de 6 dígitos, y envía un correo con el ENLACE.
// El enlace abre una página web servida por este backend (/reset-password) donde se escribe la nueva contraseña.
// Correo real: define BREVO_API_KEY y MAIL_FROM (API HTTP; en Render gratis el SMTP está bloqueado).
// Sin correo configurado (modo demo) la respuesta incluye devLink y devCode.
const crypto = require('crypto');
const publicUrl = () => (process.env.PUBLIC_URL || process.env.RENDER_EXTERNAL_URL || `http://localhost:${PORT}`).replace(/\/$/, '');
const mailConfigured = () => !!(process.env.BREVO_API_KEY && process.env.MAIL_FROM);

async function sendResetMail(to, nombre, link, code) {
  const html = `<div style="font-family:Arial,sans-serif;max-width:480px">
    <h2>Restablecer contraseña</h2>
    <p>Hola ${nombre}, recibimos una solicitud para restablecer tu contraseña.</p>
    <p><a href="${link}" style="background:#3f51b5;color:#fff;padding:12px 20px;border-radius:6px;text-decoration:none">Crear nueva contraseña</a></p>
    <p>O copia este enlace en tu navegador:<br>${link}</p>
    <p>También puedes usar el código <b>${code}</b> en la app.</p>
    <p>El enlace vence en 30 minutos. Si no fuiste tú, ignora este correo.</p></div>`;
  const r = await fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: { 'api-key': process.env.BREVO_API_KEY, 'Content-Type': 'application/json', accept: 'application/json' },
    body: JSON.stringify({
      sender: { name: process.env.MAIL_FROM_NAME || 'Tienda', email: process.env.MAIL_FROM },
      to: [{ email: to }],
      subject: 'Restablece tu contraseña',
      htmlContent: html,
    }),
  });
  if (!r.ok) throw new Error(`Brevo respondió ${r.status}: ${await r.text()}`);
}

app.post('/api/auth/forgot', async (req, res) => {
  const email = s(req.body.email).toLowerCase();
  if (!emailRx.test(email)) return fail(res, 400, 'Correo no válido', 'email');
  const user = db.users.find((u) => u.email === email);
  const out = { message: 'Si el correo existe, se envió un enlace de recuperación.' };
  if (user) {
    const code = String(Math.floor(100000 + Math.random() * 900000));
    const token = crypto.randomBytes(24).toString('hex');
    db.resets = db.resets.filter((r) => r.email !== email);
    db.resets.push({ email, code, token, exp: Date.now() + 30 * 60 * 1000 });
    save();
    const link = `${publicUrl()}/reset-password?token=${token}`;
    if (mailConfigured()) {
      try { await sendResetMail(email, user.nombre, link, code); }
      catch (e) { console.error('[CORREO] Error enviando:', e.message); }
    } else {
      console.log(`[RECUPERACIÓN - demo] ${email} → ${link}  (código ${code})`);
      out.devLink = link;
      out.devCode = code;
    }
  }
  res.json(out);
});

app.post('/api/auth/reset', (req, res) => {
  const password = req.body.password || '';
  const token = s(req.body.token), email = s(req.body.email).toLowerCase(), code = s(req.body.code);
  const r = db.resets.find((x) => x.exp > Date.now() && (token ? x.token === token : (x.email === email && x.code === code)));
  if (!r) return fail(res, 400, 'Enlace o código inválido o vencido', token ? 'token' : 'code');
  if (password.length < 8) return fail(res, 400, 'La contraseña debe tener mínimo 8 caracteres', 'password');
  const user = db.users.find((u) => u.email === r.email);
  user.hash = bcrypt.hashSync(password, 10);
  db.resets = db.resets.filter((x) => x !== r);
  save();
  res.json({ message: 'Contraseña actualizada' });
});

// Página web a la que lleva el enlace del correo
app.get('/reset-password', (req, res) => {
  const token = /^[a-f0-9]{48}$/.test(String(req.query.token || '')) ? String(req.query.token) : '';
  res.type('html').send(`<!doctype html><html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Nueva contraseña</title>
<style>body{font-family:Arial,sans-serif;background:#f4f5fb;display:flex;justify-content:center;padding:24px}
.c{background:#fff;padding:24px;border-radius:12px;max-width:380px;width:100%;box-shadow:0 2px 10px #0002}
input,button{width:100%;padding:12px;margin-top:12px;font-size:16px;box-sizing:border-box}
button{background:#3f51b5;color:#fff;border:0;border-radius:6px}.e{color:#c62828}.o{color:#2e7d32}</style></head>
<body><div class="c"><h2>Nueva contraseña</h2>
<input id="p1" type="password" placeholder="Nueva contraseña (mín. 8)"><input id="p2" type="password" placeholder="Repite la contraseña">
<p id="m" class="e"></p><button id="b">Guardar contraseña</button></div>
<script>
const token=${JSON.stringify(token)};const m=document.getElementById('m');
if(!token){m.textContent='Enlace inválido.';document.getElementById('b').disabled=true;}
document.getElementById('b').onclick=async()=>{
 const a=p1.value,b=p2.value;m.className='e';
 if(a.length<8){m.textContent='La contraseña debe tener mínimo 8 caracteres';return;}
 if(a!==b){m.textContent='Las contraseñas no coinciden';return;}
 try{const r=await fetch('/api/auth/reset',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({token,password:a})});
  const d=await r.json();
  if(r.ok){m.className='o';m.textContent='¡Listo! Ya puedes volver a la app e iniciar sesión.';document.getElementById('b').disabled=true;}
  else m.textContent=d.error||'Error';
 }catch(e){m.textContent='No se pudo conectar con el servidor';}
};
</script></body></html>`);
});

// ---------- Perfil ----------
app.get('/api/me', auth, (req, res) => res.json(pub(req.user)));

app.put('/api/me', auth, (req, res) => {
  const nombre = s(req.body.nombre), apellidos = s(req.body.apellidos), username = s(req.body.username);
  if (!nombre || !apellidos || username.length < 3) return fail(res, 400, 'Datos inválidos');
  if (db.users.some((u) => u.id !== req.user.id && u.username.toLowerCase() === username.toLowerCase()))
    return fail(res, 409, 'El username ya está en uso', 'username');
  Object.assign(req.user, { nombre, apellidos, username });
  save();
  res.json(pub(req.user));
});

app.put('/api/me/password', auth, (req, res) => {
  if (!bcrypt.compareSync(req.body.actual || '', req.user.hash)) return fail(res, 400, 'La contraseña actual es incorrecta');
  if ((req.body.nueva || '').length < 8) return fail(res, 400, 'La nueva contraseña debe tener mínimo 8 caracteres');
  req.user.hash = bcrypt.hashSync(req.body.nueva, 10);
  save();
  res.json({ message: 'Contraseña actualizada' });
});

// ---------- Productos ----------
app.get('/api/products', (req, res) => {
  const { category, q } = req.query;
  let list = products;
  if (category && category !== 'Todos') list = list.filter((p) => p.category === category);
  if (q) list = list.filter((p) => p.name.toLowerCase().includes(String(q).toLowerCase()));
  res.json(list);
});

app.get('/api/products/:id', (req, res) => {
  const p = products.find((x) => x.id === Number(req.params.id));
  p ? res.json(p) : fail(res, 404, 'Producto no encontrado');
});

// ---------- Pedidos (simulación de compra) ----------
app.post('/api/orders', auth, (req, res) => {
  const items = [];
  for (const it of req.body.items || []) {
    const p = products.find((x) => x.id === Number(it.productId));
    const qty = Math.max(1, parseInt(it.qty, 10) || 1);
    if (p) items.push({ productId: p.id, name: p.name, price: p.price, qty });
  }
  if (!items.length) return fail(res, 400, 'El carrito está vacío');
  const subtotal = items.reduce((a, i) => a + i.price * i.qty, 0);
  const iva = Math.round(subtotal * IVA);
  const total = subtotal + iva + ENVIO;
  const order = { id: db.orders.length + 1, userId: req.user.id, date: new Date().toISOString(), items, subtotal, iva, envio: ENVIO, total };
  db.orders.push(order);
  save();
  res.status(201).json(order);
});

app.get('/api/orders', auth, (req, res) =>
  res.json(db.orders.filter((o) => o.userId === req.user.id).reverse()));

loadDb()
  .then(() => app.listen(PORT, '0.0.0.0', () => console.log(`API lista en el puerto ${PORT}`)))
  .catch((e) => { console.error('No se pudo iniciar:', e); process.exit(1); });
