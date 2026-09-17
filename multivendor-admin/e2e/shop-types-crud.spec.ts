import { test, expect } from '@playwright/test';
import { login, openRowMenu } from './utils';

// Full CRUD against the Shop Types screen (/management/shop-types): create,
// toggle status, edit, delete. Image upload is optional here (ShopTypeFormSchema
// has no `.required()` on `image`), unlike Cuisines/Banners, so this spec skips it.

test.describe('Shop Types CRUD', () => {
  test.beforeEach(async ({ page }) => {
    await login(page);
    await page.goto('/management/shop-types');
  });

  test('create, toggle status, edit, then delete a shop type', async ({ page }) => {
    const suffix = Date.now();
    const title = `E2E ShopType ${suffix}`;
    const updatedTitle = `E2E ShopType ${suffix} Updated`;

    // ---- Create ----
    await page.getByText('Add Shop Type', { exact: true }).click();
    await page.getByPlaceholder('Title', { exact: true }).fill(title);
    await page.getByRole('button', { name: 'Add', exact: true }).click();
    await expect(page.getByPlaceholder('Title', { exact: true })).not.toBeVisible({ timeout: 10000 });

    const row = page.getByRole('row', { name: new RegExp(title) });
    await expect(row).toBeVisible({ timeout: 10000 });
    await expect(row.getByRole('checkbox')).toBeChecked(); // isActive: true by default

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
