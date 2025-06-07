import request from 'supertest';
import { App } from '../src/index';

const appInstance = new App();

describe('API basic endpoints', () => {
  const app = appInstance.getApp();

  test('health endpoint', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });

  test('test endpoint', async () => {
    const res = await request(app).get('/api/v1/test');
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});
