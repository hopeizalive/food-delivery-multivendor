import { test, expect } from '@playwright/test';
import { login, openRowMenu } from './utils';

// Full CRUD against the Coupons screen (/management/coupons): create, toggle
// status, edit, delete. Turning "Lifetime Active" on hides the otherwise-required
// Start/End Date fields, which keeps this spec free of native date-input formatting.

test.describe('Coupons CRUD', () => {
  test.beforeEach(async ({ page }) => {
    await login(page);
    await page.goto('/management/coupons');
  });

  test('create, toggle status, edit, then delete a coupon', async ({ page }) => {
    const suffix = Date.now();
    const title = `E2E${suffix}`;
    const updatedTitle = `E2E${suffix}U`;

    // ---- Create ----
    await page.getByText('Add Coupon', { exact: true }).click();
    await page.getByPlaceholder('Title', { exact: true }).fill(title);
    await page.getByPlaceholder('Discount', { exact: true }).fill('15');
    await page
      .locator('label', { hasText: 'Lifetime Active' })
      .locator('input[type="checkbox"]')
      .check({ force: true });
    await page.getByRole('button', { name: 'Add', exact: true }).click();
    await expect(page.getByPlaceholder('Title', { exact: true })).not.toBeVisible({ timeout: 10000 });

    const row = page.getByRole('row', { name: new RegExp(title) });
    await expect(row).toBeVisible({ timeout: 10000 });
    await expect(row.getByRole('checkbox')).toBeChecked(); // enabled: true by default

    // ---- Toggle status ----
    await row.getByRole('checkbox').click({ force: true });
    await expect(row.getByRole('checkbox')).not.toBeChecked({ timeout: 10000 });

    // ---- Edit ----
    await openRowMenu(row);
    await page.getByRole('menuitem', { name: 'Edit' }).click();
    const titleField = page.getByPlaceholder('Title', { exact: true });
    await expect(titleField).toHaveValue(title, { timeout: 10000 });
    await titleField.fill('');
    await titleField.fill(updatedTitle);
    await page.getByRole('button', { name: 'Update', exact: true }).click();
    await expect(titleField).not.toBeVisible({ timeout: 10000 });

    const updatedRow = page.getByRole('row', { name: new RegExp(updatedTitle) });
    await expect(updatedRow).toBeVisible({ timeout: 10000 });

    // ---- Delete ----
    await openRowMenu(updatedRow);
    await page.getByRole('menuitem', { name: 'Delete' }).click();
    await page.getByRole('button', { name: 'Confirm', exact: true }).click();

    await expect(updatedRow).not.toBeVisible({ timeout: 10000 });
  });
});
