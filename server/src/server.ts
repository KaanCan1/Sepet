import { createApp } from './app.js';
import { env } from './env.js';

createApp().listen(env.port, () => {
  console.log(`Sepet sunucusu http://localhost:${env.port}`);
});
