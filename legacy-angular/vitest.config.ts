import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    include: ['src/**/*.spec.ts'],
    coverage: {
      provider: 'v8',
      include: ['src/app/**/*.ts'],
      exclude: ['src/app/**/*.spec.ts', 'src/app/**/*.component.ts', 'src/app/**/*.component.html'],
    },
  },
  resolve: {
    // Let Vitest resolve TypeScript paths that match tsconfig
    conditions: ['development', 'browser'],
  },
});
