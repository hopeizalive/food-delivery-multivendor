import { test, expect } from '@playwright/test';

// Exercises the Super Admin login -> dashboard path against mock-api's
// seeded owner account (mock-api/src/data.js -> ownerAccount). See
// e2e/README.md for how to run this.
test.describe('Super Admin login', () => {
  test('logs in with the seeded demo account and reaches the dashboard', async ({
    page,
  }) => {
    await page.goto('/authentication/login');

    await page.getByPlaceholder('Email').fill('admin-demo@enatega.com');
    await page.getByPlaceholder('Password').fill('demo1234');
    await page.getByRole('button', { name: 'Login' }).click();

    await expect(page).toHaveURL(/\/home/, { timeout: 15000 });

    // Dashboard stat cards (user-stats component) - confirms getDashboardUsers
    // resolved and the page actually rendered real data, not just an empty shell.
    await expect(page.getByText('Total Users')).toBeVisible();
    await expect(page.getByText('Total Vendors')).toBeVisible();
    await expect(page.getByText('Total Stores')).toBeVisible();
    await expect(page.getByText('Total Riders')).toBeVisible();
  });

  test('rejects a wrong password and stays on the login screen', async ({
    page,
  }) => {
    await page.goto('/authentication/login');

    await page.getByPlaceholder('Email').fill('admin-demo@enatega.com');
    await page.getByPlaceholder('Password').fill('wrong-password');
    await page.getByRole('button', { name: 'Login' }).click();

    await expect(page.getByText('Invalid email or password')).toBeVisible();
    await expect(page).toHaveURL(/\/authentication\/login/);
  });
});
