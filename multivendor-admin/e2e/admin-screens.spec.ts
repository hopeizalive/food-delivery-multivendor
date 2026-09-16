import { test, expect, type Page } from '@playwright/test';

// Exercises the "core" Super Admin list screens (restaurants, riders,
// users, vendors, orders) against mock-api's seeded demo data
// (mock-api/src/data.js). Each screen just needs to load real rows without
// erroring - these aren't full CRUD flows yet (see e2e/README.md).

async function login(page: Page) {
  await page.goto('/authentication/login');
  await page.getByPlaceholder('Email').fill('admin-demo@enatega.com');
  await page.getByPlaceholder('Password').fill('demo1234');
  await page.getByRole('button', { name: 'Login' }).click();
  await expect(page).toHaveURL(/\/home/, { timeout: 15000 });
}

test.describe('Super Admin core list screens', () => {
  test.beforeEach(async ({ page }) => {
    await login(page);
  });

  test('restaurants list shows the seeded restaurants', async ({ page }) => {
    await page.goto('/general/stores');
    await expect(page.getByText('Demo Bistro')).toBeVisible({ timeout: 15000 });
    await expect(page.getByText('Sushi Point')).toBeVisible();
    await expect(page.getByText('Pizza Palace')).toBeVisible();
  });

  test('riders list shows the seeded riders', async ({ page }) => {
    await page.goto('/general/riders');
    await expect(page.getByText('Demo Rider')).toBeVisible({ timeout: 15000 });
    await expect(page.getByText('Ali Raza')).toBeVisible();
    await expect(page.getByText('Sana Malik')).toBeVisible();
  });

  test('users list shows the seeded users', async ({ page }) => {
    await page.goto('/general/users');
    await expect(page.getByText('Demo Customer')).toBeVisible({ timeout: 15000 });
    await expect(page.getByText('Sara Khan')).toBeVisible();
    await expect(page.getByText('Bilal Ahmed')).toBeVisible();
  });

  test('vendors list shows the seeded vendor', async ({ page }) => {
    await page.goto('/general/vendors');
    await expect(page.getByText('Demo Vendor')).toBeVisible({ timeout: 15000 });
  });

  test('orders list loads without error', async ({ page }) => {
    await page.goto('/management/orders');
    // No orders are seeded by default (resetDemo clears them) - just
    // confirm the page renders its table shell instead of erroring.
    await expect(page.getByText(/order/i).first()).toBeVisible({ timeout: 15000 });
  });

  test('rider detail view loads for a seeded rider', async ({ page }) => {
    await page.goto('/general/riders');
    await expect(page.getByText('Demo Rider')).toBeVisible({ timeout: 15000 });
    await page.goto('/general/riders/rider-1');
    await expect(page.getByText('Demo Rider').first()).toBeVisible({ timeout: 15000 });
  });

  test('user detail view loads for a seeded user', async ({ page }) => {
    await page.goto('/general/users');
    await expect(page.getByText('Demo Customer')).toBeVisible({ timeout: 15000 });
    await page.goto('/general/users/user-detail/customer-1');
    await expect(page.getByText('Demo Customer')).toBeVisible({ timeout: 15000 });
  });
});
